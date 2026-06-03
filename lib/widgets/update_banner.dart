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

/// Focusable prompt shown on the home screen when a newer release is available.
/// Activating it downloads the APK and launches the system installer.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<UpdateService>(
      builder: (context, updateService, _) {
        if (!updateService.updateAvailable && !updateService.isDownloading) {
          return const SizedBox.shrink();
        }

        final downloading = updateService.isDownloading;
        final version = updateService.latestVersionName ?? "";
        final percent = (updateService.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);

        final String text = downloading
            ? "${localizations.updateDownloading} $percent%"
            : "${localizations.updateAvailable(version)} — ${localizations.updateTapToInstall}";

        void activate() {
          if (!downloading) updateService.downloadAndInstall();
        }

        return Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => activate()),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => activate()),
          },
          child: Focus(
            onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _focused ? Colors.green.shade700 : Colors.green.shade900,
                borderRadius: BorderRadius.circular(8),
                elevation: _focused ? 12 : 0,
                shadowColor: Colors.black,
                child: InkWell(
                  onTap: activate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: _focused ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(downloading ? Icons.downloading : Icons.system_update,
                            color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
