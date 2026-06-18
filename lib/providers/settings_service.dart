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
import 'dart:math';

import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBarKey = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonActionKey = "back_button_action";
const _dateFormatKey = "date_format";
const _showCategoryTitlesKey = "show_category_titles";
const _showAppNamesBelowIconsKey = "show_app_names_below_icons";
const _themesKey = "app_banner_shape";
const _hideHighlightOutlineOnHomescreenKey = "hide_highlight_outline_on_homescreen";
const _appSelectorTransitionAnimationEnabledKey = "app_selector_transition_animation_enabled";
const _showDateInStatusBarKey = "show_date_in_status_bar";
const _showTimeInStatusBarKey = "show_time_in_status_bar";
const _timeFormatKey = "time_format";
const String _accentColorKey = "accent_color";
const String _screensaverClockStyleKey = "screensaver_clock_style";
const String _timeBasedWallpaperEnabledKey = "time_based_wallpaper_enabled";
const String _showInputsWidgetInStatusBarKey = "show_inputs_widget_in_status_bar";

// Subscriber identity: a unique 8-digit ID and 6-digit PIN generated once on
// this device and then kept forever (used by "become a subscriber").
const String _subscriberIdKey = "subscriber_id";
const String _subscriberPinKey = "subscriber_pin";
const int subscriberIdLength = 8;
const int subscriberPinLength = 6;

