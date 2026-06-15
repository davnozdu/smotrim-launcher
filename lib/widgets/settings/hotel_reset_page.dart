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

/// Checkout reset: per-app toggles for what to wipe. Kept apps (e.g. the TV
/// app) stay signed in; the choice is remembered. Hotel mode and the admin
/// config are preserved.
class HotelResetPage extends StatefulWidget {
  static const String routeName = "hotel_reset";

  const HotelResetPage({super.key});

  @override
  State<HotelResetPage> createState() => _HotelResetPageState();
}

class _HotelResetPageState extends State<HotelResetPage> {
  final Map<String, bool> _clear = {}; // package -> wipe on reset?

  @override
  void initState() {
    super.initState();
    final hotel = context.read<HotelModeService>();
    for (final pkg in hotel.allowedPackages) {
      _clear[pkg] = !hotel.keepOnReset.contains(pkg);
    }
  }

  Future<void> _doReset() async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    final toClear = _clear.entries.where((e) => e.value).map((e) => e.key).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.hotelResetGuest),
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

    // Remember the keep/clear choice for next checkout.
    for (final entry in _clear.entries) {
      await hotel.setKeepOnReset(entry.key, !entry.value);
    }
    await hotel.clearGuestData(toClear);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l.hotelResetDone)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hotel = context.watch<HotelModeService>();
    final apps = context.read<AppsService>().applications;
    String nameOf(String pkg) {
      for (final a in apps) {
        if (a.packageName == pkg) return a.name;
      }
      return pkg;
    }

    return Column(
      children: [
        Text(l.hotelResetGuest, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.hotelResetGuestDesc, style: Theme.of(context).textTheme.bodySmall),
                ),
                for (final pkg in hotel.allowedPackages)
                  RoundedSwitchListTile(
                    value: _clear[pkg] ?? true,
                    onChanged: (v) => setState(() => _clear[pkg] = v),
                    title: Text(nameOf(pkg), style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.android),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FocusableSettingsTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    title: Text(l.hotelDoReset, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _doReset,
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
