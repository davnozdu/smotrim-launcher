/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flauncher_channel.dart';

/// Hotel (kiosk) mode. Real lockdown is enforced natively when the launcher is
/// a Device Owner (see MainActivity#enableHotelMode); this service owns the
/// 8-digit PIN, the allowed-apps whitelist and the locked/unlocked state.
class HotelModeService extends ChangeNotifier {
  static const _kEnabled = "hotel_enabled";
  static const _kPinHash = "hotel_pin_hash";
  static const _kSalt = "hotel_salt";
  static const _kAllowed = "hotel_allowed";
  static const _kKeep = "hotel_keep_on_reset"; // packages NOT wiped on checkout
  static const _kFails = "hotel_fails";
  static const _kLockoutUntil = "hotel_lockout_until";

  // No compiled-in master/back-door code exists by design: the only way into
  // the admin panel is the owner-set 8-digit PIN. A forgotten PIN can only be
  // recovered by factory-resetting (re-provisioning) the device.
  static const int _maxFails = 5;
  static const Duration _lockoutDuration = Duration(minutes: 1);

  final SharedPreferences _prefs;
  final FLauncherChannel _channel;

  HotelModeService(this._prefs, this._channel) {
    // Re-assert the kiosk on launch if it was active (native re-asserts on
    // resume too; this also re-applies the policy after an app update).
    if (enabled) {
      _channel.enableHotelMode(allowedPackages);
    }
  }

  bool get enabled => _prefs.getBool(_kEnabled) ?? false;
  bool get hasPin => (_prefs.getString(_kPinHash) ?? "").isNotEmpty;
  List<String> get allowedPackages => _prefs.getStringList(_kAllowed) ?? const [];

  Future<bool> isDeviceOwner() => _channel.isDeviceOwner();

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode("$salt|$pin")).toString();

  Future<void> setPin(String pin) async {
    final salt = "${DateTime.now().microsecondsSinceEpoch}-${pin.length}";
    await _prefs.setString(_kSalt, salt);
    await _prefs.setString(_kPinHash, _hash(pin, salt));
    notifyListeners();
  }

  bool _pinMatches(String pin) {
    final hash = _prefs.getString(_kPinHash) ?? "";
    if (hash.isEmpty) return false;
    final salt = _prefs.getString(_kSalt) ?? "";
    return _hash(pin, salt) == hash;
  }

  Duration get lockoutRemaining {
    final until = _prefs.getInt(_kLockoutUntil) ?? 0;
    final ms = until - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  /// Packages kept (not wiped) on a checkout reset — e.g. the TV/IPTV app.
  Set<String> get keepOnReset => (_prefs.getStringList(_kKeep) ?? const []).toSet();

  Future<void> setKeepOnReset(String pkg, bool keep) async {
    final set = keepOnReset;
    if (keep) {
      set.add(pkg);
    } else {
      set.remove(pkg);
    }
    await _prefs.setStringList(_kKeep, set.toList());
    notifyListeners();
  }

  /// Wipes data of the whitelisted guest apps except those kept; admin config
  /// (PIN, whitelist) and hotel mode itself stay intact. Returns true if applied.
  Future<bool> clearGuestData(List<String> packages) async {
    if (packages.isEmpty) return true;
    return _channel.clearGuestData(packages);
  }

  Future<bool> factoryReset() => _channel.factoryReset();

  /// Enables the kiosk pinned to [allowed]. Requires a PIN to already be set.
  /// Returns true if the native Device-Owner policy was applied.
  Future<bool> enable(List<String> allowed) async {
    await _prefs.setStringList(_kAllowed, allowed);
    final applied = await _channel.enableHotelMode(allowed);
    await _prefs.setBool(_kEnabled, true);
    notifyListeners();
    return applied;
  }

  Future<void> disable() async {
    await _channel.disableHotelMode();
    await _prefs.setBool(_kEnabled, false);
    notifyListeners();
  }

  /// Verifies the admin PIN (or service master code). Does NOT leave hotel mode
  /// — on success the caller opens the admin panel. Wrong codes count toward a
  /// lockout. Returns true on success.
  Future<bool> verifyCode(String code) async {
    if (lockoutRemaining > Duration.zero) return false;
    if (_pinMatches(code)) {
      await _prefs.setInt(_kFails, 0);
      notifyListeners();
      return true;
    }
    final fails = (_prefs.getInt(_kFails) ?? 0) + 1;
    if (fails >= _maxFails) {
      await _prefs.setInt(_kFails, 0);
      await _prefs.setInt(
          _kLockoutUntil, DateTime.now().millisecondsSinceEpoch + _lockoutDuration.inMilliseconds);
    } else {
      await _prefs.setInt(_kFails, fails);
    }
    notifyListeners();
    return false;
  }
}
