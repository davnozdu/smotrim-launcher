/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flutter/services.dart';

class FLauncherChannel {
  static const _methodChannel = MethodChannel('cz.smotrim.launcher/method');
  static const _appsEventChannel = EventChannel('cz.smotrim.launcher/event_apps');
  static const _notificationsEventChannel = EventChannel('cz.smotrim.launcher/event_notifications');

  Future<List<Map<dynamic, dynamic>>> getApplications() async {
    List<Map<dynamic, dynamic>>? applications = await _methodChannel.invokeListMethod("getApplications");
    return applications!;
  }

  Future<Uint8List> getApplicationBanner(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationBanner", packageName);
    return bytes;
  }

  Future<Uint8List> getApplicationIcon(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationIcon", packageName);
    return bytes;
  }

  Future<void> launchActivityFromAction(String action) async => await _methodChannel.invokeMethod('launchActivityFromAction', action);

  Future<void> launchApp(String packageName) async => await _methodChannel.invokeMethod('launchApp', packageName);

  Future<void> openSettings() async => await _methodChannel.invokeMethod('openSettings');

  Future<void> openAppInfo(String packageName) async => await _methodChannel.invokeMethod('openAppInfo', packageName);

  Future<void> uninstallApp(String packageName) async => await _methodChannel.invokeMethod('uninstallApp', packageName);

  Future<bool> installApk(String filePath) async => await _methodChannel.invokeMethod('installApk', filePath);

  Future<bool> isAppInstalled(String packageName) async => await _methodChannel.invokeMethod('isAppInstalled', packageName);

  /// Installed app's versionName, or null if it isn't installed.
  Future<String?> getAppVersion(String packageName) async =>
      await _methodChannel.invokeMethod('getAppVersion', packageName);

  Future<bool> isDeviceOwner() async =>
      await _methodChannel.invokeMethod('isDeviceOwner') ?? false;

  /// Enables hotel-mode kiosk pinned to [allowedPackages] (Device Owner only).
  Future<bool> enableHotelMode(List<String> allowedPackages) async =>
      await _methodChannel.invokeMethod('enableHotelMode', allowedPackages) ?? false;

  Future<bool> disableHotelMode() async =>
      await _methodChannel.invokeMethod('disableHotelMode') ?? false;

  /// Wipes per-app data of the given packages (Device Owner, API 28+).
  Future<bool> clearGuestData(List<String> packages) async =>
      await _methodChannel.invokeMethod('clearGuestData', packages) ?? false;

  /// Full factory reset of the device (Device Owner). Irreversible.
  Future<bool> factoryReset() async =>
      await _methodChannel.invokeMethod('factoryReset') ?? false;

  Future<bool> isDefaultLauncher() async => await _methodChannel.invokeMethod('isDefaultLauncher');

  Future<bool> checkForGetContentAvailability() async =>
      await _methodChannel.invokeMethod("checkForGetContentAvailability");

  /// Active network info: { networkAccess, internetAccess, networkType, wirelessSignalLevel }.
  Future<Map<String, dynamic>> getActiveNetworkInformation() async {
    final map = await _methodChannel.invokeMethod("getActiveNetworkInformation");
    return (map as Map).cast<String, dynamic>();
  }

  Future<void> openWifiSettings() async =>
      await _methodChannel.invokeMethod("openWifiSettings");

  Future<void> openDefaultLauncherSettings() async =>
      await _methodChannel.invokeMethod("openDefaultLauncherSettings");

  Future<void> startAmbientMode() async => await _methodChannel.invokeMethod("startAmbientMode");

  void addAppsChangedListener(void Function(Map<String, dynamic>) listener) =>
      _appsEventChannel.receiveBroadcastStream().listen((event) {
        Map<dynamic, dynamic> eventMap = event;
        listener(eventMap.cast<String, dynamic>());
      });

  Future<List<Map<dynamic, dynamic>>> getTvInputs() async {
    try {
      final List<dynamic> inputs = await _methodChannel.invokeMethod("getTvInputs");
      return inputs.cast<Map<dynamic, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> launchTvInput(String inputId) async {
    try {
      final bool success = await _methodChannel.invokeMethod("launchTvInput", inputId);
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkNotificationListenerPermission() async =>
      await _methodChannel.invokeMethod("checkNotificationListenerPermission");

  Future<void> requestNotificationListenerPermission() async =>
      await _methodChannel.invokeMethod("requestNotificationListenerPermission");

  Future<bool> checkOverlayPermission() async =>
      await _methodChannel.invokeMethod("checkOverlayPermission");

  Future<void> requestOverlayPermission() async =>
      await _methodChannel.invokeMethod("requestOverlayPermission");

  Future<List<Map<dynamic, dynamic>>> getActiveNotifications() async {
    try {
      final List<dynamic> list = await _methodChannel.invokeMethod("getActiveNotifications");
      return list.cast<Map<dynamic, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  StreamSubscription addNotificationsChangedListener(void Function(List<Map<dynamic, dynamic>>) listener) =>
      _notificationsEventChannel.receiveBroadcastStream().listen((event) {
        final List<dynamic> eventList = event;
        listener(eventList.cast<Map<dynamic, dynamic>>());
      });
}
