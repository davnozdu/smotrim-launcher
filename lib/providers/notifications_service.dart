import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsService extends ChangeNotifier {
  final FLauncherChannel _channel;
  Map<String, int> _notificationCounts = {};
  bool _hasPermission = false;
  bool _hasOverlayPermission = false;
  bool _systemPopupEnabled = false;
  bool _initialized = false;
  StreamSubscription? _subscription;
  // One generation counter per concurrent operation. They used to share a single
  // counter, so calling e.g. checkPermission() while _init() was still running
  // bumped it and made _init() abort half-way — leaving the service permanently
  // uninitialised with no notification listener attached.
  int _initCallCount = 0;
  int _permissionCallCount = 0;
  int _overlayCallCount = 0;
  int _refreshCallCount = 0;
  bool _disposed = false;
  SharedPreferences? _prefs;

  NotificationsService(this._channel) {
    _init();
  }

  Map<String, int> get notificationCounts => Map.unmodifiable(_notificationCounts);
  bool get hasPermission => _hasPermission;
  bool get hasOverlayPermission => _hasOverlayPermission;
  bool get systemPopupEnabled => _systemPopupEnabled;
  bool get initialized => _initialized;

  int getNotificationCount(String packageName) {
    return _notificationCounts[packageName] ?? 0;
  }

  Future<void> _init() async {
    final localCallCount = ++_initCallCount;

    try {
      _prefs = await SharedPreferences.getInstance();
      if (localCallCount != _initCallCount || _disposed) return;

      _systemPopupEnabled = _prefs?.getBool('system_notifications_popup') ?? false;

      final bool allowed = await _channel.checkNotificationListenerPermission();
      if (localCallCount != _initCallCount || _disposed) return;

      _hasPermission = allowed;

      final bool overlayAllowed = await _channel.checkOverlayPermission();
      if (localCallCount != _initCallCount || _disposed) return;

      _hasOverlayPermission = overlayAllowed;

      if (_hasPermission) {
        final List<Map<dynamic, dynamic>> list = await _channel.getActiveNotifications();
        if (localCallCount != _initCallCount || _disposed) return;

        _updateNotificationCounts(list);

        _subscription = _channel.addNotificationsChangedListener((eventList) {
          _updateNotificationCounts(eventList);
        });
      }
    } catch (e) {
      // A failed permission probe must not leave the service stuck as
      // uninitialised; it just means there are no badges to show.
      debugPrint('NotificationsService init failed: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> checkPermission() async {
    final localCallCount = ++_permissionCallCount;
    final bool allowed = await _channel.checkNotificationListenerPermission();
    if (localCallCount != _permissionCallCount) return;

    if (_hasPermission != allowed) {
      _hasPermission = allowed;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    if (!_hasPermission) return;

    final localCallCount = ++_refreshCallCount;
    final List<Map<dynamic, dynamic>> list = await _channel.getActiveNotifications();
    if (localCallCount != _refreshCallCount) return;

    _updateNotificationCounts(list);
  }

  void _updateNotificationCounts(List<Map<dynamic, dynamic>> list) {
    final Map<String, int> newCounts = {};
    for (final item in list) {
      final String? pkg = item['packageName'] as String?;
      final int? count = item['count'] as int?;
      if (pkg != null && count != null) {
        newCounts[pkg] = count;
      }
    }

    // Direct comparison to avoid unnecessary notifies
    bool changed = false;
    if (_notificationCounts.length != newCounts.length) {
      changed = true;
    } else {
      for (final key in newCounts.keys) {
        if (_notificationCounts[key] != newCounts[key]) {
          changed = true;
          break;
        }
      }
    }

    if (changed) {
      _notificationCounts = newCounts;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    await _channel.requestNotificationListenerPermission();
    // Re-check after returning from settings (handled externally or via polling/resume)
  }

  Future<void> checkOverlayPermission() async {
    final localCallCount = ++_overlayCallCount;
    final bool allowed = await _channel.checkOverlayPermission();
    if (localCallCount != _overlayCallCount) return;

    if (_hasOverlayPermission != allowed) {
      _hasOverlayPermission = allowed;
      notifyListeners();
    }
  }

  Future<void> requestOverlayPermission() async {
    await _channel.requestOverlayPermission();
  }

  Future<void> setSystemPopupEnabled(bool enabled) async {
    _systemPopupEnabled = enabled;
    await _prefs?.setBool('system_notifications_popup', enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }

  // Platform events can arrive after disposal; notifying then throws.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
