import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/device_state.dart';
import 'services/mqtt_service.dart';
import 'services/borlindo_api_service.dart';

import 'models/app_config.dart';
import 'widgets/seat_pairing_dialog.dart';
import 'widgets/global_call_banner.dart';
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
  final bool isPassengerOnly;

  const MyApp({super.key, this.isPassengerOnly = false});

  @override
  Widget build(BuildContext context) {
    AppConfig.mode = isPassengerOnly ? AppMode.passengerOnly : AppMode.full;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceState()),
        Provider(create: (_) => MqttService()),
        ChangeNotifierProvider(create: (_) => BorlindoApiService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: isPassengerOnly
            ? 'SmartBus Passenger Monitor'
            : 'Safety Protection System',
        theme: AutomotiveTheme.dark(),
        home: SplashScreen(isPassengerOnly: isPassengerOnly),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              const GlobalCallBanner(),
              const SeatPairingDialog(),
            ],
          );
        },
      ),
    );
  }
}
