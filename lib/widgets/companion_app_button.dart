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

/// A bottom-of-home button that installs or updates a companion app from its
/// GitHub `latest` release.
///
/// On press it first checks what's installed against the latest release tag:
///   * not installed        → downloads and installs;
///   * newer version exists → downloads and updates (data preserved, same sig);
///   * already up to date   → shows a brief "you have the latest version"
///                            message and downloads nothing.
///
/// The "available version" is the release `tag_name` (e.g. `v2.0.10`), which
/// matches both companion apps' `versionName`. The installed version comes from
/// the package manager via [FLauncherChannel.getAppVersion].
class CompanionAppButton extends StatefulWidget {
  /// Package id, e.g. `cz.smotrim.player`.
  final String packageName;

  /// GitHub repo as `owner/name`, e.g. `davnozdu/smotrim-player`.
  final String repo;

  /// Exact asset name to prefer (e.g. the universal `app-release.apk`). When
  /// null, or when no asset matches, the first `.apk` asset is used.
  final String? preferredAsset;

  /// Temp file name used while downloading.
  final String tempFileName;

  /// Label selectors, resolved against the current locale in [build].
  final String Function(AppLocalizations) installLabel;
  final String Function(AppLocalizations) updateLabel;
  final String Function(AppLocalizations) downloadingLabel;
  final String Function(AppLocalizations) checkingLabel;
  final String Function(AppLocalizations) upToDateLabel;

  const CompanionAppButton({
    super.key,
    required this.packageName,
    required this.repo,
    required this.tempFileName,
    required this.installLabel,
    required this.updateLabel,
    required this.downloadingLabel,
    required this.checkingLabel,
    required this.upToDateLabel,
    this.preferredAsset,
  });

  @override
  State<CompanionAppButton> createState() => _CompanionAppButtonState();
}

enum _Phase { idle, checking, downloading }

class _CompanionAppButtonState extends State<CompanionAppButton> {
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
      final installed = await _channel.isAppInstalled(widget.packageName);
      if (mounted) setState(() => _installed = installed);
    } catch (_) {}
  }

  /// Fetches the latest release: returns (tagName, apkDownloadUrl).
  Future<(String, String)?> _fetchLatest(HttpClient client) async {
    final url = "https://api.github.com/repos/${widget.repo}/releases/latest";
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, "SmotrimLauncher");
    request.headers.set(HttpHeaders.acceptHeader, "application/vnd.github+json");
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;

    final json = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final tag = (json["tagName"] as String?) ?? (json["tag_name"] as String?);
    final assets = (json["assets"] as List?) ?? const [];

    String? apkUrl;
    if (widget.preferredAsset != null) {
      for (final a in assets) {
        if ((a["name"] as String?) == widget.preferredAsset) {
          apkUrl = a["browser_download_url"] as String?;
          break;
        }
      }
    }
    apkUrl ??= () {
      for (final a in assets) {
        final name = (a["name"] as String?) ?? "";
        if (name.toLowerCase().endsWith(".apk")) return a["browser_download_url"] as String?;
      }
      return null;
    }();

    if (tag == null || apkUrl == null) return null;
    return (tag, apkUrl);
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

  void _showSnack(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _onPressed() async {
    if (_phase != _Phase.idle) return;
    setState(() => _phase = _Phase.checking);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final latest = await _fetchLatest(client);
      if (latest == null) {
        debugPrint("${widget.repo}: failed to resolve latest release");
        return;
      }
      final (tag, apkUrl) = latest;

      final installedVersion = await _channel.getAppVersion(widget.packageName);
      // Already installed and not older than the latest release → nothing to do.
      if (installedVersion != null && _compareVersions(tag, installedVersion) <= 0) {
        if (mounted) setState(() => _phase = _Phase.idle);
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          _showSnack("${widget.upToDateLabel(l)} ($installedVersion)");
        }
        return;
      }

      if (mounted) {
        setState(() {
          _phase = _Phase.downloading;
          _progress = 0;
        });
      }

      final request = await client.getUrl(Uri.parse(apkUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return;

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/${widget.tempFileName}");
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
      debugPrint("${widget.repo} install failed: $e");
    } finally {
      client.close();
      if (mounted) setState(() => _phase = _Phase.idle);
      _refreshInstalled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    final String label;
    final IconData icon;
    switch (_phase) {
      case _Phase.checking:
        label = widget.checkingLabel(l);
        icon = Icons.search;
        break;
      case _Phase.downloading:
        label = "${widget.downloadingLabel(l)} ${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%";
        icon = Icons.download;
        break;
      case _Phase.idle:
        label = _installed ? widget.updateLabel(l) : widget.installLabel(l);
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
