import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/device_model.dart';

class SharedPrefsHelper {
  static const String _keyDeviceCode = 'dCode';
  static const String _keyIsDisconnected = 'is_disconnected_device';
  static bool _forceUserCleared = false;

  static Future<void> saveUser(DeviceData deviceData) async {
    _forceUserCleared = false;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(deviceData.toJson());
    await prefs.setString(_keyDeviceCode, jsonStr);
    await prefs.setBool(_keyIsDisconnected, false);
  }

  static Future<DeviceData?> fetchUser() async {
    if (_forceUserCleared) return null;
    final prefs = await SharedPreferences.getInstance();

    final isDisconnected = prefs.getBool(_keyIsDisconnected) ?? false;
    if (isDisconnected) return null;

    final jsonStr = prefs.getString(_keyDeviceCode);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      final data = DeviceData.fromJson(map);
      if (data.deviceStatus == 'disconnected' ||
          data.deviceStatus == 'Deleted' ||
          data.deviceStatus == 'Suspended') {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    _forceUserCleared = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceCode);
    await prefs.setBool(_keyIsDisconnected, true);
  }

  static Future<bool> isDisconnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_keyIsDisconnected) ?? false) || _forceUserCleared;
  }
}
