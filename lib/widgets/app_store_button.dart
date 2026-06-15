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
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/widgets/app_store_page.dart';

/// Bottom-row button that opens the Smotrim app store in a WebView.
///
/// [compact] picks the short "AppHub" label when the row is too narrow to fit
/// the full "App Store" wording alongside the other buttons.
class AppStoreButton extends StatefulWidget {
  final bool compact;

  const AppStoreButton({super.key, this.compact = false});

  @override
  State<AppStoreButton> createState() => _AppStoreButtonState();
}

class _AppStoreButtonState extends State<AppStoreButton> {
  bool _focused = false;

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppStorePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;
    final label = widget.compact ? l.appStoreShort : l.appStore;

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _open()),
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
              onTap: _open,
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
                    const Icon(Icons.storefront, color: Colors.white, size: 28),
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
