import 'package:flutter/material.dart';

class AutomotiveTheme {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const panel = Color(0xFF161D27);

  static const primary = Color(0xFF4DA3FF);
  static const accent = Color(0xFF00E5FF);
  static const danger = Color(0xFFFF5252);

  static ThemeData dark() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      cardColor: panel,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color.fromARGB(179, 22, 10, 10)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.all(primary),
        trackColor: MaterialStateProperty.all(primary.withOpacity(0.4)),
      ),
    );
  }
}
