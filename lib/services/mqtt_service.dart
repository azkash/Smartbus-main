import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_state.dart';

import 'mqtt_setup_server.dart' if (dart.library.html) 'mqtt_setup_web.dart'
    as mqtt_setup;

enum LogType { info, action, error, success }

class SeatPairingResult {
  final bool success;
  final String? error;

  const SeatPairingResult({required this.success, this.error});

  String get message {
    switch (error) {
      case 'duplicate_id':
        return 'Nomor kursi sudah digunakan.';
      case 'invalid_id':
        return 'Nomor kursi tidak valid.';
      case 'pairing_not_found':
        return 'Permintaan pairing sudah kedaluwarsa. Tekan tombol seat lagi.';
      case 'headunit_required':
        return 'Head unit belum terdaftar di master.';
      case 'not_connected':
        return 'WebSocket master belum terhubung.';
      case 'timeout':
        return 'Master tidak memberikan jawaban pairing.';
      case 'busy':
        return 'Pairing lain masih diproses.';
      default:
        return success ? 'Pairing diterima master.' : 'Pairing gagal.';
    }
  }
}

class NetworkLogEntry {
  final DateTime timestamp;
  final LogType type;
  final String title;
  final String? message;
  final String? code;

  NetworkLogEntry({
    required this.timestamp,
    required this.type,
    required this.title,
    this.message,
    this.code,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return "$h:$m:$s.$ms";
  }
}

class MqttService with ChangeNotifier {
  String currentBroker = 'broker.emqx.io';
  final String clientId =
      'flutter_bus_zulham_${DateTime.now().millisecondsSinceEpoch}';
  final String topicPub = 'bus_zulham/control';
  final String topicSub = 'bus_zulham/status';

  late MqttClient client;
  StreamSubscription? _sub;
  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  // ===================== LOG BUFFER JARINGAN =====================
  final List<NetworkLogEntry> _networkLogs = [];
  List<NetworkLogEntry> get networkLogs => List.unmodifiable(_networkLogs);

  void addLog(String title,
      {LogType type = LogType.info, String? message, String? code}) {
    final entry = NetworkLogEntry(
      timestamp: DateTime.now(),
      type: type,
      title: title,
      message: message,
      code: code,
    );
    if (_networkLogs.length >= 300) {
      _networkLogs.removeAt(0);
    }
    _networkLogs.add(entry);
    notifyListeners();
  }

  void clearLogs() {
    _networkLogs.clear();
    addLog("Log dibersihkan oleh pengguna", type: LogType.info);
    notifyListeners();
  }

  // ===================== WEBSOCKET LOKAL ESP32 (DENGAN IP CACHING) =====================
  WebSocket? _localSocket;
  bool _isLocalWsConnected = false;
  bool get isLocalWsConnected => _isLocalWsConnected;
  bool _isConnectingLocalWs = false;
  Timer? _reconnectTimer;
  String? _lastConnectedHost;
  String? _cachedEspIp;
  int _failedDirectAttempts = 0;
  Completer<SeatPairingResult>? _pairingCompleter;

  bool get isConnected {
    try {
      if (client.connectionStatus == null) return false;
      return client.connectionStatus!.state == MqttConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  MqttService() {
    _initClient(currentBroker, 1883);
    _loadCachedMaster();
    addLog("MqttService diinisialisasi", type: LogType.info);
  }

  Future<void> _loadCachedMaster() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedEspIp = prefs.getString('cached_esp_ip');
      if (_cachedEspIp == '192.168.4.1') {
        _cachedEspIp = null;
        await prefs.remove('cached_esp_ip');
      }
      // These keys belonged to the retired in-app WiFi provisioning flow.
      await prefs.remove('wifi_target_ssid');
      await prefs.remove('wifi_target_pass');
      addLog("Cache master dimuat",
          type: LogType.info, message: _cachedEspIp ?? 'bus-led.local');
    } catch (e) {
      addLog("Gagal memuat cache master",
          type: LogType.error, message: e.toString());
    }
  }

