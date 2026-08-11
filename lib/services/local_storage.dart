import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage utility wrapping SharedPreferences.
/// Used for offline persistence of user data (XP, streak, plans, habits).
class LocalStorage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Int helpers ──────────────────────────────────────────────
  static Future<void> saveInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  static int loadInt(String key, int fallback) {
    return _prefs.getInt(key) ?? fallback;
  }

  // ── String helpers ───────────────────────────────────────────
  static Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  static String loadString(String key, String fallback) {
    return _prefs.getString(key) ?? fallback;
  }

  // ── JSON helpers (encode objects to string) ──────────────────
  static Future<void> saveJson(String key, dynamic value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  static String? loadJsonString(String key) {
    return _prefs.getString(key);
  }

  // ── Bool helpers ─────────────────────────────────────────────
  static Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  static bool loadBool(String key, bool fallback) {
    return _prefs.getBool(key) ?? fallback;
  }

  // ── List<String> helpers ─────────────────────────────────────
  static Future<void> saveStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  static List<String>? loadStringList(String key) {
    return _prefs.getStringList(key);
  }

  // ── Remove a key ─────────────────────────────────────────────
  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
