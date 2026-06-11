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
///
/// On press it first compares the installed versionName against the latest
/// release tag: if it's already up to date it tells the user so in a dialog
/// and downloads nothing; otherwise it pulls the universal `app-release.apk`
/// from the `latest` release and installs/updates in place (data preserved,
/// same signature).
///
/// The latest tag is resolved from the redirect of `releases/latest` on
/// github.com — deliberately NOT via api.github.com, whose anonymous rate
/// limit is shared per IP and routinely exhausted behind carrier-grade NAT.
class PlayerInstallButton extends StatefulWidget {
  const PlayerInstallButton({super.key});

  @override
  State<PlayerInstallButton> createState() => _PlayerInstallButtonState();
}

enum _Phase { idle, checking, downloading }

class _PlayerInstallButtonState extends State<PlayerInstallButton> {
  static const String _playerPackage = "cz.smotrim.player";
  static const String _repo = "davnozdu/smotrim-player";
  static const String _apkUrl =
      "https://github.com/$_repo/releases/latest/download/app-release.apk";

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
      final installed = await _channel.isAppInstalled(_playerPackage);
      if (mounted) setState(() => _installed = installed);
    } catch (_) {}
  }

  /// Resolves the latest release tag from the `releases/latest` redirect
  /// (e.g. `.../releases/tag/v1.7.25` -> `v1.7.25`). Returns null on failure.
  Future<String?> _fetchLatestTag(HttpClient client) async {
    try {
      final request =
          await client.getUrl(Uri.parse("https://github.com/$_repo/releases/latest"));
      request.followRedirects = false;
      final response = await request.close();
      await response.drain();
      if (response.statusCode < 300 || response.statusCode >= 400) return null;
      final location = response.headers.value(HttpHeaders.locationHeader) ?? "";
      return RegExp(r'/tag/([^/?#]+)').firstMatch(location)?.group(1);
    } catch (e) {
      debugPrint("Player: latest tag resolution failed: $e");
      return null;
    }
  }

  Future<void> _onPressed() async {
    if (_phase != _Phase.idle) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _phase = _Phase.checking);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final tag = await _fetchLatestTag(client);
      if (tag == null) {
        _showMessage(l.updateCheckFailed);
        return;
      }

      final installedVersion = await _channel.getAppVersion(_playerPackage);
      if (installedVersion != null && _compareVersions(tag, installedVersion) <= 0) {
        _showMessage("${l.alreadyUpToDate} ($installedVersion)");
        return;
      }

      if (mounted) setState(() { _phase = _Phase.downloading; _progress = 0; });

      final request = await client.getUrl(Uri.parse(_apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        _showMessage(l.downloadFailed);
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/smotrim-player.apk");
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
      debugPrint("Player install failed: $e");
      _showMessage(l.downloadFailed);
    } finally {
      client.close();
      if (mounted) setState(() => _phase = _Phase.idle);
      _refreshInstalled();
    }
  }

  /// TV-friendly result dialog: always visible (unlike a snackbar) and
  /// dismissable with the remote (OK button autofocused).
  void _showMessage(String text) {
    if (!mounted) return;
    setState(() => _phase = _Phase.idle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
        label = "${l.playerDownloading} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%";
        icon = Icons.download;
        break;
      case _Phase.idle:
        label = _installed ? l.updatePlayer : l.installPlayer;
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