// Accent color presets (hex values)
const String ACCENT_COLOR_PURPLE = "7C4DFF";
const String ACCENT_COLOR_TEAL = "00BFA5";
const String ACCENT_COLOR_BLUE = "2979FF";
const String ACCENT_COLOR_ORANGE = "FF6D00";
const String ACCENT_COLOR_PINK = "F50057";
const String ACCENT_COLOR_GREEN = "00C853";
const String ACCENT_COLOR_WHITE = "FFFFFF";
const String ACCENT_COLOR_YELLOW = "FFD600";
const String ACCENT_COLOR_RED = "D50000";
const String ACCENT_COLOR_CYAN = "00E5FF";
const String ACCENT_COLOR_INDIGO = "536DFE";
const String ACCENT_COLOR_LIME = "AEEA00";
const String ACCENT_COLOR_AMBER = "FFAB00";
const String ACCENT_COLOR_ROSE = "FF4081";
const String ACCENT_COLOR_ICE_BLUE = "80D8FF";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  final SharedPreferences _sharedPreferences;

  late bool _appHighlightAnimationEnabled;
  late bool _appKeyClickEnabled;
  late bool _autoHideAppBarEnabled;
  late bool _showCategoryTitles;
  late bool _showAppNamesBelowIcons;
  late String _themes;
  late bool _hideHighlightOutlineOnHomescreen;
  late bool _appSelectorTransitionAnimationEnabled;
  late bool _showDateInStatusBar;
  late bool _showTimeInStatusBar;
  late String? _gradientUuid;
  late String _backButtonAction;
  late String _dateFormat;
  late String _timeFormat;
  late String _accentColorHex;
  late String _screensaverClockStyle;
  late bool _timeBasedWallpaperEnabled;
  late bool _showInputsWidgetInStatusBar;
  late String _subscriberId;
  late String _subscriberPin;

  bool get appHighlightAnimationEnabled => _appHighlightAnimationEnabled;

  bool get appKeyClickEnabled => _appKeyClickEnabled;

  bool get autoHideAppBarEnabled => _autoHideAppBarEnabled;

  bool get showCategoryTitles => _showCategoryTitles;

  bool get showAppNamesBelowIcons => _showAppNamesBelowIcons;

  String get themes => _themes;

  bool get hideHighlightOutlineOnHomescreen => _hideHighlightOutlineOnHomescreen;

  bool get appSelectorTransitionAnimationEnabled => _appSelectorTransitionAnimationEnabled;

  bool get showDateInStatusBar => _showDateInStatusBar;

  bool get showTimeInStatusBar => _showTimeInStatusBar;

  String? get gradientUuid => _gradientUuid;

  String get backButtonAction => _backButtonAction;

  String get dateFormat => _dateFormat;

  String get timeFormat => _timeFormat;

  bool get showInputsWidgetInStatusBar => _showInputsWidgetInStatusBar;

  String get accentColorHex => _accentColorHex;

  String get screensaverClockStyle => _screensaverClockStyle;

  /// The device's permanent subscriber ID (8 digits) and PIN (6 digits). They
  /// are generated once on first access and never change afterwards.
  String get subscriberId => _subscriberId;

  String get subscriberPin => _subscriberPin;

  Color get accentColor {
    final hex = accentColorHex;
    return Color(int.parse("0xFF$hex"));
  }

  SettingsService(this._sharedPreferences) {
    _appHighlightAnimationEnabled = _sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? true;
    _appKeyClickEnabled = _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;
    _autoHideAppBarEnabled = _sharedPreferences.getBool(_autoHideAppBarKey) ?? false;
    _showCategoryTitles = _sharedPreferences.getBool(_showCategoryTitlesKey) ?? true;
    _showAppNamesBelowIcons = _sharedPreferences.getBool(_showAppNamesBelowIconsKey) ?? false;
    _themes = _sharedPreferences.getString(_themesKey) ?? "modern";
    _hideHighlightOutlineOnHomescreen = _sharedPreferences.getBool(_hideHighlightOutlineOnHomescreenKey) ?? false;
    _appSelectorTransitionAnimationEnabled = _sharedPreferences.getBool(_appSelectorTransitionAnimationEnabledKey) ?? true;
    _showDateInStatusBar = _sharedPreferences.getBool(_showDateInStatusBarKey) ?? true;
    _showTimeInStatusBar = _sharedPreferences.getBool(_showTimeInStatusBarKey) ?? true;
    _gradientUuid = _sharedPreferences.getString(_gradientUuidKey);
    _backButtonAction = _sharedPreferences.getString(_backButtonActionKey) ?? BACK_BUTTON_ACTION_NOTHING;
    _dateFormat = _sharedPreferences.getString(_dateFormatKey) ?? defaultDateFormat;
    _timeFormat = _sharedPreferences.getString(_timeFormatKey) ?? defaultTimeFormat;
    _accentColorHex = _sharedPreferences.getString(_accentColorKey) ?? ACCENT_COLOR_PURPLE;
    _screensaverClockStyle = _sharedPreferences.getString(_screensaverClockStyleKey) ?? "minimal";
    _timeBasedWallpaperEnabled = _sharedPreferences.getBool(_timeBasedWallpaperEnabledKey) ?? false;
    _showInputsWidgetInStatusBar = _sharedPreferences.getBool(_showInputsWidgetInStatusBarKey) ?? true;
    _subscriberId = _loadOrCreateDigits(_subscriberIdKey, subscriberIdLength);
    _subscriberPin = _loadOrCreateDigits(_subscriberPinKey, subscriberPinLength);
  }

  static final Random _rng = Random.secure();

  // A random n-digit string whose first digit is never 0 (so it is always
  // exactly n digits long), drawn from a cryptographically secure source.
  static String _randomDigits(int n) {
    final sb = StringBuffer();
    sb.write(1 + _rng.nextInt(9));
    for (var i = 1; i < n; i++) {
      sb.write(_rng.nextInt(10));
    }
    return sb.toString();
  }

  // Returns the stored value if it is a valid n-digit string; otherwise
  // generates a fresh one, persists it (fire-and-forget) and returns it. Once
  // created the value is stable across launches and app updates.
  String _loadOrCreateDigits(String key, int length) {
    final existing = _sharedPreferences.getString(key);
    if (existing != null && existing.length == length && int.tryParse(existing) != null) {
      return existing;
    }
    final value = _randomDigits(length);
    _sharedPreferences.setString(key, value);
    return value;
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    await _sharedPreferences.setBool(_appHighlightAnimationEnabledKey, value);
    _appHighlightAnimationEnabled = value;
    notifyListeners();
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    await _sharedPreferences.setBool(_appKeyClickEnabledKey, value);
    _appKeyClickEnabled = value;
    notifyListeners();
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    await _sharedPreferences.setBool(_autoHideAppBarKey, value);
    _autoHideAppBarEnabled = value;
    notifyListeners();
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    _gradientUuid = value;
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_backButtonActionKey, value);
    _backButtonAction = value;
    notifyListeners();
  }

  Future<void> setDateTimeFormat(String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_dateFormatKey, dateFormatString),
      _sharedPreferences.setString(_timeFormatKey, timeFormatString)
    ]);
    _dateFormat = dateFormatString;
    _timeFormat = timeFormatString;
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    await _sharedPreferences.setBool(_showCategoryTitlesKey, show);
    _showCategoryTitles = show;
    notifyListeners();
  }

  Future<void> setShowAppNamesBelowIcons(bool show) async {
    await _sharedPreferences.setBool(_showAppNamesBelowIconsKey, show);
    _showAppNamesBelowIcons = show;
    notifyListeners();
  }

  Future<void> setThemes(String shape) async {
    await _sharedPreferences.setString(_themesKey, shape);
    _themes = shape;
    notifyListeners();
  }

  Future<void> setHideHighlightOutlineOnHomescreen(bool enabled) async {
    await _sharedPreferences.setBool(_hideHighlightOutlineOnHomescreenKey, enabled);
    _hideHighlightOutlineOnHomescreen = enabled;
    notifyListeners();
  }

  Future<void> setAppSelectorTransitionAnimationEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_appSelectorTransitionAnimationEnabledKey, enabled);
    _appSelectorTransitionAnimationEnabled = enabled;
    notifyListeners();
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_showDateInStatusBarKey, show);
    _showDateInStatusBar = show;
    notifyListeners();
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_showTimeInStatusBarKey, show);
    _showTimeInStatusBar = show;
    notifyListeners();
  }

  Future<void> setAccentColor(String colorHex) async {
    await _sharedPreferences.setString(_accentColorKey, colorHex);
    _accentColorHex = colorHex;
    notifyListeners();
  }

  Future<void> setScreensaverClockStyle(String style) async {
    await _sharedPreferences.setString(_screensaverClockStyleKey, style);
    _screensaverClockStyle = style;
    notifyListeners();
  }

  bool get timeBasedWallpaperEnabled => _timeBasedWallpaperEnabled;

  Future<void> setTimeBasedWallpaperEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_timeBasedWallpaperEnabledKey, enabled);
    _timeBasedWallpaperEnabled = enabled;
    notifyListeners();
  }

  Future<void> setShowInputsWidgetInStatusBar(bool show) async {
    await _sharedPreferences.setBool(_showInputsWidgetInStatusBarKey, show);
    _showInputsWidgetInStatusBar = show;
    notifyListeners();
  }
}
