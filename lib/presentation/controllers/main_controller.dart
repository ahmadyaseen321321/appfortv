import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/notification_service.dart';
import '../../core/utils/shared_prefs_helper.dart';
import '../../data/models/device_model.dart';
import '../../data/models/weather_model.dart';
import '../../data/repositories/device_repository.dart';
import '../../core/network/socket_service.dart';

class MainController extends ChangeNotifier {
  final DeviceRepository _deviceRepository;
  final SocketService _socketService;

  MainController({
    DeviceRepository? deviceRepository,
    SocketService? socketService,
  }) : _deviceRepository = deviceRepository ?? DeviceRepository(),
       _socketService = socketService ?? SocketService() {
    _setupNotificationListeners();
    _setupSocketListeners();
  }

  void _setupNotificationListeners() {
    final ns = NotificationService();
    ns.onActionReceived = (message) {
      onScreenRemoved(message);
    };
    ns.onDataUpdateRequested = () {
      if (_deviceData?.deviceCode != null) {
        refreshDeviceDetails(_deviceData!.deviceCode!);
      }
    };
    // When Firebase rotates the FCM token, re-register it with the backend
    ns.onTokenRefreshed = (newToken) {
      debugPrint(
        'MainController: FCM token refreshed — re-registering with backend',
      );
      if (_deviceData?.deviceCode != null) {
        refreshDeviceDetails(_deviceData!.deviceCode!);
      }
    };
  }

  void _setupSocketListeners() {
    _socketService.onDeviceUpdated = (newDeviceData) async {
      debugPrint(
        "MainController: Socket device_updated received: ${newDeviceData.deviceCode}",
      );
      _deviceData = newDeviceData;
      await SharedPrefsHelper.saveUser(_deviceData!);
      _extractWeatherFromDevice(_deviceData!);
      notifyListeners();
    };

    _socketService.onDeviceStatusDisconnected = () {
      debugPrint("MainController: Socket device_status disconnected received.");
      onScreenRemoved('Disconnected');
    };
  }

  DeviceData? _deviceData;
  DeviceData? get deviceData => _deviceData;

  WeatherData? _weatherData;
  WeatherData? get weatherData => _weatherData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _dialogMessage;
  String? get dialogMessage => _dialogMessage;

  bool _isDisconnected = false;
  bool get isDisconnected => _isDisconnected;

  void clearDisconnected() {
    _isDisconnected = false;
    _dialogMessage = null;
  }

  Timer? _tokenTimer;

  /// Extracts weather data embedded in the device payload.
  void _extractWeatherFromDevice(DeviceData data) {
    final temp = data.temprature;
    final icon = data.weatherIcon;
    final desc = data.weatherDesc;
    if ((temp != null && temp.isNotEmpty) ||
        (icon != null && icon.isNotEmpty)) {
      _weatherData = WeatherData(
        temperature: temp,
        iconUrl: icon,
        description: desc,
      );
    }
  }

  void setDeviceData(DeviceData data) {
    _deviceData = data;
    notifyListeners();
  }

  Future<void> init(DeviceData? initialData) async {
    _isDisconnected = false; // reset on new session
    if (initialData != null) {
      _deviceData = initialData;
    } else {
      _deviceData = await SharedPrefsHelper.fetchUser();
    }

    if (_deviceData != null) {
      _extractWeatherFromDevice(_deviceData!);
      // Purge any stale pending disconnect flags since an active session is running
      try {
        await NotificationService().clearPendingNavigation();
      } catch (e) {
        debugPrint('MainController: Error clearing pending flags: $e');
      }
    }

    if (_deviceData?.deviceCode != null) {
      _socketService.connect(_deviceData!.deviceCode!);
      await refreshDeviceDetails(_deviceData!.deviceCode!);
    }

    _startTokenPolling();
  }

  Future<void> refreshDeviceDetails(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Always include the FCM token so the backend keeps it up-to-date
      final fcmToken = await NotificationService().getToken();
      debugPrint(
        'MainController: refreshDeviceDetails code=$code token=$fcmToken',
      );

      final response = await _deviceRepository.getDeviceDetails(
        code,
        deviceToken: fcmToken,
      );
      _isLoading = false;

      if (response.status == true &&
          response.data != null &&
          response.data?.deviceStatus != 'disconnected') {
        _deviceData = response.data;
        await SharedPrefsHelper.saveUser(_deviceData!);
        _extractWeatherFromDevice(_deviceData!);
        notifyListeners();
      } else if (response.data?.deviceStatus == 'disconnected' ||
          response.message == 'Disconnected' ||
          response.message == 'Deleted' ||
          response.message == 'Suspended') {
        onScreenRemoved(response.message ?? 'Disconnected');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTokenPolling() {
    _tokenTimer?.cancel();
    _tokenTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_deviceData?.deviceCode != null) {
        _checkDeviceToken(_deviceData!.deviceCode!);
      }
    });
  }

  Future<void> _checkDeviceToken(String code) async {
    try {
      final fcmToken = await NotificationService().getToken();
      final response = await _deviceRepository.checkToken(
        code,
        deviceToken: fcmToken,
      );
      if (response.status == true && response.data != null) {
        final newData = response.data!;

        if (newData.deviceStatus == 'disconnected') {
          onScreenRemoved('Disconnected');
          return;
        }

        _deviceData = newData;
        await SharedPrefsHelper.saveUser(_deviceData!);
        _extractWeatherFromDevice(_deviceData!);
        notifyListeners();
      } else if (response.status == false) {
        final msg = response.message;
        if (msg == 'Disconnected' || msg == 'Deleted' || msg == 'Suspended') {
          onScreenRemoved(msg!);
        }
      }
    } catch (e) {
      debugPrint("Token polling error: $e");
    }
  }

  void onScreenRemoved(String message) async {
    if (_isDisconnected) {
      debugPrint(
        'MainController: onScreenRemoved — already in progress, skipping',
      );
      return;
    }

    _tokenTimer?.cancel();
    _socketService.disconnect();

    if (_deviceData != null) {
      final deviceId = _deviceData!.id?.toString() ?? _deviceData!.deviceCode;
      if (deviceId != null) {
        await NotificationService().unsubscribeFromDeviceTopic(deviceId);
      }
    }

    await SharedPrefsHelper.clearUser();
    _deviceData = null;
    _weatherData = null;
    _isDisconnected = true;

    debugPrint(
      'MainController: onScreenRemoved($message) — setting isDisconnected=true',
    );
    notifyListeners();
  }

  void clearDialogMessage() {
    _dialogMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
