/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/l10n/app_localizations.dart';

enum _Phase { checking, upToDate, available, downloading }

/// Settings dialog that force-checks the launcher's latest GitHub release and,
/// if a newer one exists, downloads and installs it.
class LauncherUpdateDialog extends StatefulWidget {
  const LauncherUpdateDialog({super.key});

  @override
  State<LauncherUpdateDialog> createState() => _LauncherUpdateDialogState();
}

class _LauncherUpdateDialogState extends State<LauncherUpdateDialog> {
  _Phase _phase = _Phase.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final updateService = context.read<UpdateService>();
    setState(() => _phase = _Phase.checking);
    await updateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _phase = updateService.updateAvailable ? _Phase.available : _Phase.upToDate);
  }

  Future<void> _install() async {
    final updateService = context.read<UpdateService>();
    setState(() => _phase = _Phase.downloading);
    await updateService.downloadAndInstall();
    // The system installer takes over; if the user cancels we land back here.
    if (mounted) setState(() => _phase = _Phase.available);
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final updateService = context.watch<UpdateService>();

    late final Widget content;
    late final List<Widget> actions;

    switch (_phase) {
      case _Phase.checking:
        content = _busy(l.checkingForUpdates);
        actions = const [];
        break;
      case _Phase.upToDate:
        content = Text(l.alreadyUpToDate);
        actions = [TextButton(autofocus: true, onPressed: _close, child: Text(l.close))];
        break;
      case _Phase.available:
        content = Text(l.updateAvailable(updateService.latestVersionName ?? ""));
        actions = [
          TextButton(onPressed: _close, child: Text(l.close)),
          ElevatedButton(autofocus: true, onPressed: _install, child: Text(l.install)),
        ];
        break;
      case _Phase.downloading:
        final percent = (updateService.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);
        content = _busy("${l.updateDownloading} $percent%");
        actions = const [];
        break;
    }

    return AlertDialog(
      title: Text(l.checkForUpdates),
      content: content,
      actions: actions,
    );
  }

  Widget _busy(String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Flexible(child: Text(text)),
        ],
      );
}
