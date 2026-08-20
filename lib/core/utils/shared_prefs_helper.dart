import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/device_model.dart';

class SharedPrefsHelper {
  static const String _keyDeviceCode = 'dCode';

  static Future<void> saveUser(DeviceData deviceData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(deviceData.toJson());
    await prefs.setString(_keyDeviceCode, jsonStr);
  }

  static Future<DeviceData?> fetchUser() async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceCode);
  }
}
