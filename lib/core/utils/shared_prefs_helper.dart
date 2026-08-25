import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/device_model.dart';

class SharedPrefsHelper {
  static const String _keyDeviceCode = 'dCode';
  static bool _forceUserCleared = false;

  static Future<void> saveUser(DeviceData deviceData) async {
    _forceUserCleared = false;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(deviceData.toJson());
    await prefs.setString(_keyDeviceCode, jsonStr);
  }

  static Future<DeviceData?> fetchUser() async {
    if (_forceUserCleared) return null;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyDeviceCode);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return DeviceData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    _forceUserCleared = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceCode);
    // Mark that we just disconnected so CodeView won't auto-login
    await prefs.setBool(_keyJustDisconnected, true);
  }

  static const String _keyJustDisconnected = 'just_disconnected';

  /// Returns true if the app just went through a disconnect flow.
  static Future<bool> wasJustDisconnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyJustDisconnected) ?? false;
  }

  /// Clears the just-disconnected flag.
  static Future<void> clearJustDisconnected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyJustDisconnected);
  }
}
