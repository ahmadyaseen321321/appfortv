import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/weather_model.dart';

class WeatherWidget extends StatelessWidget {
  final WeatherData? weatherData;

  const WeatherWidget({super.key, this.weatherData});

  @override
  Widget build(BuildContext context) {
    final data = weatherData;

    // Hide the widget entirely when there is nothing to show
    if (data == null || !data.hasData) return const SizedBox.shrink();

    final tempText = data.temperature ?? '';
    final desc = data.description ?? '';
    final iconUrl = data.iconUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Weather icon — network URL from payload, fallback to sun outline
        if (iconUrl != null && iconUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: iconUrl,
            width: 40,
            height: 40,
            placeholder: (context, url) => const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, err) => const Icon(
              Icons.wb_sunny_outlined,
              color: Colors.white,
              size: 24,
            ),
          )
        else
          const Icon(
            Icons.wb_sunny_outlined,
            color: Colors.white,
            size: 24,
          ),

        const SizedBox(width: 8),

        // Temperature + description stacked vertically
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tempText.isNotEmpty)
              Text(
                tempText,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            if (desc.isNotEmpty)
              Text(
                desc,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
