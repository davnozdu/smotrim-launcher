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
/// The release asset name carries the version (e.g. `hls-proxy-launcher-8.4.8.apk`),
/// so we can't use a static `releases/latest/download/<name>` URL. Instead we
/// query the GitHub API for the `latest` release and grab its first `.apk`
/// asset. Installing the same package over an existing one updates it and keeps
/// its data (same signature).
class HlsProxyInstallButton extends StatefulWidget {
  const HlsProxyInstallButton({super.key});

  @override
  State<HlsProxyInstallButton> createState() => _HlsProxyInstallButtonState();
}

class _HlsProxyInstallButtonState extends State<HlsProxyInstallButton> {
  static const String _hlsPackage = "com.hlsproxy.launcher";
  static const String _latestApiUrl =
      "https://api.github.com/repos/davnozdu/hls-proxy-android/releases/latest";

  final FLauncherChannel _channel = FLauncherChannel();
  bool _focused = false;
  bool _installed = false;
  bool _downloading = false;
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

  /// Resolves the download URL of the first `.apk` asset in the latest release.
  Future<String?> _resolveApkUrl(HttpClient client) async {
    final request = await client.getUrl(Uri.parse(_latestApiUrl));
    // GitHub's API rejects requests without a User-Agent.
    request.headers.set(HttpHeaders.userAgentHeader, "SmotrimLauncher");
    request.headers.set(HttpHeaders.acceptHeader, "application/vnd.github+json");
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final assets = (json["assets"] as List?) ?? const [];
    for (final asset in assets) {
      final name = (asset["name"] as String?) ?? "";
      if (name.toLowerCase().endsWith(".apk")) {
        return asset["browser_download_url"] as String?;
      }
    }
    return null;
  }

  Future<void> _onPressed() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final apkUrl = await _resolveApkUrl(client);
      if (apkUrl == null) {
        debugPrint("HLS-PROXY: no .apk asset in latest release");
        return;
      }

      final request = await client.getUrl(Uri.parse(apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return;

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/hls-proxy.apk");
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;
      var lastPercent = -1;

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
      await sink.flush();
      await sink.close();

      // The system installer takes over (installs new or updates in place,
      // preserving data for the same package + signature).
      await _channel.installApk(file.path);
    } catch (e) {
      debugPrint("HLS-PROXY install failed: $e");
    } finally {
      client.close();
      if (mounted) setState(() => _downloading = false);
      _refreshInstalled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    final String label = _downloading
        ? "${l.hlsProxyDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%"
        : (_installed ? l.updateHlsProxy : l.installHlsProxy);
    final IconData icon = _installed ? Icons.system_update : Icons.download;

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
