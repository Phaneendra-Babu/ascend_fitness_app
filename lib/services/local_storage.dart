import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage utility wrapping SharedPreferences.
/// Used for offline persistence of user data (XP, streak, plans, habits).
///
/// All keys are namespaced with the currently signed-in user's id, so
/// different accounts on the same device never read each other's data.
/// Call [setUserId] whenever the auth state changes (sign-in, sign-out,
/// account switch). When no user is signed in, keys fall back to their
/// plain (legacy) form.
class LocalStorage {
  static late SharedPreferences _prefs;
  static String? _currentUserId;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Set the signed-in user whose data this storage is scoped to.
  /// A null/empty value clears the scope (keys then use their plain form).
  static void setUserId(String? uid) {
    _currentUserId = (uid == null || uid.isEmpty) ? null : uid;
  }

  static String _scopedKey(String key) {
    final uid = _currentUserId;
    if (uid == null) return key;
    return 'user_$uid/$key';
  }

  /// Return stored keys (with the user-scope prefix stripped) that begin with
  /// [prefix]. Used to discover week-scoped keys like `workoutPlan_<weekId>`
  /// across different weeks.
  static List<String> localKeysWithPrefix(String prefix) {
    final uid = _currentUserId;
    final prefixLen = uid == null ? 0 : 'user_$uid/'.length;
    final fullPrefix = uid == null ? prefix : 'user_$uid/$prefix';
    return _prefs
        .getKeys()
        .where((k) => k.startsWith(fullPrefix))
        .map((k) => k.substring(prefixLen))
        .toList();
  }

  // ── Int helpers ──────────────────────────────────────────────
  static Future<void> saveInt(String key, int value) async {
    await _prefs.setInt(_scopedKey(key), value);
  }

  static int loadInt(String key, int fallback) {
    return _prefs.getInt(_scopedKey(key)) ?? fallback;
  }

  // ── String helpers ───────────────────────────────────────────
  static Future<void> saveString(String key, String value) async {
    await _prefs.setString(_scopedKey(key), value);
  }

  static String loadString(String key, String fallback) {
    return _prefs.getString(_scopedKey(key)) ?? fallback;
  }

  // ── JSON helpers (encode objects to string) ──────────────────
  static Future<void> saveJson(String key, dynamic value) async {
    await _prefs.setString(_scopedKey(key), jsonEncode(value));
  }

  static String? loadJsonString(String key) {
    return _prefs.getString(_scopedKey(key));
  }

  // ── Bool helpers ─────────────────────────────────────────────
  static Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(_scopedKey(key), value);
  }

  static bool loadBool(String key, bool fallback) {
    return _prefs.getBool(_scopedKey(key)) ?? fallback;
  }

  // ── List<String> helpers ─────────────────────────────────────
  static Future<void> saveStringList(String key, List<String> value) async {
    await _prefs.setStringList(_scopedKey(key), value);
  }

  static List<String>? loadStringList(String key) {
    return _prefs.getStringList(_scopedKey(key));
  }

  // ── Remove a key ─────────────────────────────────────────────
  static Future<void> remove(String key) async {
    await _prefs.remove(_scopedKey(key));
  }
}
