import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/weather_model.dart';

class WeatherRepository {
  final ApiClient apiClient;

  WeatherRepository({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Future<WeatherData> getWeatherDetails(double latitude, double longitude) async {
    final responseMap = await apiClient.get(
      baseUrl: ApiConstants.weatherBaseUrl,
      path: ApiEndpoints.weather,
      headers: {
        'Authorization': ApiConstants.weatherApiKey,
      },
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': ApiConstants.weatherApiKey,
      },
    );
    return WeatherData.fromJson(responseMap);
  }
}