  void _initClient(String broker, int port) {
    client = mqtt_setup.setup(broker, clientId, port);
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.onDisconnected = () {
      debugPrint("Disconnected from MQTT");
      addLog("MQTT Terputus", type: LogType.error);
      notifyListeners();
    };
    client.onConnected = () {
      debugPrint("Connected to MQTT");
      addLog("MQTT Terhubung", type: LogType.success, message: "$broker:$port");
      notifyListeners();
    };
  }

  // ===================== METODE KONTROL PERANGKAT & LAMPU =====================
  Future<void> setPower(String host, bool power) async {
    final cmd = power ? "power_on" : "power_off";
    await sendControlHttp(host, cmd);
  }

  Future<void> setRgb(String host, int r, int g, int b) async {
    final cmd = "rgb_${r}_${g}_$b";
    await sendControlHttp(host, cmd);
  }

  // Retains the old method name for widget compatibility. Transport is now
  // WebSocket-only; the master's port 80 serves the read-only web monitor.
  Future<void> sendControlHttp(String _, String command) async {
    addLog("Kirim Perintah Kontrol", type: LogType.action, message: command);
    if (_isLocalWsConnected && _localSocket != null) {
      try {
        if (command.startsWith("clearCall_")) {
          final id = command.substring(10);
          _localSocket!.add('{"action":"clearCall","id":"$id"}');
        } else {
          _localSocket!.add(command);
        }
        return;
      } catch (e) {
        addLog("WebSocket gagal mengirim",
            type: LogType.error, message: e.toString());
      }
    }
    addLog("Perintah tidak dikirim",
        type: LogType.error, message: "WebSocket master belum terhubung");
  }

