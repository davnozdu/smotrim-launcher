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
/// glance whether the network is available. Polls a cheap native call every few
/// seconds; no permissions and no traffic statistics.
class NetworkStatusIcon extends StatefulWidget {
  const NetworkStatusIcon({super.key});

  @override
  State<NetworkStatusIcon> createState() => _NetworkStatusIconState();
}

class _NetworkStatusIconState extends State<NetworkStatusIcon> {
  static const int _networkTypeEthernet = 2; // NetworkUtils.NETWORK_TYPE_ETHERNET

  final FLauncherChannel _channel = FLauncherChannel();
  Timer? _timer;
  bool _available = false;
  bool _ethernet = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final info = await _channel.getActiveNetworkInformation();
      final available = (info["networkAccess"] as bool?) ?? false;
      final ethernet = (info["networkType"] as int?) == _networkTypeEthernet;
      if (mounted && (available != _available || ethernet != _ethernet)) {
        setState(() {
          _available = available;
          _ethernet = ethernet;
        });
      }
    } catch (_) {
      if (mounted && _available) setState(() => _available = false);
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
