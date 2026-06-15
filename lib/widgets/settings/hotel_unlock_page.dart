/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/hotel_mode_service.dart';
import 'hotel_admin_page.dart';
import 'pin_pad.dart';

/// The only screen shown in Settings while hotel mode is locked: enter the
/// 8-digit PIN (or the service master code) to open the admin panel.
class HotelUnlockPage extends StatefulWidget {
  static const String routeName = "hotel_unlock";

  const HotelUnlockPage({super.key});

  @override
  State<HotelUnlockPage> createState() => _HotelUnlockPageState();
}

class _HotelUnlockPageState extends State<HotelUnlockPage> {
  String? _error;

  Future<void> _try(String code) async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    if (hotel.lockoutRemaining > Duration.zero) {
      setState(() => _error = l.hotelLockedOut);
      return;
    }
    final ok = await hotel.verifyCode(code);
    if (!mounted) return;
    if (ok) {
      // PIN accepted — open the admin panel (does NOT leave hotel mode).
      Navigator.of(context).pushReplacementNamed(HotelAdminPage.routeName);
    } else {
      setState(() => _error =
          hotel.lockoutRemaining > Duration.zero ? l.hotelLockedOut : l.hotelWrongPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(l.hotelUnlock, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        const SizedBox(height: 8),
        Text(l.hotelEnterPin, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: PinPad(onCompleted: _try, errorText: _error),
          ),
        ),
      ],
    );
  }
}
