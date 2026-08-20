import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final ApiClient apiClient;

  DeviceRepository({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<DeviceResponse> getDeviceDetails(String code, {String? deviceToken}) async {
    final Map<String, String> queryParams = {'code': code};
    if (deviceToken != null && deviceToken.isNotEmpty) {
      queryParams['device_token'] = deviceToken;
    }

    final responseMap = await apiClient.get(
      baseUrl: ApiConstants.deviceBaseUrl,
      path: ApiEndpoints.device,
      queryParameters: queryParams,
    );
    return DeviceResponse.fromJson(responseMap);
  }

  Future<DeviceResponse> checkToken(String deviceCode) async {
    final responseMap = await apiClient.get(
      baseUrl: ApiConstants.deviceBaseUrl,
      path: ApiEndpoints.checkToken,
      queryParameters: {'device_code': deviceCode},
    );
    return DeviceResponse.fromJson(responseMap);
  }

  Future<Map<String, dynamic>> getSubsDetails(int deviceId) async {
    return await apiClient.get(
      baseUrl: ApiConstants.deviceBaseUrl,
      path: ApiEndpoints.subsDetails,
      queryParameters: {'device_id': deviceId.toString()},
    );
  }
}