  // ===================== KONEKSI WEBSOCKET LOKAL DENGAN SMART AUTO-DISCOVERY =====================
  Future<void> connectLocalWs(
    String host,
    DeviceState deviceState, {
    bool forceReconnect = false,
  }) async {
    if (forceReconnect) {
      _reconnectTimer?.cancel();
      final previousSocket = _localSocket;
      _localSocket = null;
      _isLocalWsConnected = false;
      try {
        await previousSocket?.close();
      } catch (_) {}
    }
    if (_isLocalWsConnected) {
      debugPrint("🔌 WebSocket Lokal sudah terhubung aktif.");
      return;
    }
    if (_isConnectingLocalWs) {
      debugPrint(
          "🔌 Sedang dalam proses menghubungkan ke WebSocket. Abaikan duplikat.");
      return;
    }
    _isConnectingLocalWs = true;

    try {
      _reconnectTimer?.cancel();
      _lastConnectedHost = host;

      if (kIsWeb) {
        addLog("Platform Web terdeteksi", type: LogType.info);
        return;
      }

      // Bersihkan format host
      String cleanHost = host;
      if (cleanHost.startsWith('http://')) cleanHost = cleanHost.substring(7);
      if (cleanHost.startsWith('https://')) cleanHost = cleanHost.substring(8);
      if (cleanHost.contains(':')) {
        cleanHost = cleanHost.split(':')[0];
      }
      if (cleanHost.endsWith('/')) {
        cleanHost = cleanHost.substring(0, cleanHost.length - 1);
      }

      // Prefer mDNS on the shared router LAN, then the last successful DHCP IP.
      final List<String> directCandidates = ['bus-led.local'];
      if (!cleanHost.contains('emqx') &&
          !directCandidates.contains(cleanHost)) {
        directCandidates.add(cleanHost);
      }
      if (_cachedEspIp != null &&
          _cachedEspIp!.isNotEmpty &&
          _cachedEspIp != '192.168.4.1' &&
          !directCandidates.contains(_cachedEspIp)) {
        directCandidates.add(_cachedEspIp!);
      }

      WebSocket? connectedSocket;
      String? successfulHost;

      // 2. TAHAP 1: mDNS/cached-IP fast path.
      for (String cand in directCandidates) {
        addLog("Mencoba koneksi langsung",
            type: LogType.action, message: "ws://$cand:81");
        try {
          connectedSocket = await WebSocket.connect('ws://$cand:81')
              .timeout(const Duration(milliseconds: 1200));
          successfulHost = cand;
          addLog("Tersambung langsung ke ESP32",
              type: LogType.success, message: "ws://$cand:81");
          break;
        } catch (e) {
          addLog("Gagal sambung langsung",
              type: LogType.error, message: "$cand: $e");
        }
      }

      // 3. TAHAP 2: Last-resort router-subnet discovery.
      if (connectedSocket == null) {
        _failedDirectAttempts++;
        addLog("Koneksi langsung gagal ($_failedDirectAttempts/2)",
            type: LogType.info);

        if (_failedDirectAttempts >= 2) {
          addLog("Memulai pencarian master pada subnet router...",
              type: LogType.action);
          _failedDirectAttempts = 0;

          try {
            List<NetworkInterface> interfaces = await NetworkInterface.list(
              includeLoopback: false,
              type: InternetAddressType.IPv4,
            );

            for (var interface in interfaces) {
              for (var addr in interface.addresses) {
                String ip = addr.address;
                addLog("Interface Headunit terdeteksi",
                    type: LogType.info, message: "${interface.name}: $ip");

                if (ip.startsWith("192.168.") ||
                    ip.startsWith("10.") ||
                    ip.startsWith("172.")) {
                  String subnetPrefix = ip.substring(0, ip.lastIndexOf('.'));

                  // Scan bertahap batch kecil 6 IP. Do not assume .1 is the
                  // master; on router LAN it is normally the router itself.
                  const int batchSize = 6;
                  for (int i = 1; i <= 254; i += batchSize) {
                    if (connectedSocket != null) break;

                    List<String> currentBatch = [];
                    for (int j = i; j < i + batchSize && j <= 254; j++) {
                      String testIp = "$subnetPrefix.$j";
                      if (testIp != ip) currentBatch.add(testIp);
                    }

                    List<Future<String?>> probes =
                        currentBatch.map((probeIp) async {
                      try {
                        final sock = await Socket.connect(probeIp, 81,
                            timeout: const Duration(milliseconds: 300));
                        sock.destroy();
                        return probeIp;
                      } catch (_) {
                        return null;
                      }
                    }).toList();

                    final results = await Future.wait(probes);
                    for (String? discoveredIp in results) {
                      if (discoveredIp != null) {
                        try {
                          connectedSocket =
                              await WebSocket.connect('ws://$discoveredIp:81')
                                  .timeout(const Duration(milliseconds: 1500));
                          successfulHost = discoveredIp;
                          addLog("Auto-Discovery Sukses!",
                              type: LogType.success,
                              message: "ws://$discoveredIp:81");
                          break;
                        } catch (e) {
                          addLog("Gagal handshake WS di $discoveredIp",
                              type: LogType.error, message: e.toString());
                        }
                      }
                    }
                  }
                }
              }
              if (connectedSocket != null) break;
            }
          } catch (e) {
            addLog("Error saat Auto-Discovery",
                type: LogType.error, message: e.toString());
          }
        }
      }

      // 4. TAHAP 3: Simpan IP sukses dan register Headunit
      if (connectedSocket != null && successfulHost != null) {
        _localSocket = connectedSocket;
        _isLocalWsConnected = true;
        _failedDirectAttempts = 0;
        _cachedEspIp = successfulHost;
        notifyListeners();

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_esp_ip', successfulHost);
          addLog("IP ESP32 Dikunci di Cache",
              type: LogType.info, message: successfulHost);
        } catch (e) {
          addLog("Gagal simpan cache IP",
              type: LogType.error, message: e.toString());
        }

        // Daftarkan role headunit
        _localSocket!.add('{"role":"headunit"}');
        addLog("Headunit terdaftar di WebSocket", type: LogType.success);

        // Dengarkan broadcast pesan
        _localSocket!.listen(
          (message) {
            try {
              if (message is String) {
                // Debug log: tampilkan ringkasan setiap pesan masuk
                if (!message.startsWith('[')) {
                  debugPrint('[WS-RX] $message');
                }

                if (message.startsWith('[')) {
                  deviceState.updateSeatPayload(message);
                } else {
                  final data = jsonDecode(message);
                  if (data is Map) {
                    // Prioritas 1: Event pairing — cek PERTAMA sebelum apapun
                    if (data.containsKey('event')) {
                      final event = data['event'];
                      if ((event == 'seatPairingRequest' ||
                              event == 'seatPairingRequired') &&
                          data.containsKey('uid')) {
                        final uid = data['uid'].toString();
                        addLog("\u{1F514} PAIRING REQUEST DITERIMA",
                            type: LogType.action,
                            message: "Event: $event, UID: $uid");
                        debugPrint('[PAIRING] Popup trigger for UID=$uid');
                        deviceState.setPendingPairingUid(uid);
                      } else if (event == 'seatPairingResult') {
                        final result = SeatPairingResult(
                          success: data['success'] == true,
                          error: data['error']?.toString(),
                        );
                        addLog(
                          result.success
                              ? "Pairing diterima master"
                              : "Pairing ditolak master",
                          type:
                              result.success ? LogType.success : LogType.error,
                          message: result.message,
                        );
                        final completer = _pairingCompleter;
                        if (completer != null && !completer.isCompleted) {
                          completer.complete(result);
                        }
                        if (result.success) {
                          deviceState.setPendingPairingUid(null);
                        }
                      } else if (event == 'seatIdSaved') {
                        addLog("ID tersimpan pada seat",
                            type: LogType.success,
                            message: "ID: ${data['id']}");
                        deviceState.setPendingPairingUid(null);
                      }
                      // Prioritas 2: Status messages
                    } else if (data['status'] == 'inverter' &&
                        data.containsKey('vdc')) {
                      double vdc = (data['vdc'] as num).toDouble();
                      deviceState.updateVoltage(vdc);
                    } else if (data['status'] == 'wifi' &&
                        data.containsKey('connected')) {
                      bool connected = data['connected'] ?? false;
                      addLog("Status Wi-Fi Upstream ESP32",
                          type: LogType.info, message: "Connected: $connected");
                      // ═══ FAILSAFE: Deteksi langsung seat unassigned + tombol ditekan ═══
                      // Jika Master gagal mengirim event seatPairingRequired (karena alasan apapun),
                      // Flutter tetap bisa mendeteksi kursi baru dari pesan seat individual yang
                      // mungkin sampai lewat broadcast master.
                    } else if (data['unassigned'] == true &&
                        (data['sensorState'] == 1 ||
                            data['sensorState'] == '1') &&
                        data.containsKey('uid') &&
                        deviceState.pendingPairingUid == null) {
                      final uid = data['uid'].toString();
                      if (uid.length == 12) {
                        addLog(
                            "\u{1F6A8} FAILSAFE: Seat unassigned terdeteksi langsung!",
                            type: LogType.action,
                            message: "UID: $uid");
                        debugPrint(
                            '[PAIRING-FAILSAFE] Detected unassigned seat button press, UID=$uid');
                        deviceState.setPendingPairingUid(uid);
                      }
                      // Prioritas 3: Seat data payload
                    } else if (data.containsKey('seats') ||
                        data.containsKey('seatId') ||
                        data.containsKey('id') ||
                        data.containsKey('1A') ||
                        data.containsKey('A')) {
                      deviceState.updateSeatPayload(message);
                    }
                  }
                }
              }
            } catch (e) {
              addLog("Gagal mengurai pesan WS",
                  type: LogType.error, message: e.toString());
            }
          },
          onDone: () {
            if (!identical(_localSocket, connectedSocket)) return;
            addLog("Koneksi WebSocket Ditutup (onDone)",
                type: LogType.error, code: "WS_CLOSED");
            _handleLocalWsDisconnect(deviceState);
          },
          onError: (err) {
            if (!identical(_localSocket, connectedSocket)) return;
            addLog("Koneksi WebSocket Error (onError)",
                type: LogType.error, message: err.toString(), code: "WS_ERR");
            _handleLocalWsDisconnect(deviceState);
          },
          cancelOnError: true,
        );
      } else {
        addLog("Gagal terhubung ke WebSocket. Coba lagi dalam 3 detik...",
            type: LogType.error);
        _handleLocalWsDisconnect(deviceState);
      }
    } catch (e) {
      addLog("Exception di connectLocalWs",
          type: LogType.error, message: e.toString());
    } finally {
      _isConnectingLocalWs = false;
    }
  }

