import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/notification_service.dart';
import '../../core/utils/shared_prefs_helper.dart';
import '../../data/models/device_model.dart';
import '../../data/repositories/device_repository.dart';

class CodeController extends ChangeNotifier {
  final DeviceRepository _repository;

  CodeController({DeviceRepository? repository})
      : _repository = repository ?? DeviceRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DeviceData? _deviceData;
  DeviceData? get deviceData => _deviceData;

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns true if a disconnect notification arrived while the app was killed.
  /// Written by the background FCM handler in notification_service.dart.
  Future<bool> hasPendingDisconnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pending_navigate_to') == 'code_view';
  }

  /// Clears the pending disconnect flag and the saved device session.
  Future<void> clearPendingDisconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_navigate_to');
    await prefs.remove('pending_disconnect_type');
    await SharedPrefsHelper.clearUser();
    debugPrint('CodeController: pending disconnect cleared');
  }

  Future<DeviceData?> checkSavedSession() async {
    final savedData = await SharedPrefsHelper.fetchUser();
    if (savedData != null && savedData.deviceCode != null) {
      _deviceData = savedData;
      notifyListeners();
      return savedData;
    }
    return null;
  }

  Future<bool> validateAndSubmitCode(String code) async {
    if (code.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch FCM token to register this TV device on the backend
      final fcmToken = await NotificationService().getToken();

      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════╗');
      debugPrint('║         PAIRING — FCM TOKEN BEING SENT TO API           ║');
      debugPrint('╠══════════════════════════════════════════════════════════╣');
      debugPrint('║ Code       : $code');
      debugPrint('║ FCM Token  : $fcmToken');
      debugPrint('╚══════════════════════════════════════════════════════════╝');
      debugPrint('');

      final response = await _repository.getDeviceDetails(
        code,
        deviceToken: fcmToken,
      );

      debugPrint('CodeController: API response status=${response.status} deviceId=${response.data?.id} deviceCode=${response.data?.deviceCode} savedToken=${response.data?.deviceToken}');

      _isLoading = false;

      if (response.status == true &&
          response.data != null &&
          response.data?.deviceStatus != 'disconnected') {
        _deviceData = response.data;

        if (_deviceData != null) {
          await SharedPrefsHelper.saveUser(_deviceData!);

          // Clear any pending disconnect flags so NotificationService doesn't
          // trigger a false-positive redirect to CodeView.
          await NotificationService().clearPendingNavigation();
          await SharedPrefsHelper.clearJustDisconnected();

          // Subscribe to the device-specific FCM topic so the backend can
          // push targeted disconnect notifications via FCM v1.
          final deviceId = _deviceData!.id?.toString()
              ?? _deviceData!.deviceCode
              ?? code;

          debugPrint('CodeController: Subscribing to FCM topic: $deviceId');
          await NotificationService().subscribeToDeviceTopic(deviceId);
        }

        notifyListeners();
        return true;
      } else {
        _errorMessage = ApiConstants.someWrongMessage;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('CodeController: validateAndSubmitCode error: $e');
      _isLoading = false;
      _errorMessage = ApiConstants.someWrongMessage;
      notifyListeners();
      return false;
    }
  }
}
