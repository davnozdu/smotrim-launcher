/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/hotel_mode_service.dart';
import 'focusable_settings_tile.dart';
import 'hotel_reset_page.dart';
import 'hotel_reset_apps_page.dart';
import 'set_pin_dialog.dart';

/// Shown after the admin PIN is accepted while hotel mode is locked. Lets staff
/// reset guest data, leave hotel mode, or factory-reset the device — without
/// any of these being reachable by a guest.
class HotelAdminPage extends StatelessWidget {
  static const String routeName = "hotel_admin";

  const HotelAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(l.hotelAdminTitle, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(l.hotelResetGuest, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(HotelResetPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.apps_outlined),
                  title: Text(l.hotelResetByApps, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(HotelResetAppsPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.password),
                  title: Text(l.hotelChangePin, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () async {
                    final code = await showSetPinDialog(context);
                    if (code != null && context.mounted) {
                      await context.read<HotelModeService>().setPin(code);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(SnackBar(content: Text(l.hotelPinChanged)));
                      }
                    }
                  },
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.lock_open),
                  title: Text(l.hotelExit, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () async {
                    await context.read<HotelModeService>().disable();
                    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
                const Divider(),
                FocusableSettingsTile(
                  leading: const Icon(Icons.restore, color: Colors.redAccent),
                  title: Text(l.hotelFactoryReset,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent)),
                  onPressed: () => _confirmFactory(context, l),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmFactory(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.hotelFactoryReset),
        content: Text(l.hotelFactoryResetWarn),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.hotelCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.read<HotelModeService>().factoryReset();
            },
            child: Text(l.hotelReset, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
