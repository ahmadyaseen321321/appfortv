import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
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
    if (code.length != 5) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.getDeviceDetails(code);

      _isLoading = false;

      if (response.status == true &&
          response.data != null &&
          response.data?.deviceStatus != 'disconnected') {
        _deviceData = response.data;
        if (_deviceData != null) {
          await SharedPrefsHelper.saveUser(_deviceData!);
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = ApiConstants.someWrongMessage;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = ApiConstants.someWrongMessage;
      notifyListeners();
      return false;
    }
  }
}
