import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/weather_model.dart';

class WeatherWidget extends StatelessWidget {
  final WeatherData? weatherData;

  const WeatherWidget({super.key, this.weatherData});

  @override
  Widget build(BuildContext context) {
    final tempText = weatherData?.main?.formattedTemp ?? "-- F / -- C";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wb_sunny_outlined,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          tempText,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
