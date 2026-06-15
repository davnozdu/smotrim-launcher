/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/hotel_mode_service.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'focusable_settings_tile.dart';
import 'pin_pad.dart';

/// Owner-only setup for hotel mode: set the 8-digit PIN, pick the apps a guest
/// may use, then activate the kiosk.
class HotelModePage extends StatefulWidget {
  static const String routeName = "hotel_mode";

  const HotelModePage({super.key});

  @override
  State<HotelModePage> createState() => _HotelModePageState();
}

class _HotelModePageState extends State<HotelModePage> {
  late Set<String> _allowed;
  bool? _deviceOwner;

  @override
  void initState() {
    super.initState();
    _allowed = {...context.read<HotelModeService>().allowedPackages};
    context.read<HotelModeService>().isDeviceOwner().then((v) {
      if (mounted) setState(() => _deviceOwner = v);
    });
  }

  Future<void> _setPin() async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.hotelSetPin),
        content: SizedBox(
          width: 320,
          child: PinPad(onCompleted: (code) async {
            await hotel.setPin(code);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          }),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String? _autoLaunchName(List<App> apps, String? pkg) {
    if (pkg == null) return null;
    for (final a in apps) {
      if (a.packageName == pkg) return a.name;
    }
    return pkg;
  }

  Future<void> _pickAutoLaunch(List<App> apps) async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    // Only apps currently ticked as allowed can be auto-launched.
    final choices = apps.where((a) => _allowed.contains(a.packageName)).toList();
    await showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l.hotelAutoLaunch),
        children: [
          SimpleDialogOption(
            onPressed: () {
              hotel.setAutoLaunch(null);
              Navigator.of(dialogContext).pop();
            },
            child: Text(l.hotelAutoLaunchNone),
          ),
          for (final a in choices)
            SimpleDialogOption(
              onPressed: () {
                hotel.setAutoLaunch(a.packageName);
                Navigator.of(dialogContext).pop();
              },
              child: Text(a.name),
            ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _activate() async {
    final l = AppLocalizations.of(context)!;
    final hotel = context.read<HotelModeService>();
    if (!hotel.hasPin) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l.hotelPinRequired)));
      return;
    }
    await hotel.enable(_allowed.toList());
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hotel = context.watch<HotelModeService>();
    final apps = context.watch<AppsService>().applications.where((a) => !a.hidden).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      children: [
        Text(l.hotelMode, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.hotelModeDesc, style: Theme.of(context).textTheme.bodySmall),
                ),
                if (_deviceOwner == false)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.hotelNeedDeviceOwner,
                        style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.password),
                  title: Text(l.hotelSetPin, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: Text(hotel.hasPin ? l.statusGranted : "—",
                      style: TextStyle(color: hotel.hasPin ? Colors.green : Colors.orange)),
                  onPressed: _setPin,
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(l.hotelAutoLaunch, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: Text(_autoLaunchName(apps, hotel.autoLaunchPackage) ?? l.hotelAutoLaunchNone,
                      style: Theme.of(context).textTheme.bodySmall),
                  onPressed: () => _pickAutoLaunch(apps),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(l.hotelAllowedApps, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final app in apps)
                  RoundedSwitchListTile(
                    value: _allowed.contains(app.packageName),
                    onChanged: (v) => setState(() {
                      if (v) {
                        _allowed.add(app.packageName);
                      } else {
                        _allowed.remove(app.packageName);
                      }
                    }),
                    title: Text(app.name, style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.android),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FocusableSettingsTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l.hotelActivate, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _activate,
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
