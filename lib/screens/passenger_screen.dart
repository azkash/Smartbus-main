import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';
import '../services/borlindo_api_service.dart';
import '../services/headunit_http_server.dart';
import '../widgets/header_section.dart';
import '../widgets/passenger_web_view.dart';
import '../widgets/ambient_glow.dart';
import 'main_control_screen.dart' show showSeatTriggerNotification, SeatStatus;

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final HeadunitHttpServer _httpServer = HeadunitHttpServer();

  @override
  void initState() {
    super.initState();

    // Jalankan HTTP Server lokal untuk data loadcell/seat trigger
    final deviceState = Provider.of<DeviceState>(context, listen: false);
    _httpServer.start(context, deviceState, (seatNumber, weight, isOccupied) {
      if (isOccupied && mounted) {
        showSeatTriggerNotification(
          context,
          SeatStatus(
            seatNumber: seatNumber,
            isOccupied: isOccupied,
            weight: weight,
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final mqtt = Provider.of<MqttService>(context, listen: false);
      final borlindoApi =
          Provider.of<BorlindoApiService>(context, listen: false);

      deviceState.onSeatPayloadUpdate = (payload) {
        borlindoApi.onSeatPayloadReceived(payload);
      };
      borlindoApi.onLogCallback = (title, {message, isError = false}) {
        mqtt.addLog(title,
            type: isError ? LogType.error : LogType.action, message: message);
      };

      mqtt.connect(deviceState);

      // Panggil background service pemantau notifikasi secara aman
      const platform =
          MethodChannel('com.example.safety_protection_system/wifi');
      try {
        await platform.invokeMethod('startBackgroundService');
      } catch (e) {
        debugPrint("⚠️ Gagal memulai service latar belakang: $e");
      }
    });
  }

  @override
  void dispose() {
    _httpServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03070C),
      body: Stack(
        children: [
          const Positioned(
              top: -50,
              right: -50,
              child: AmbientGlow(color: Colors.blueAccent)),
          const Positioned(
              bottom: -50,
              left: -50,
              child: AmbientGlow(color: Colors.indigo)),
          SafeArea(
            child: Column(
              children: [
                HeaderSection(
                  currentIndex: 0,
                  onTabChanged: (_) {},
                  isPassengerOnly: true,
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: PassengerWebView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
