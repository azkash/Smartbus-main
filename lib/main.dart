import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/device_state.dart';
import 'services/mqtt_service.dart';

import 'widgets/seat_pairing_dialog.dart';
import 'screens/splash_screen.dart';
import 'theme/automotive_theme.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceState()),
        Provider(create: (_) => MqttService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safety Protection System',
        theme: AutomotiveTheme.dark(),
        home: const SplashScreen(),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              const SeatPairingDialog(),
            ],
          );
        },
      ),
    );
  }
}
