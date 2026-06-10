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

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/l10n/app_localizations.dart';

/// Installs or updates the HLS-PROXY companion app from its GitHub releases.
///
/// On press it first compares the installed versionName against the latest
/// release tag: if it's already up to date it shows a brief message and
/// downloads nothing. The release asset name carries an internal version
/// (e.g. `hls-proxy-launcher-8.4.8.apk`), so we resolve the first `.apk` of the
/// `latest` release via the GitHub API. Installing the same package over an
/// existing one updates it and keeps its data (same signature).
class HlsProxyInstallButton extends StatefulWidget {
  const HlsProxyInstallButton({super.key});

  @override
  State<HlsProxyInstallButton> createState() => _HlsProxyInstallButtonState();
}

enum _Phase { idle, checking, downloading }

class _HlsProxyInstallButtonState extends State<HlsProxyInstallButton> {
  static const String _hlsPackage = "com.hlsproxy.launcher";
  static const String _latestApiUrl =
      "https://api.github.com/repos/davnozdu/hls-proxy-android/releases/latest";

  final FLauncherChannel _channel = FLauncherChannel();
  bool _focused = false;
  bool _installed = false;
  _Phase _phase = _Phase.idle;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  Future<void> _refreshInstalled() async {
    try {
      final installed = await _channel.isAppInstalled(_hlsPackage);
      if (mounted) setState(() => _installed = installed);
    } catch (_) {}
  }

  /// Fetches the latest release: returns (tagName, apkDownloadUrl).
  Future<(String, String)?> _fetchLatest(HttpClient client) async {
    final request = await client.getUrl(Uri.parse(_latestApiUrl));
    request.headers.set(HttpHeaders.userAgentHeader, "SmotrimLauncher");
    request.headers.set(HttpHeaders.acceptHeader, "application/vnd.github+json");
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;

    final json = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final tag = json["tag_name"] as String?;
    final assets = (json["assets"] as List?) ?? const [];

    String? apkUrl;
    for (final a in assets) {
      final name = (a["name"] as String?) ?? "";
      if (name.toLowerCase().endsWith(".apk")) {
        apkUrl = a["browser_download_url"] as String?;
        break;
      }
    }
    if (tag == null || apkUrl == null) return null;
    return (tag, apkUrl);
  }

  Future<void> _onPressed() async {
    if (_phase != _Phase.idle) return;
    setState(() => _phase = _Phase.checking);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final latest = await _fetchLatest(client);
      if (latest == null) {
        debugPrint("HLS-PROXY: failed to resolve latest release");
        return;
      }
      final (tag, apkUrl) = latest;

      final installedVersion = await _channel.getAppVersion(_hlsPackage);
      if (installedVersion != null && _compareVersions(tag, installedVersion) <= 0) {
        if (mounted) {
          setState(() => _phase = _Phase.idle);
          final l = AppLocalizations.of(context)!;
          _showSnack("${l.alreadyUpToDate} ($installedVersion)");
        }
        return;
      }

      if (mounted) setState(() { _phase = _Phase.downloading; _progress = 0; });

      final request = await client.getUrl(Uri.parse(apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return;

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/hls-proxy.apk");
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;
      var lastPercent = -1;

      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final percent = received * 100 ~/ total;
            if (percent != lastPercent) {
              lastPercent = percent;
              if (mounted) setState(() => _progress = received / total);
            }
          }
        }
      } finally {
        // close() flushes pending writes and releases the file handle even if
        // the stream errors out mid-download.
        await sink.close();
      }

      await _channel.installApk(file.path);
    } catch (e) {
      debugPrint("HLS-PROXY install failed: $e");
    } finally {
      client.close();
      if (mounted) setState(() => _phase = _Phase.idle);
      _refreshInstalled();
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  /// Numeric, component-wise version compare. Returns >0 if [a] is newer.
  static int _compareVersions(String a, String b) {
    final pa = _parse(a), pb = _parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static List<int> _parse(String v) {
    final m = RegExp(r'\d+(?:\.\d+)*').firstMatch(v);
    if (m == null) return const [];
    return m.group(0)!.split('.').map(int.parse).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    final String label;
    final IconData icon;
    switch (_phase) {
      case _Phase.checking:
        label = l.checkingForUpdates;
        icon = Icons.search;
        break;
      case _Phase.downloading:
        label = "${l.hlsProxyDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%";
        icon = Icons.download;
        break;
      case _Phase.idle:
        label = _installed ? l.updateHlsProxy : l.installHlsProxy;
        icon = _installed ? Icons.system_update : Icons.download;
        break;
    }

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _onPressed()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _onPressed()),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1.0,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            color: _focused ? accent : accent.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            elevation: _focused ? 16 : 0,
            shadowColor: Colors.black,
            child: InkWell(
              onTap: _onPressed,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: _focused ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
