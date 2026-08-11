import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascend_app/models/xp_system.dart';
import 'package:ascend_app/theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _keyDarkMode = 'isDarkMode';
  static const _keyMode = 'appMode';

  bool _isDark = false;
  AppMode _currentMode = AppMode.survival;

  bool get isDark => _isDark;
  AppMode get currentMode => _currentMode;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// The complete ThemeData for the current mode + brightness combination.
  ThemeData get currentTheme => AppTheme.getTheme(_currentMode, _isDark);

  /// Get the color scheme for the current mode and theme
  Map<String, int> get modeColors => XPSystem.getModeColors(_currentMode, _isDark);

  /// Get primary color for current mode/theme
  Color get primaryColor => Color(modeColors['primary']!);

  /// Get secondary color for current mode/theme
  Color get secondaryColor => Color(modeColors['secondary']!);

  /// Get accent color for current mode/theme
  Color get accentColor => Color(modeColors['accent']!);

  ThemeController() {
    _loadPreference();
  }

  Future<void> load() async {
    await _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_keyDarkMode) ?? false;
    _currentMode = AppMode.values.byName(prefs.getString(_keyMode) ?? 'survival');
    notifyListeners();
  }

  Future<void> toggleDark() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, _isDark);
  }

  Future<void> setMode(AppMode mode) async {
    _currentMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
  }

  /// Get unlocked modes based on streak
  List<AppMode> getUnlockedModes(int streakDays) {
    return XPSystem.getUnlockedModes(streakDays);
  }

  /// Check if a mode is unlocked
  bool isModeUnlocked(AppMode mode, int streakDays) {
    return getUnlockedModes(streakDays).contains(mode);
  }

  /// Get seed color for Material3 theme
  Color get seedColor => primaryColor;
}