  void _handleLocalWsDisconnect(DeviceState deviceState) {
    try {
      _localSocket?.close();
    } catch (_) {}
    _isLocalWsConnected = false;
    _localSocket = null;
    final pairing = _pairingCompleter;
    if (pairing != null && !pairing.isCompleted) {
      pairing.complete(
          const SeatPairingResult(success: false, error: 'not_connected'));
    }
    notifyListeners();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_lastConnectedHost != null) {
        connectLocalWs(_lastConnectedHost!, deviceState);
      }
    });
  }

  Future<SeatPairingResult> assignSeatId({
    required String uid,
    required String seatId,
  }) async {
    if (!_isLocalWsConnected || _localSocket == null) {
      return const SeatPairingResult(success: false, error: 'not_connected');
    }
    if (_pairingCompleter != null && !_pairingCompleter!.isCompleted) {
      return const SeatPairingResult(success: false, error: 'busy');
    }

    final payloadAssign = jsonEncode({
      "action": "assignSeatId",
      "uid": uid,
      "id": seatId,
    });
    addLog("Mengirim inisialisasi kursi",
        type: LogType.action, message: "UID: $uid -> Kursi: $seatId");

    final completer = Completer<SeatPairingResult>();
    _pairingCompleter = completer;
    try {
      _localSocket!.add(payloadAssign);
      debugPrint('[PAIRING-TX] WebSocket: $payloadAssign');
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () =>
            const SeatPairingResult(success: false, error: 'timeout'),
      );
    } catch (e) {
      addLog("Pairing gagal dikirim",
          type: LogType.error, message: e.toString());
      return const SeatPairingResult(success: false, error: 'not_connected');
    } finally {
      if (identical(_pairingCompleter, completer)) _pairingCompleter = null;
    }
  }

  // ===================== FUNGSI KONEKSI UTAMA =====================
  Future<void> connect(
    DeviceState state, {
    bool forceReconnect = false,
  }) async {
    _isConnecting = true;
    notifyListeners();
    try {
      final host = state.mqttHost;
      bool isLocal = host.contains('192.168.') ||
          host.contains('10.') ||
          host.contains('172.') ||
          host.endsWith('.local') ||
          host.contains('localhost');

      if (isLocal) {
        if (isConnected) client.disconnect();
        await connectLocalWs(
          host,
          state,
          forceReconnect: forceReconnect,
        );
      } else {
        _reconnectTimer?.cancel();
        _isLocalWsConnected = false;
        _localSocket?.close();
        _localSocket = null;

        if (isConnected) client.disconnect();
        _initClient(host, 1883);
        await client.connect();
        _subscribeToStatus(state);
      }
    } catch (e) {
      addLog("Connect Exception", type: LogType.error, message: e.toString());
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void _subscribeToStatus(DeviceState state) {
    client.subscribe(topicSub, MqttQos.atMostOnce);
    _sub?.cancel();
    _sub = client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      try {
        final data = jsonDecode(payload);
        if (data.containsKey('voltage')) {
          state.updateVoltage(data['voltage'].toDouble());
        }
        if (data.containsKey('signal')) {
          state.updateWifiSignal(data['signal']);
        }
        if (data.containsKey('seats') || data.containsKey('SEAT-01')) {
          state.updateSeatPayload(payload);
        }
      } catch (e) {
        addLog("MQTT Parse Error", type: LogType.error, message: e.toString());
      }
    });
  }

  void publish(String topic, Map<String, dynamic> payload) {
    if (_isLocalWsConnected && _localSocket != null) {
      try {
        _localSocket!.add(jsonEncode(payload));
      } catch (e) {
        addLog("WS Publish Failed", type: LogType.error, message: e.toString());
      }
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      addLog("MQTT Publish Failed", type: LogType.error, message: e.toString());
    }
  }
}
