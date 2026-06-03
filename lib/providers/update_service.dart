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

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flauncher_channel.dart';

enum UpdateStatus { idle, checking, available, downloading, error }

/// Checks the GitHub releases of the project once per day and, when a newer
/// build is published, lets the user install it from the home screen.
///
/// The release must ship two assets (produced by the build workflow):
///  - `latest.json`        -> `{ "versionCode": <int>, "versionName": "<str>" }`
///  - `smotrim-launcher.apk` -> the universal signed APK
class UpdateService extends ChangeNotifier {
  static const String _owner = "davnozdu";
  static const String _repo = "LtvLauncher";
  static const String _apkAsset = "smotrim-launcher.apk";

  static const String _latestJsonUrl =
      "https://github.com/$_owner/$_repo/releases/latest/download/latest.json";
  static const String _apkUrl =
      "https://github.com/$_owner/$_repo/releases/latest/download/$_apkAsset";

  static const String _lastCheckKey = "update_last_check_ms";
  static const Duration _checkInterval = Duration(hours: 24);

  final SharedPreferences _sharedPreferences;
  final FLauncherChannel _channel;

  UpdateService(this._sharedPreferences, this._channel);

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  String? _latestVersionName;
  String? get latestVersionName => _latestVersionName;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  bool get updateAvailable => _status == UpdateStatus.available;
  bool get isDownloading => _status == UpdateStatus.downloading;

  void _setStatus(UpdateStatus status) {
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
        _setStatus(UpdateStatus.available);
      } else {
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
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response.transform(utf8.decoder).join();
      final map = jsonDecode(body) as Map<String, dynamic>;
      final versionCode = (map["versionCode"] as num).toInt();
      final versionName = (map["versionName"] ?? "").toString();
      return _LatestRelease(versionCode, versionName);
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
    try {
      final request = await client.getUrl(Uri.parse(_apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        _setStatus(UpdateStatus.error);
        return false;
      }

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$_apkAsset");
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();

      final started = await _channel.installApk(file.path);
      // The system installer takes over; reset back to "available" so the
      // prompt remains if the user cancels the install.
      _setStatus(started ? UpdateStatus.available : UpdateStatus.error);
      return started;
    } catch (e) {
      debugPrint("Update download failed: $e");
      _setStatus(UpdateStatus.error);
      return false;
    } finally {
      client.close();
    }
  }
}

class _LatestRelease {
  final int versionCode;
  final String versionName;

  const _LatestRelease(this.versionCode, this.versionName);
}
