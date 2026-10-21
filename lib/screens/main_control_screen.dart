import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../models/control_panel_state.dart';
import '../services/mqtt_service.dart';
import '../services/borlindo_api_service.dart';
import '../services/headunit_http_server.dart';
import '../widgets/header_section.dart';
import '../widgets/passenger_web_view.dart';
import '../widgets/bus_preview_card.dart';
import '../widgets/rgb_control_card.dart';
import '../widgets/ambient_light_card.dart';
import '../widgets/light_control_card.dart';
import '../widgets/ambient_glow.dart';

class MainControlScreen extends StatefulWidget {
  const MainControlScreen({super.key});

  @override
  State<MainControlScreen> createState() => _MainControlScreenState();
}

class _MainControlScreenState extends State<MainControlScreen> {
  late final ControlPanelState panel;
  final HeadunitHttpServer _httpServer = HeadunitHttpServer();
  int _currentScreenIndex = 0;

  @override
  void initState() {
    super.initState();
    panel = ControlPanelState();

    // Jalankan HTTP Server lokal untuk data loadcell
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
    panel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: panel,
      child: Scaffold(
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
                    currentIndex: _currentScreenIndex,
                    onTabChanged: (index) {
                      setState(() {
                        _currentScreenIndex = index;
                      });
                    },
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentScreenIndex,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > constraints.maxHeight) {
                              return const _LandscapeLayout();
                            } else {
                              return const _PortraitLayout();
                            }
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: PassengerWebView(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 4, child: BusPreviewCard()),
          Expanded(flex: 4, child: RgbControlCard()),
          Expanded(flex: 3, child: AmbientLightCard()),
          Expanded(flex: 4, child: LightControlCard()),
        ],
      ),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(4),
        children: const [
          BusPreviewCard(height: 300),
          RgbControlCard(height: 320),
          AmbientLightCard(height: 280),
          LightControlCard(height: 280),
        ],
      );
}

// =========================================================================
// MODEL DATA & UI NOTIFIKASI MELAYANG
// =========================================================================

class SeatStatus {
  final String seatNumber;
  final bool isOccupied;
  final double weight;

  SeatStatus({
    required this.seatNumber,
    required this.isOccupied,
    required this.weight,
  });
}

OverlayEntry? _activeNotification;

void showSeatTriggerNotification(BuildContext context, SeatStatus seat) {
  if (_activeNotification != null && _activeNotification!.mounted) {
    _activeNotification!.remove();
    _activeNotification = null;
  }

  final overlayState = Overlay.of(context);

  _activeNotification = OverlayEntry(
    builder: (context) => Positioned(
      top: 25,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value.clamp(0.0, 1.0), child: child));
            },
            child: Container(
              width: 380,
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22).withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.amberAccent.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: Colors.amberAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "SAFETY ALERT: KURSI TERISI",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Terdeteksi di ${seat.seatNumber} (${seat.weight.toStringAsFixed(1)} kg)",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 18,
                      color: Colors.white.withOpacity(0.08),
                      margin: const EdgeInsets.symmetric(horizontal: 6)),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white30, size: 16),
                    onPressed: () {
                      if (_activeNotification != null &&
                          _activeNotification!.mounted) {
                        _activeNotification!.remove();
                        _activeNotification = null;
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlayState.insert(_activeNotification!);

  Timer(const Duration(milliseconds: 7000), () {
    if (_activeNotification != null && _activeNotification!.mounted) {
      _activeNotification!.remove();
      _activeNotification = null;
    }
  });
}
