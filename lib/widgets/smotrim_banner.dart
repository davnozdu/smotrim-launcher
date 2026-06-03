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

/// Brand information banner shown at the bottom of the home screen.
/// Informational only (not focusable) and laid out as a bottom bar so it
/// never overlaps the apps grid.
class SmotrimBanner extends StatelessWidget {
  static const String phone = "+420608210867";

  const SmotrimBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    const textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.white,
      shadows: [
        Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 4),
      ],
    );

    return IgnorePointer(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            Text(localizations.bannerTagline, style: textStyle),
            const Text(
              phone,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
