class WeatherData {
  final MainData? main;
  final String? name;
  final int? cod;

  WeatherData({this.main, this.name, this.cod});

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      main: json['main'] != null ? MainData.fromJson(json['main']) : null,
      name: json['name'] as String?,
      cod: json['cod'] is int ? json['cod'] : (json['cod'] != null ? int.tryParse(json['cod'].toString()) : null),
    );
  }
}

class MainData {
  final double? temp;
  final double? tempMin;
  final double? tempMax;

  MainData({this.temp, this.tempMin, this.tempMax});

  factory MainData.fromJson(Map<String, dynamic> json) {
    return MainData(
      temp: (json['temp'] as num?)?.toDouble(),
      tempMin: (json['temp_min'] as num?)?.toDouble(),
      tempMax: (json['temp_max'] as num?)?.toDouble(),
    );
  }

  int get tempFahrenheit {
    final k = tempMax ?? temp ?? 0.0;
    return ((k - 273.15) * 9 / 5 + 32).toInt();
  }

  int get tempCelsius {
    final k = tempMax ?? temp ?? 0.0;
    return (k - 273.15).toInt();
  }

  String get formattedTemp {
    return "$tempFahrenheit F / $tempCelsius C";
  }
}
