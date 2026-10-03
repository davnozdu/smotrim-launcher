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
  static const String brand = "smotrim.cz";
  static const String phone = "+420608210867";
  static const String newsSite = "24n.cz";

  // Bright tones: the bar sits on a dark wallpaper, where darker reds and
  // blues would barely read.
  static const Color _brandBlue = Color(0xFF448AFF);
  static const Color _newsRed = Color(0xFFFF3D3D);
  static const Color _newsYellow = Color(0xFFFFD600);

  static const List<Shadow> _shadows = [
    Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 4),
  ];

  const SmotrimBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    const baseStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      shadows: _shadows,
    );

    return IgnorePointer(
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
            const Text(
              brand,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _brandBlue,
                shadows: _shadows,
              ),
            ),
            const Text(
              phone,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                decorationThickness: 1.5,
                shadows: _shadows,
              ),
            ),
            // The news link is the eye-catcher of the bar: a red site name and
            // a yellow description, both heavier than the text around them.
            Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: "— "),
                  const TextSpan(
                    text: newsSite,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _newsRed,
                    ),
                  ),
                  TextSpan(
                    text: " — ${localizations.bannerTagline}",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _newsYellow,
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
