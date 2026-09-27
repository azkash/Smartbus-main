import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final String city;
  final String temperature;
  final String condition;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.condition,
  });
}

class WeatherLocationService {
  static IconData getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clouds':
        return Icons.cloud_outlined;
      case 'rain':
        return Icons.umbrella_outlined;
      case 'clear':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.wb_cloudy_outlined;
    }
  }

  Future<WeatherData?> fetchWeatherAndLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return WeatherData(city: "GPS MATI", temperature: "--", condition: "");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return WeatherData(
              city: "IZIN DITOLAK", temperature: "--", condition: "");
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 10));

      String cityName = "UNKNOWN";
      List<Placemark> pm =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (pm.isNotEmpty) {
        cityName = pm[0].locality?.toUpperCase() ?? "UNKNOWN";
      }

      final res = await http.get(Uri.parse(
          "https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=a02b8b56fcd3d12bb37463d954fbf7fb&units=metric&lang=id"));

      String temperature = "--";
      String condition = "";

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        temperature = data['main']['temp'].round().toString();
        condition = data['weather'][0]['main'] ?? "";
      }

      return WeatherData(
        city: cityName,
        temperature: temperature,
        condition: condition,
      );
    } catch (e) {
      debugPrint("Error fetching weather and location: $e");
      return null;
    }
  }
}
