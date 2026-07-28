/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flauncher/flauncher_channel.dart';

/// Small, non-interactive status icon next to the settings gear that shows at a
/// glance whether the network is available.
///
/// Reads the state once at startup and then follows the platform's network
/// callbacks. It used to poll every 15 seconds instead, which woke the launcher
/// up 5760 times a day to learn nothing.
class NetworkStatusIcon extends StatefulWidget {
  const NetworkStatusIcon({super.key});

  @override
  State<NetworkStatusIcon> createState() => _NetworkStatusIconState();
}

class _NetworkStatusIconState extends State<NetworkStatusIcon> {
  static const int _networkTypeEthernet = 2; // NetworkUtils.NETWORK_TYPE_ETHERNET

  final FLauncherChannel _channel = FLauncherChannel();
  StreamSubscription? _subscription;
  bool _available = false;
  bool _ethernet = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = _channel.addNetworkChangedListener(_apply);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      _apply(await _channel.getActiveNetworkInformation());
    } catch (_) {
      if (mounted && _available) setState(() => _available = false);
    }
  }

  void _apply(Map<String, dynamic> info) {
    final available = (info["networkAccess"] as bool?) ?? false;
    final ethernet = (info["networkType"] as int?) == _networkTypeEthernet;
    if (mounted && (available != _available || ethernet != _ethernet)) {
      setState(() {
        _available = available;
        _ethernet = ethernet;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon = !_available
        ? Icons.wifi_off
        : (_ethernet ? Icons.settings_ethernet : Icons.wifi);
    final Color color = _available ? Colors.white70 : Colors.white30;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
