/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/hotel_mode_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'focusable_settings_tile.dart';

/// Ad-hoc per-app reset: pick exactly the apps to wipe now (data + cache).
/// Unlike the checkout reset it doesn't change the saved keep/clear config.
class HotelResetAppsPage extends StatefulWidget {
  static const String routeName = "hotel_reset_apps";

  const HotelResetAppsPage({super.key});

  @override
  State<HotelResetAppsPage> createState() => _HotelResetAppsPageState();
}

class _HotelResetAppsPageState extends State<HotelResetAppsPage> {
  final Set<String> _selected = {};

  Future<void> _reset() async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.hotelResetByApps),
        content: Text(l.hotelResetConfirmMsg),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.hotelCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.hotelReset, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await hotel.clearGuestData(_selected.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l.hotelResetDone)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    final apps = context.read<AppsService>().applications;
    String nameOf(String pkg) {
      for (final a in apps) {
        if (a.packageName == pkg) return a.name;
      }
      return pkg;
    }

    return Column(
      children: [
        Text(l.hotelResetByApps, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.hotelResetByAppsDesc, style: Theme.of(context).textTheme.bodySmall),
                ),
                for (final pkg in hotel.allowedPackages)
                  RoundedSwitchListTile(
                    value: _selected.contains(pkg),
                    onChanged: (v) => setState(() {
                      if (v) {
                        _selected.add(pkg);
                      } else {
                        _selected.remove(pkg);
                      }
                    }),
                    title: Text(nameOf(pkg), style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.android),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FocusableSettingsTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    title: Text(l.hotelDoReset, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _reset,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
