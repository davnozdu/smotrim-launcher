/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flauncher_channel.dart';

enum UpdateStatus { idle, checking, available, downloading }

/// Checks the GitHub releases of the project once per day and, when a newer
/// build is published, lets the user install it from the home screen.
///
/// The release must ship two assets (produced by the build workflow):
///  - `latest.json`        -> `{ "versionCode": <int>, "versionName": "<str>" }`
///  - `smotrim-launcher.apk` -> the universal signed APK
class UpdateService extends ChangeNotifier {
  static const String _owner = "davnozdu";
  static const String _repo = "smotrim-launcher";
  static const String _apkAsset = "smotrim-launcher.apk";

  static const String _latestJsonUrl =
      "https://github.com/$_owner/$_repo/releases/latest/download/latest.json";
  static const String _apkUrl =
      "https://github.com/$_owner/$_repo/releases/latest/download/$_apkAsset";

  static const String _lastCheckKey = "update_last_check_ms";
  static const Duration _checkInterval = Duration(hours: 24);
  // Connection timeouts only cover the handshake. On a flaky hotel network a
  // connection can be established and then stall forever, which used to pin the
  // status at "downloading" and block every later check for good.
  static const Duration _metadataTimeout = Duration(seconds: 30);
  // Inactivity deadline: fires when no chunk arrives for this long, so a slow
  // but progressing download is never cut off.
  static const Duration _downloadStallTimeout = Duration(minutes: 2);

  final SharedPreferences _sharedPreferences;
  final FLauncherChannel _channel;
  Timer? _periodicTimer;
  bool _disposed = false;

  UpdateService(this._sharedPreferences, this._channel) {
    // Re-check periodically so the daily check still happens on a TV that
    // stays powered on for days without the launcher process restarting.
    _periodicTimer = Timer.periodic(const Duration(hours: 6), (_) => maybeCheckForUpdate());
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    super.dispose();
  }

  // A check or download in flight at disposal time would otherwise notify a
  // dead notifier when it finally completes.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  String? _latestVersionName;
  String? get latestVersionName => _latestVersionName;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  /// SHA-256 of the pending APK, when the release publishes one.
  String? _expectedSha256;

  bool get updateAvailable => _status == UpdateStatus.available;
  bool get isDownloading => _status == UpdateStatus.downloading;

  void _setStatus(UpdateStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  /// Checks for an update at most once per [_checkInterval], unless [force].
  Future<void> maybeCheckForUpdate({bool force = false}) async {
    final lastCheck = _sharedPreferences.getInt(_lastCheckKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastCheck;
    if (!force && elapsed < _checkInterval.inMilliseconds) return;
    await checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    if (_status == UpdateStatus.downloading) return;
    _setStatus(UpdateStatus.checking);
    try {
      final latest = await _fetchLatest();
      await _sharedPreferences.setInt(
          _lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (latest == null) {
        _setStatus(UpdateStatus.idle);
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (latest.versionCode > currentCode) {
        _latestVersionName = latest.versionName;
        _expectedSha256 = latest.sha256;
        _setStatus(UpdateStatus.available);
      } else {
        _expectedSha256 = null;
        _setStatus(UpdateStatus.idle);
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
      _setStatus(UpdateStatus.idle);
    }
  }

  Future<_LatestRelease?> _fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(_latestJsonUrl));
      final response = await request.close().timeout(_metadataTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body =
          await response.transform(utf8.decoder).join().timeout(_metadataTimeout);
      final map = jsonDecode(body) as Map<String, dynamic>;
      final versionCode = (map["versionCode"] as num).toInt();
      final versionName = (map["versionName"] ?? "").toString();
      // Optional: when the release ships a checksum we verify the APK against it.
      final checksum = (map["sha256"] as String?)?.trim().toLowerCase();
      return _LatestRelease(versionCode, versionName,
          checksum != null && checksum.isNotEmpty ? checksum : null);
    } finally {
      client.close();
    }
  }

  /// Downloads the latest APK and launches the system installer.
  Future<bool> downloadAndInstall() async {
    if (_status == UpdateStatus.downloading) return false;
    _downloadProgress = 0;
    _setStatus(UpdateStatus.downloading);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    File? file;
    try {
      final request = await client.getUrl(Uri.parse(_apkUrl));
      final response = await request.close().timeout(_metadataTimeout);
      if (response.statusCode != HttpStatus.ok) {
        // Keep the prompt so the user can retry instead of it vanishing.
        _setStatus(UpdateStatus.available);
        return false;
      }

      final dir = await getTemporaryDirectory();
      file = File("${dir.path}/$_apkAsset");
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;
      var lastPercent = -1;
      final digest = _expectedSha256 != null ? AccumulatorSink<Digest>() : null;
      final hasher = digest != null ? sha256.startChunkedConversion(digest) : null;

      try {
        // A whole-download deadline: a stream that stalls mid-transfer would
        // otherwise hang here forever with the status stuck on "downloading".
        await for (final chunk in response.timeout(_downloadStallTimeout)) {
          sink.add(chunk);
          hasher?.add(chunk);
          received += chunk.length;
          if (total > 0) {
            // Only notify on whole-percent changes to avoid excessive rebuilds.
            final percent = (received * 100 ~/ total);
            if (percent != lastPercent) {
              lastPercent = percent;
              _downloadProgress = received / total;
              notifyListeners();
            }
          }
        }
      } finally {
        // close() flushes pending writes and releases the file handle even if
        // the stream errors out mid-download.
        await sink.close();
      }

      if (hasher != null && digest != null) {
        hasher.close();
        final actual = digest.events.single.toString();
        if (actual != _expectedSha256) {
          debugPrint("Update rejected: checksum mismatch");
          await _deleteQuietly(file);
          _setStatus(UpdateStatus.available);
          return false;
        }
      }

      final started = await _channel.installApk(file.path);
      // The system installer takes over; keep status "available" so the prompt
      // remains if the user cancels (or the install couldn't be launched).
      _setStatus(UpdateStatus.available);
      return started;
    } catch (e) {
      debugPrint("Update download failed: $e");
      // A partial file left behind would be handed to the installer on a retry.
      if (file != null) await _deleteQuietly(file);
      _setStatus(UpdateStatus.available);
      return false;
    } finally {
      client.close();
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — a stale temp file is not worth failing the update over.
    }
  }
}

class _LatestRelease {
  final int versionCode;
  final String versionName;
  final String? sha256;

  const _LatestRelease(this.versionCode, this.versionName, [this.sha256]);
}
