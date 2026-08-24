/// Weather data now comes directly from the device API payload
/// (fields: temprature, weather_icon, weather_desc).
/// The [WeatherData] model wraps these three fields and is populated
/// from [DeviceData] — no separate OpenWeatherMap call needed.
class WeatherData {
  /// Pre-formatted temperature string from the server, e.g. "25°C".
  final String? temperature;

  /// Full URL to the weather condition icon, e.g.
  /// "https://openweathermap.org/img/wn/01d@2x.png".
  final String? iconUrl;

  /// Human-readable weather description, e.g. "clear sky".
  final String? description;

  const WeatherData({
    this.temperature,
    this.iconUrl,
    this.description,
  });

  bool get hasData =>
      (temperature != null && temperature!.isNotEmpty) ||
      (iconUrl != null && iconUrl!.isNotEmpty);

  /// Build from the flat device payload map (same shape as DeviceData.fromJson input).
  factory WeatherData.fromDeviceJson(Map<String, dynamic> json) {
    String? sanitize(String? v) {
      if (v == null) return null;
      final t = v.trim();
      return (t.isEmpty || t.toLowerCase() == 'null') ? null : t;
    }

    return WeatherData(
      temperature: sanitize(json['temprature']?.toString()),
      iconUrl: sanitize(json['weather_icon']?.toString()),
      description: sanitize(json['weather_desc']?.toString()),
    );
  }
}
