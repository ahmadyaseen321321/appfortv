// WeatherRepository is no longer used.
// Weather data is now embedded in the device API payload
// (fields: temprature, weather_icon, weather_desc) and extracted
// directly in MainController._extractWeatherFromDevice().
//
// This file is kept to avoid breaking any future imports.

class WeatherRepository {
  const WeatherRepository();
}
