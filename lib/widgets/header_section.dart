import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';
import '../services/weather_location_service.dart';
import 'wifi_signal_icon.dart';
import 'network_log_dialog.dart';
import 'borlindo_sync_dialog.dart';
import 'seat_list_dialog.dart';

class HeaderSection extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final bool isPassengerOnly;

  const HeaderSection({
    Key? key,
    required this.currentIndex,
    required this.onTabChanged,
    this.isPassengerOnly = false,
  }) : super(key: key);

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  String _currentCity = "LOCATING...";
  String _currentTemp = "--";
  String _weatherMain = "";
  final TextEditingController _ipController = TextEditingController();

  bool _isWifiConnectedBawaan = false;
  String _currentWifiName = "UNKNOWN WIFI";
  final WeatherLocationService _weatherService = WeatherLocationService();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        _periksaKoneksiWifiAndroid();
      } else {
        t.cancel();
      }
    });
    _updateGeo();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _updateGeo() async {
    final weatherData = await _weatherService.fetchWeatherAndLocation();
    if (weatherData != null && mounted) {
      setState(() {
        _currentCity = weatherData.city;
        _currentTemp = weatherData.temperature;
        _weatherMain = weatherData.condition;
      });
    }
  }

  Future<void> _periksaKoneksiWifiAndroid() async {
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      bool terhubungKeWifi = false;
      String namaJaringan = "UNKNOWN WIFI";

      for (var interface in interfaces) {
        if (interface.name.contains('wlan') || interface.name.contains('eth')) {
          terhubungKeWifi = true;
          if (interface.addresses.isNotEmpty) {
            String ipAwal = interface.addresses.first.address;
            namaJaringan = "LAN ROUTER ($ipAwal)";
          }
          break;
        }
      }

      if (_isWifiConnectedBawaan != terhubungKeWifi ||
          _currentWifiName != namaJaringan) {
        setState(() {
          _isWifiConnectedBawaan = terhubungKeWifi;
          _currentWifiName = terhubungKeWifi ? namaJaringan : "DISCONNECTED";
        });
      }
    } catch (e) {
      debugPrint("Gagal membaca interface jaringan: $e");
    }
  }

  OverlayEntry? _activeNotification;

  void _tampilkanPopupStatusKoneksi(bool isConnected) {
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
                    child:
                        Opacity(opacity: value.clamp(0.0, 1.0), child: child));
              },
              child: Container(
                width: 380,
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isConnected
                        ? Colors.greenAccent.withOpacity(0.25)
                        : Colors.redAccent.withOpacity(0.25),
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
                        color: isConnected
                            ? Colors.greenAccent.withOpacity(0.12)
                            : Colors.redAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_off_rounded,
                        color:
                            isConnected ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isConnected
                                ? "STATUS: TERKONEKSI"
                                : "STATUS: TERPUTUS",
                            style: TextStyle(
                              color: isConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnected
                                ? "Terhubung ke $_currentWifiName"
                                : "Sambungkan Wi-Fi Headunit ke jaringan alat.",
                            style: const TextStyle(
                                color: Colors.white70,
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

    Timer(const Duration(milliseconds: 3500), () {
      if (_activeNotification != null && _activeNotification!.mounted) {
        _activeNotification!.remove();
        _activeNotification = null;
      }
    });
  }

  void _showIPDialog(MqttService mqtt, DeviceState s) {
    _ipController.text = s.mqttHost;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "KONEKSI SMARTBUS MASTER",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.blueAccent.withOpacity(0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.router_rounded,
                        color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tablet dan ESP32 Master harus terhubung ke router "
                        "iot_bus. Seat ditemukan master melalui UDP; aplikasi "
                        "hanya terhubung ke master melalui WebSocket port 81.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "ALAMAT MASTER",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: "http://bus-led.local",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      const Icon(Icons.lan, color: Colors.white24, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Gunakan bus-led.local. IP DHCP dapat diisi manual jika mDNS "
                "tidak tersedia pada router.",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              const platform =
                  MethodChannel('com.example.safety_protection_system/wifi');
              try {
                await platform.invokeMethod('openWifiSettings');
              } catch (e) {
                debugPrint("Gagal membuka pengaturan Wi-Fi: $e");
              }
            },
            icon: const Icon(Icons.wifi, size: 16),
            label: const Text("WI-FI TABLET"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("BATAL", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final host = _ipController.text.trim().isEmpty
                  ? DeviceState.defaultMasterHost
                  : _ipController.text.trim();
              await s.updateMqttHost(host);
              await mqtt.connect(s, forceReconnect: true);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(
              "SIMPAN & HUBUNGKAN",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTabs(bool isLandscape) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(0, "CONTROLS", Icons.tune_rounded, isLandscape),
          _buildTabItem(1, "PASSENGERS", Icons.people_alt_rounded, isLandscape),
        ],
      ),
    );
  }

  Widget _buildTabItem(
      int index, String label, IconData icon, bool isLandscape) {
    bool active = widget.currentIndex == index;
    return GestureDetector(
      onTap: () => widget.onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            EdgeInsets.symmetric(horizontal: isLandscape ? 16 : 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? Colors.blueAccent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.blueAccent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isLandscape ? 12 : 10,
              color: active ? Colors.blueAccent : Colors.white30,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: isLandscape ? 9 : 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DeviceState>();
    final mqtt = context.watch<MqttService>();
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final List<String> days = [
      "MINGGU",
      "SENIN",
      "SELASA",
      "RABU",
      "KAMIS",
      "JUMAT",
      "SABTU"
    ];
    final List<String> months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MEI",
      "JUN",
      "JUL",
      "AGU",
      "SEP",
      "OKT",
      "NOV",
      "DES"
    ];

    // ONLINE means the Master WebSocket is alive, not merely that Android is
    // associated with some Wi-Fi network or a cloud MQTT broker.
    final bool isDeviceConnected = mqtt.isLocalWsConnected;

    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.symmetric(horizontal: isLandscape ? 20 : 12, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isLandscape ? 32 : 24,
                    fontWeight: FontWeight.w200,
                    height: 1.0),
              ),
              const SizedBox(height: 4),
              Text(
                "${days[_now.weekday % 7]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: isLandscape ? 10 : 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          SizedBox(width: isLandscape ? 18 : 10),
          Container(width: 1, height: 35, color: Colors.white10),
          SizedBox(width: isLandscape ? 18 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 10, color: Colors.white38),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _currentCity,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isLandscape ? 11 : 9,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(WeatherLocationService.getWeatherIcon(_weatherMain),
                        size: 14, color: Colors.blueAccent.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text("$_currentTemp°C",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isPassengerOnly) ...[
            SizedBox(width: isLandscape ? 12 : 6),
            _buildNavTabs(isLandscape),
          ],
          SizedBox(width: isLandscape ? 10 : 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.12),
              side: const BorderSide(color: Colors.blueAccent, width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 10 : 7,
                  vertical: isLandscape ? 9 : 7),
            ),
            icon: const Icon(Icons.wifi_find_rounded,
                color: Colors.blueAccent, size: 14),
            label: const Text(
              "SETTING WI-FI",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
            onPressed: () => _showIPDialog(mqtt, s),
          ),
          SizedBox(width: isLandscape ? 6 : 4),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 9 : 6,
                  vertical: isLandscape ? 9 : 7),
            ),
            icon: const Icon(Icons.terminal_rounded,
                color: Color(0xFF38BDF8), size: 14),
            label: const Text(
              "LOG",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
            onPressed: () => NetworkLogDialog.show(context),
          ),
          SizedBox(width: isLandscape ? 6 : 4),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 9 : 6,
                  vertical: isLandscape ? 9 : 7),
            ),
            icon: const Icon(Icons.cloud_sync_rounded,
                color: Color(0xFF38BDF8), size: 14),
            label: const Text(
              "INTEGRASI API",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
            onPressed: () => BorlindoSyncDialog.show(context),
          ),
          SizedBox(width: isLandscape ? 6 : 4),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF10B981), width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 9 : 6,
                  vertical: isLandscape ? 9 : 7),
            ),
            icon: const Icon(Icons.event_seat_rounded,
                color: Color(0xFF10B981), size: 14),
            label: const Text(
              "DAFTAR KURSI",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
            onPressed: () => SeatListDialog.show(context),
          ),
          SizedBox(width: isLandscape ? 8 : 4),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 10 : 7, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _tampilkanPopupStatusKoneksi(isDeviceConnected),
                  onLongPress: () => _showIPDialog(mqtt, s),
                  child: Column(
                    children: [
                      WifiSignalIcon(
                        isConnected: isDeviceConnected,
                        level: s.wifiSignal,
                        size: isLandscape ? 18 : 15,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDeviceConnected ? "ONLINE" : "OFFLINE",
                        style: TextStyle(
                            color: isDeviceConnected
                                ? Colors.greenAccent
                                : Colors.white24,
                            fontSize: 7,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isLandscape ? 15 : 10),
                _BlinkingVoltage(
                  voltage: s.voltage,
                  isLandscape: isLandscape,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingVoltage extends StatefulWidget {
  final double voltage;
  final bool isLandscape;

  const _BlinkingVoltage({
    Key? key,
    required this.voltage,
    required this.isLandscape,
  }) : super(key: key);

  @override
  State<_BlinkingVoltage> createState() => _BlinkingVoltageState();
}

class _BlinkingVoltageState extends State<_BlinkingVoltage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  // Batas voltase aki lemah (Low Battery) < 22.5V untuk sistem bus 24V
  bool get isLowVoltage => widget.voltage > 0 && widget.voltage <= 22.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (isLowVoltage) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BlinkingVoltage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isLowVoltage && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!isLowVoltage && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = isLowVoltage ? Colors.redAccent : Colors.amberAccent;
    Color iconColor = isLowVoltage ? Colors.redAccent : Colors.amber;

    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        double opacity = isLowVoltage ? _opacityAnim.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt,
                color: iconColor,
                size: widget.isLandscape ? 16 : 14,
              ),
              Text(
                "${widget.voltage.toStringAsFixed(1)}V",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.isLandscape ? 9 : 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
