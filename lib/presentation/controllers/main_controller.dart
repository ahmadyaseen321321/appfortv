import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/notification_service.dart';
import '../../core/utils/shared_prefs_helper.dart';
import '../../data/models/device_model.dart';
import '../../data/models/weather_model.dart';
import '../../data/repositories/device_repository.dart';
import '../../core/network/socket_service.dart';
import '../views/code_view.dart';

// Private alias to avoid circular imports
typedef _CodeViewPage = CodeView;

class MainController extends ChangeNotifier {
  final DeviceRepository _deviceRepository;
  final SocketService _socketService;

  MainController({
    DeviceRepository? deviceRepository,
    SocketService? socketService,
  })  : _deviceRepository = deviceRepository ?? DeviceRepository(),
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
      debugPrint('MainController: FCM token refreshed — re-registering with backend');
      if (_deviceData?.deviceCode != null) {
        refreshDeviceDetails(_deviceData!.deviceCode!);
      }
    };
  }

  void _setupSocketListeners() {
    _socketService.onDeviceUpdated = (newDeviceData) async {
      debugPrint("MainController: Socket device_updated received: ${newDeviceData.deviceCode}");
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
    _isRemoving = false; // reset guard on new session
    if (initialData != null) {
      _deviceData = initialData;
    } else {
      _deviceData = await SharedPrefsHelper.fetchUser();
    }

    if (_deviceData != null) {
      _extractWeatherFromDevice(_deviceData!);
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
      debugPrint('MainController: refreshDeviceDetails code=$code token=$fcmToken');

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
      } else {
        _dialogMessage = ApiConstants.screenDisconnectedMsg;
        await SharedPrefsHelper.clearUser();
        notifyListeners();
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

  // Navigator key so we can navigate from outside the widget tree
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Guard against double-fire (FCM + socket both firing simultaneously)
  bool _isRemoving = false;

  void onScreenRemoved(String message) async {
    if (_isRemoving) {
      debugPrint('MainController: onScreenRemoved — already in progress, skipping');
      return;
    }
    _isRemoving = true;

    _tokenTimer?.cancel();
    _socketService.disconnect();

    // Unsubscribe from the FCM device topic before clearing the session
    if (_deviceData != null) {
      final deviceId = _deviceData!.id?.toString() ?? _deviceData!.deviceCode;
      if (deviceId != null) {
        await NotificationService().unsubscribeFromDeviceTopic(deviceId);
      }
    }

    await SharedPrefsHelper.clearUser();
    _deviceData = null;
    _weatherData = null;

    debugPrint('MainController: onScreenRemoved($message) — navigating to CodeView');

    // Use addPostFrameCallback so we navigate AFTER the current frame
    // completes — avoids navigator being in a transitional/detached state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      debugPrint('MainController: navigatorKey.currentState = $nav');
      if (nav != null && nav.mounted) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _CodeViewPage()),
          (route) => false,
        ).then((_) => _isRemoving = false);
      } else {
        // Fallback: set dialog so _MainViewState handles it on next build
        if (message == 'Deleted') {
          _dialogMessage = ApiConstants.screenDeletedMsg;
        } else if (message == 'Suspended') {
          _dialogMessage = 'Screen has been suspended.';
        } else {
          _dialogMessage = ApiConstants.screenDisconnectedMsg;
        }
        notifyListeners();
        _isRemoving = false;
      }
    });
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
