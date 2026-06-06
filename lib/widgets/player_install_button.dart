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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/l10n/app_localizations.dart';

/// Installs or updates the companion Smotrim Player from its GitHub releases.
/// Always pulls the universal APK from the `latest` tag, so future player
/// releases are picked up automatically. Installing the same package over an
/// existing one updates it and keeps its data (same signature).
class PlayerInstallButton extends StatefulWidget {
  const PlayerInstallButton({super.key});

  @override
  State<PlayerInstallButton> createState() => _PlayerInstallButtonState();
}

class _PlayerInstallButtonState extends State<PlayerInstallButton> {
  static const String _playerPackage = "cz.smotrim.player";
  static const String _apkUrl =
      "https://github.com/davnozdu/smotrim-player/releases/latest/download/app-release.apk";

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
      final installed = await _channel.isAppInstalled(_playerPackage);
      if (mounted) setState(() => _installed = installed);
    } catch (_) {}
  }

  Future<void> _onPressed() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(_apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return;

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/smotrim-player.apk");
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
      debugPrint("Player install failed: $e");
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
        ? "${l.playerDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%"
        : (_installed ? l.updatePlayer : l.installPlayer);
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
