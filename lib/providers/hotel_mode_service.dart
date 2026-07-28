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
import 'dart:math';

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
  static const _kAutoLaunch = "hotel_autolaunch"; // app force-launched on boot
  static const _kKeep = "hotel_keep_on_reset"; // packages NOT wiped on checkout
  static const _kFails = "hotel_fails";
  static const _kLockoutUntil = "hotel_lockout_until";
  // Which scheme _kPinHash was produced with; absent means the pre-stretching
  // single-round hash.
  static const _kPinAlgo = "hotel_pin_algo";
  static const _algoPbkdf2 = "pbkdf2-sha256";

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

  /// App force-launched on boot in hotel mode (null = none).
  String? get autoLaunchPackage {
    final p = _prefs.getString(_kAutoLaunch) ?? "";
    return p.isEmpty ? null : p;
  }

  Future<void> setAutoLaunch(String? pkg) async {
    await _prefs.setString(_kAutoLaunch, pkg ?? "");
    await _channel.setHotelAutoLaunch(pkg ?? "");
    notifyListeners();
  }

  Future<bool> isDeviceOwner() => _channel.isDeviceOwner();

  /// Length-independent, non-short-circuiting comparison, so the time taken
  /// does not leak how much of the hash matched.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> setPin(String pin) async {
    // A random salt. The old one was derived from the clock and the PIN length,
    // both of which an attacker can narrow down to a handful of candidates.
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final hash = await compute(_pbkdf2, (pin: pin, salt: salt));
    await _prefs.setString(_kSalt, salt);
    await _prefs.setString(_kPinHash, hash);
    await _prefs.setString(_kPinAlgo, _algoPbkdf2);
    notifyListeners();
  }

  Future<bool> _pinMatches(String pin) async {
    final hash = _prefs.getString(_kPinHash) ?? "";
    if (hash.isEmpty) return false;
    final salt = _prefs.getString(_kSalt) ?? "";

    if (_prefs.getString(_kPinAlgo) == _algoPbkdf2) {
      return _constantTimeEquals(
          await compute(_pbkdf2, (pin: pin, salt: salt)), hash);
    }

    // Legacy single-round hash, from before the PIN was stretched. Verify with
    // the old scheme so boxes provisioned by an earlier build keep working, then
    // transparently upgrade: a launcher update must never lock an admin out.
    if (!_constantTimeEquals(_legacyHash(pin, salt), hash)) return false;
    await setPin(pin);
    return true;
  }

  Duration get lockoutRemaining {
    final until = _prefs.getInt(_kLockoutUntil) ?? 0;
    if (until == 0) return Duration.zero;

    // Measured against the monotonic clock: wall-clock deadlines are trivially
    // skipped by changing the device's time.
    final elapsed = _elapsedRealtime();
    final ms = until - elapsed;
    if (ms <= 0) return Duration.zero;
    // A reboot resets the monotonic clock, which would otherwise leave a
    // deadline in the far "future" and lock the admin out permanently.
    if (ms > _lockoutDuration.inMilliseconds) return Duration.zero;
    return Duration(milliseconds: ms);
  }

  /// Milliseconds since process start — monotonic and immune to clock changes.
  static final Stopwatch _uptime = Stopwatch()..start();

  static int _elapsedRealtime() => _uptime.elapsedMilliseconds;

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
    await _channel.setHotelAutoLaunch(autoLaunchPackage ?? "");
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
    if (await _pinMatches(code)) {
      await _prefs.setInt(_kFails, 0);
      notifyListeners();
      return true;
    }
    final fails = (_prefs.getInt(_kFails) ?? 0) + 1;
    if (fails >= _maxFails) {
      await _prefs.setInt(_kFails, 0);
      await _prefs.setInt(
          _kLockoutUntil, _elapsedRealtime() + _lockoutDuration.inMilliseconds);
    } else {
      await _prefs.setInt(_kFails, fails);
    }
    notifyListeners();
    return false;
  }
}

/// Single-round SHA-256 as used by builds before the PIN was stretched.
/// Kept only so an existing PIN can still be verified once and re-hashed.
String _legacyHash(String pin, String salt) =>
    sha256.convert(utf8.encode("$salt|$pin")).toString();

// A 6-8 digit PIN has at most 10^8 candidates, so one hash round is brute-forced
// in seconds by anyone who can read the preferences file. Stretching multiplies
// that cost by the iteration count. Runs via compute() on its own isolate so the
// UI does not freeze while it works.
const int _pinHashIterations = 50000;

/// PBKDF2-HMAC-SHA256, one output block (32 bytes), hex encoded.
String _pbkdf2(({String pin, String salt}) input) {
  final hmac = Hmac(sha256, utf8.encode(input.pin));
  // Block index 1, per PBKDF2: salt || INT_32_BE(1).
  final seed = <int>[...utf8.encode(input.salt), 0, 0, 0, 1];
  var block = hmac.convert(seed).bytes;
  final result = List<int>.from(block);
  for (var i = 1; i < _pinHashIterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return result.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
