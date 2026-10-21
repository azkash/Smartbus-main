import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // SET FULLSCREEN
  // immersiveSticky membuat bar navigasi dan status bar hilang total
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // Kunci orientasi ke Landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp(isPassengerOnly: true));
}
