import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceState extends ChangeNotifier {
  DeviceState() {
    _loadSettings();
  }

  Color _bodyColor = Colors.white;
  Color _lightsColor = Colors.blueAccent;
  double _brightness = 1.0;
  bool _inverterOn = false;

  double _dimmerLevel = 0;
  int _matrixPattern = 0;
  double _voltage = 24.0;

  int _wifiSignal = 3;

  // Master is discovered by mDNS on the shared iot_bus router LAN.
  static const String defaultMasterHost = "http://bus-led.local";
  String _mqttHost = defaultMasterHost;
  String _lastSeatPayload = '{}';
  final Set<String> _activeCallSeats = {};
  final Set<String> _registeredSeatIds = {};
  String? _pendingPairingUid;
  void Function(String payload)? onSeatPayloadUpdate;

  String get lastSeatPayload => _lastSeatPayload;
  Set<String> get activeCallSeats => _activeCallSeats;
  Set<String> get registeredSeatIds => _registeredSeatIds;
  String? get pendingPairingUid => _pendingPairingUid;
  String get mqttHost => _mqttHost;
  Color get bodyColor => _bodyColor;
  Color get lightsColor => _lightsColor;
  double get brightness => _brightness;
  bool get inverterOn => _inverterOn;
  double get dimmerLevel => _dimmerLevel;
  int get matrixPattern => _matrixPattern;
  double get voltage => _voltage;
  int get wifiSignal => _wifiSignal;

  void setPendingPairingUid(String? uid) {
    _pendingPairingUid = uid;
    notifyListeners();
  }

  // ===================== METHOD WIFI/MQTT OPTION =====================

  Future<void> updateMqttHost(String newIp) async {
    // input otomatis jika user hanya input angka IP
    if (!newIp.startsWith('http')) {
      newIp = "http://$newIp";
    }

    _mqttHost = newIp;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_host', newIp);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('mqtt_host');
    // Migrate installations that cached the retired ESP32 SoftAP address.
    if (savedHost == null || savedHost.contains('192.168.4.1')) {
      _mqttHost = defaultMasterHost;
      await prefs.setString('mqtt_host', defaultMasterHost);
    } else {
      _mqttHost = savedHost;
    }
    notifyListeners();
  }

  // ===================== METHOD SETTER =====================

  void updateWifiSignal(int level) {
    _wifiSignal = level.clamp(0, 3);
    notifyListeners();
  }

  void setBodyColor(Color c) {
    _bodyColor = c;
    notifyListeners();
  }

  void setLightsColor(Color c) {
    _lightsColor = c;
    notifyListeners();
  }

  void setBrightness(double v) {
    _brightness = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleInverter() {
    _inverterOn = !_inverterOn;
    notifyListeners();
  }

  void setDimmer(double v) {
    _dimmerLevel = v.clamp(0.0, 100.0);
    notifyListeners();
  }

  void setMatrixPattern(int pattern) {
    _matrixPattern = pattern;
    notifyListeners();
  }

  void updateVoltage(double v) {
    _voltage = v;
    notifyListeners();
  }

  void updateSeatPayload(String payload) {
    _lastSeatPayload = payload;
    _parseAndTrackCallingSeats(payload);
    onSeatPayloadUpdate?.call(payload);
    notifyListeners();
  }

  void clearCall(String seatId) {
    _activeCallSeats.remove(seatId);
    notifyListeners();
  }

  void clearAllCalls() {
    _activeCallSeats.clear();
    notifyListeners();
  }

  void unpairSeatLocal(String seatId) {
    _registeredSeatIds.remove(seatId);
    _activeCallSeats.remove(seatId);
    notifyListeners();
  }

  void _parseAndTrackCallingSeats(String payload) {
    try {
      final dynamic data = jsonDecode(payload);
      final List<String> newlyTriggered = [];

      if (data is List) {
        final Set<String> currentCallingInRoster = {};
        final Set<String> currentRegisteredInRoster = {};
        for (var item in data) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty && id != 'RandomID') {
              currentRegisteredInRoster.add(id);
            }
            final isCalling = item['calling'] == true ||
                item['calling'] == 1 ||
                item['callPending'] == true;
            if (isCalling && id.isNotEmpty) {
              currentCallingInRoster.add(id);
              if (!_activeCallSeats.contains(id)) {
                newlyTriggered.add(id);
              }
              _activeCallSeats.add(id);
            }
          }
        }
        _registeredSeatIds.clear();
        _registeredSeatIds.addAll(currentRegisteredInRoster);
        // Hapus kursi yang panggilannya sudah selesai / dimatikan dari roster
        _activeCallSeats
            .removeWhere((id) => !currentCallingInRoster.contains(id));
      } else if (data is Map) {
        if (data.containsKey('seats') && data['seats'] is Map) {
          final seats = data['seats'] as Map;
          final Set<String> currentCallingInMap = {};
          seats.forEach((key, val) {
            final id = key.toString();
            if (id.isNotEmpty && id != 'RandomID') {
              _registeredSeatIds.add(id);
            }
            if (val is Map) {
              final isCalling = val['calling'] == true ||
                  val['calling'] == 1 ||
                  val['callPending'] == true;
              if (isCalling) {
                currentCallingInMap.add(id);
                if (!_activeCallSeats.contains(id)) {
                  newlyTriggered.add(id);
                }
                _activeCallSeats.add(id);
              }
            }
          });
          _activeCallSeats
              .removeWhere((id) => !currentCallingInMap.contains(id));
        } else if (data.containsKey('seatId') || data.containsKey('id')) {
          final id = (data['seatId'] ?? data['id']).toString();
          if (id.isNotEmpty && id != 'RandomID') {
            _registeredSeatIds.add(id);
          }
          final isCalling = data['calling'] == true ||
              data['calling'] == 1 ||
              data['callPending'] == true;
          if (isCalling && id.isNotEmpty) {
            if (!_activeCallSeats.contains(id)) {
              newlyTriggered.add(id);
            }
            _activeCallSeats.add(id);
          } else if (id.isNotEmpty) {
            _activeCallSeats.remove(id);
          }
        } else {
          final Set<String> currentCalling = {};
          data.forEach((key, val) {
            final id = key.toString();
            if (id.isNotEmpty && id != 'RandomID') {
              _registeredSeatIds.add(id);
            }
            if (val is Map) {
              final isCalling = val['calling'] == true ||
                  val['calling'] == 1 ||
                  val['callPending'] == true;
              if (isCalling) {
                currentCalling.add(id);
                if (!_activeCallSeats.contains(id)) {
                  newlyTriggered.add(id);
                }
                _activeCallSeats.add(id);
              }
            }
          });
          _activeCallSeats.removeWhere((id) => !currentCalling.contains(id));
        }
      }

      // Jika ada panggilan baru, trigger notifikasi native persistent tanpa suara.
      if (newlyTriggered.isNotEmpty) {
        _triggerNativeNotification(newlyTriggered.join(', '));
      }
    } catch (_) {}
  }

  void _triggerNativeNotification(String seatId) {
    try {
      const MethodChannel platform =
          MethodChannel('com.example.safety_protection_system/wifi');
      platform.invokeMethod('triggerNativeNotification', {'seatId': seatId});
    } catch (_) {}
  }
}
