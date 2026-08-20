import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/shared_prefs_helper.dart';
import '../../data/models/device_model.dart';
import '../../data/models/weather_model.dart';
import '../../data/repositories/device_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../../core/utils/notification_service.dart';
import '../../core/network/socket_service.dart';

class MainController extends ChangeNotifier {
  final DeviceRepository _deviceRepository;
  final WeatherRepository _weatherRepository;
  final SocketService _socketService;

  MainController({
    DeviceRepository? deviceRepository,
    WeatherRepository? weatherRepository,
    SocketService? socketService,
  })  : _deviceRepository = deviceRepository ?? DeviceRepository(),
        _weatherRepository = weatherRepository ?? WeatherRepository(),
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
  }

  void _setupSocketListeners() {
    _socketService.onDeviceUpdated = (newDeviceData) async {
      debugPrint("MainController: Socket device_updated received: ${newDeviceData.deviceCode}");
      _deviceData = newDeviceData;
      await SharedPrefsHelper.saveUser(_deviceData!);
      notifyListeners();

      if (_deviceData?.lat != null && _deviceData?.longitude != null) {
        final lat = double.tryParse(_deviceData!.lat!);
        final lon = double.tryParse(_deviceData!.longitude!);
        if (lat != null && lon != null) {
          await fetchWeather(lat, lon);
        }
      }
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

  Timer? _weatherTimer;
  Timer? _tokenTimer;

  void setDeviceData(DeviceData data) {
    _deviceData = data;
    notifyListeners();
  }

  Future<void> init(DeviceData? initialData) async {
    if (initialData != null) {
      _deviceData = initialData;
    } else {
      _deviceData = await SharedPrefsHelper.fetchUser();
    }

    if (_deviceData?.deviceCode != null) {
      _socketService.connect(_deviceData!.deviceCode!);
      await refreshDeviceDetails(_deviceData!.deviceCode!);
    }

    _startWeatherTimer();
    _startTokenPolling();
  }

  Future<void> refreshDeviceDetails(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _deviceRepository.getDeviceDetails(code);
      _isLoading = false;

      if (response.status == true &&
          response.data != null &&
          response.data?.deviceStatus != 'disconnected') {
        _deviceData = response.data;
        await SharedPrefsHelper.saveUser(_deviceData!);
        notifyListeners();

        // Fetch weather for lat/lon if present
        if (_deviceData?.lat != null && _deviceData?.longitude != null) {
          final lat = double.tryParse(_deviceData!.lat!);
          final lon = double.tryParse(_deviceData!.longitude!);
          if (lat != null && lon != null) {
            await fetchWeather(lat, lon);
          }
        }
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

  Future<void> fetchWeather(double latitude, double longitude) async {
    try {
      final weather = await _weatherRepository.getWeatherDetails(latitude, longitude);
      _weatherData = weather;
      notifyListeners();
    } catch (e) {
      debugPrint("Weather fetch error: $e");
    }
  }

  void _startWeatherTimer() {
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_deviceData?.lat != null && _deviceData?.longitude != null) {
        final lat = double.tryParse(_deviceData!.lat!);
        final lon = double.tryParse(_deviceData!.longitude!);
        if (lat != null && lon != null) {
          fetchWeather(lat, lon);
        }
      }
    });
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
      final response = await _deviceRepository.checkToken(code);
      if (response.status == true && response.data != null) {
        final newData = response.data!;
        
        // If status is disconnected, handle it
        if (newData.deviceStatus == 'disconnected') {
          onScreenRemoved('Disconnected');
          return;
        }

        _deviceData = newData;
        await SharedPrefsHelper.saveUser(_deviceData!);
        notifyListeners();
      } else if (response.status == false) {
        // Handle Disconnected, Deleted, or Suspended status from API
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
    _socketService.disconnect();
    if (message == 'Deleted') {
      _dialogMessage = ApiConstants.screenDeletedMsg;
    } else if (message == 'Suspended') {
      _dialogMessage = "Screen has been suspended.";
    } else {
      _dialogMessage = ApiConstants.screenDisconnectedMsg;
    }
    await SharedPrefsHelper.clearUser();
    notifyListeners();
  }

  void clearDialogMessage() {
    _dialogMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _tokenTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
