import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum BorlindoSyncStatus {
  idle,
  loggingIn,
  syncing,
  success,
  error,
  offline,
}

class BorlindoSeatItem {
  final String seatName;
  final int isFilled; // 1 = terisi, 0 = kosong
  final int weight;

  BorlindoSeatItem({
    required this.seatName,
    required this.isFilled,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'seat_name': seatName,
        'is_filled': isFilled,
        'weight': weight,
      };
}

class BorlindoApiService with ChangeNotifier {
  static const String defaultBaseUrl = 'https://v2-api.borlindo.com/api/partner/v2';
  static const String defaultUsername = '085876409220';
  static const String defaultPassword = 'S3mar4n9!';
  static const String defaultBusIdentity = 'DD7214RFABC';
  static const int defaultPeriodicIntervalSec = 30;
  static const int defaultWeight = 20;

  // Preferences keys
  static const String _keyBaseUrl = 'borlindo_base_url';
  static const String _keyUsername = 'borlindo_username';
  static const String _keyPassword = 'borlindo_password';
  static const String _keyBusIdentity = 'borlindo_bus_identity';
  static const String _keyIsEnabled = 'borlindo_enabled';
  static const String _keyToken = 'borlindo_token';
  static const String _keyPeriodicSec = 'borlindo_periodic_sec';

  String _baseUrl = defaultBaseUrl;
  String _username = defaultUsername;
  String _password = defaultPassword;
  String _busIdentity = defaultBusIdentity;
  bool _isEnabled = true;
  int _periodicIntervalSec = defaultPeriodicIntervalSec;
  int _occupiedWeight = defaultWeight;

  String? _token;
  BorlindoSyncStatus _status = BorlindoSyncStatus.idle;
  String _statusMessage = 'Belum sinkron';
  DateTime? _lastSyncTime;
  List<String> _latestWarnings = [];

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  String _lastSentFingerprint = '';
  List<BorlindoSeatItem> _currentSeats = [];

  // Callback opsional untuk menyalurkan log ke UI / MqttService
  void Function(String title, {String? message, bool isError})? onLogCallback;

  // Getters
  String get baseUrl => _baseUrl;
  String get username => _username;
  String get password => _password;
  String get busIdentity => _busIdentity;
  bool get isEnabled => _isEnabled;
  int get periodicIntervalSec => _periodicIntervalSec;
  int get occupiedWeight => _occupiedWeight;
  String? get token => _token;
  BorlindoSyncStatus get status => _status;
  String get statusMessage => _statusMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<String> get latestWarnings => List.unmodifiable(_latestWarnings);
  List<BorlindoSeatItem> get currentSeats => List.unmodifiable(_currentSeats);
  bool get isConfigured => _username.isNotEmpty && _password.isNotEmpty && _busIdentity.isNotEmpty;

  BorlindoApiService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
      _username = prefs.getString(_keyUsername) ?? defaultUsername;
      _password = prefs.getString(_keyPassword) ?? defaultPassword;
      _busIdentity = prefs.getString(_keyBusIdentity) ?? defaultBusIdentity;
      _isEnabled = prefs.getBool(_keyIsEnabled) ?? true;
      _token = prefs.getString(_keyToken);
      _periodicIntervalSec = prefs.getInt(_keyPeriodicSec) ?? defaultPeriodicIntervalSec;

      _startPeriodicTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('BorlindoApiService loadSettings error: $e');
    }
  }

  Future<void> updateConfig({
    String? baseUrl,
    String? username,
    String? password,
    String? busIdentity,
    bool? isEnabled,
    int? periodicIntervalSec,
    int? occupiedWeight,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    bool needRelogin = false;

    if (baseUrl != null && baseUrl != _baseUrl) {
      _baseUrl = baseUrl.trim();
      await prefs.setString(_keyBaseUrl, _baseUrl);
      needRelogin = true;
    }
    if (username != null && username != _username) {
      _username = username.trim();
      await prefs.setString(_keyUsername, _username);
      needRelogin = true;
    }
    if (password != null && password != _password) {
      _password = password.trim();
      await prefs.setString(_keyPassword, _password);
      needRelogin = true;
    }
    if (busIdentity != null && busIdentity != _busIdentity) {
      _busIdentity = busIdentity.trim();
      await prefs.setString(_keyBusIdentity, _busIdentity);
    }
    if (isEnabled != null && isEnabled != _isEnabled) {
      _isEnabled = isEnabled;
      await prefs.setBool(_keyIsEnabled, _isEnabled);
      if (!_isEnabled) {
        _status = BorlindoSyncStatus.idle;
        _statusMessage = 'Sinkronisasi dinonaktifkan';
      }
    }
    if (periodicIntervalSec != null && periodicIntervalSec != _periodicIntervalSec) {
      _periodicIntervalSec = periodicIntervalSec;
      await prefs.setInt(_keyPeriodicSec, _periodicIntervalSec);
      _startPeriodicTimer();
    }
    if (occupiedWeight != null) {
      _occupiedWeight = occupiedWeight;
    }

    if (needRelogin) {
      _token = null;
      await prefs.remove(_keyToken);
    }

    notifyListeners();
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    if (!_isEnabled || _periodicIntervalSec <= 0) return;

    _periodicTimer = Timer.periodic(Duration(seconds: _periodicIntervalSec), (_) {
      if (_isEnabled && _currentSeats.isNotEmpty) {
        debugPrint('[BorlindoApi] Periodic sync triggered (${_currentSeats.length} seats)');
        sendCurrentSeats(isHeartbeat: true);
      }
    });
  }

  /// Melakukan Login ke API Borlindo untuk mendapatkan Bearer Token
  Future<bool> login() async {
    if (_username.isEmpty || _password.isEmpty) {
      _setStatus(BorlindoSyncStatus.error, 'Username atau password kosong');
      return false;
    }

    _setStatus(BorlindoSyncStatus.loggingIn, 'Menghubungkan ke Borlindo...');
    final url = Uri.parse('$_baseUrl/token');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _username,
              'password': _password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final newToken = data['token']?.toString();

        if (newToken != null && newToken.isNotEmpty) {
          _token = newToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyToken, _token!);

          _setStatus(BorlindoSyncStatus.success, 'Login berhasil');
          _log('Login Cloud Borlindo Berhasil', message: 'Token didapatkan untuk $_username');
          return true;
        } else {
          _setStatus(BorlindoSyncStatus.error, 'Token tidak ditemukan dalam respon');
          _log('Login Cloud Borlindo Gagal', message: 'Respon tidak memuat token', isError: true);
          return false;
        }
      } else {
        String msg = 'Gagal login (HTTP ${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            msg = errBody['message'].toString();
          }
        } catch (_) {}

        _setStatus(BorlindoSyncStatus.error, msg);
        _log('Login Cloud Borlindo Gagal', message: msg, isError: true);
        return false;
      }
    } on SocketException {
      _setStatus(BorlindoSyncStatus.offline, 'Tidak ada koneksi internet');
      _log('Cloud Borlindo Offline', message: 'Tidak dapat menjangkau server', isError: true);
      return false;
    } catch (e) {
      _setStatus(BorlindoSyncStatus.error, 'Error: $e');
      _log('Login Cloud Borlindo Error', message: e.toString(), isError: true);
      return false;
    }
  }

  /// Mengestimasi bobot penumpang (kg) berdasarkan ambang batas tekanan sensor FSR
  static int estimateWeightFromPressure(bool isOccupied, int pressureReading) {
    if (!isOccupied) return 0;

    // Nilai ADC 12-bit FSR (0 - 4095)
    // Ambang batas dasar kursi terisi: ON >= 150, OFF <= 100
    if (pressureReading > 0) {
      if (pressureReading < 200) {
        return 20; // Tekanan sangat ringan / barang / tas
      } else if (pressureReading < 400) {
        return 30; // Anak-anak
      } else if (pressureReading < 800) {
        return 45; // Remaja / dewasa berbobot ringan
      } else if (pressureReading < 1600) {
        return 60; // Dewasa rata-rata standar
      } else if (pressureReading < 2600) {
        return 75; // Dewasa berbobot sedang-besar
      } else {
        return 85; // Dewasa berbobot besar (> 85 kg)
      }
    }

    // Default jika nilai ADC mentah tidak dikirim (firmware lama):
    return 60;
  }

  /// Mengurai roster payload dari Master ESP32 dan menyiapkan sinkronisasi
  void onSeatPayloadReceived(String payload) {
    if (!_isEnabled) return;

    try {
      final dynamic data = jsonDecode(payload);
      final List<BorlindoSeatItem> items = [];

      if (data is List) {
        for (var item in data) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            if (id.isEmpty || id == 'RandomID') continue;

            final isOccupied = item['occupied'] == true || item['occupied'] == 1;
            final int rawPressure = (item['pressure'] ?? item['reading'] ?? 0) is num
                ? (item['pressure'] ?? item['reading'] as num).toInt()
                : int.tryParse((item['pressure'] ?? item['reading'] ?? '0').toString()) ?? 0;

            final int calculatedWeight = estimateWeightFromPressure(isOccupied, rawPressure);

            items.add(BorlindoSeatItem(
              seatName: id,
              isFilled: isOccupied ? 1 : 0,
              weight: calculatedWeight,
            ));
          }
        }
      } else if (data is Map) {
        if (data.containsKey('seats') && data['seats'] is Map) {
          final seatsMap = data['seats'] as Map;
          seatsMap.forEach((key, val) {
            final id = key.toString();
            if (id.isEmpty || id == 'RandomID') return;
            bool isOccupied = false;
            int rawPressure = 0;
            if (val is Map) {
              isOccupied = val['occupied'] == true || val['occupied'] == 1;
              rawPressure = (val['pressure'] ?? val['reading'] ?? 0) is num
                  ? (val['pressure'] ?? val['reading'] as num).toInt()
                  : int.tryParse((val['pressure'] ?? val['reading'] ?? '0').toString()) ?? 0;
            }
            final int calculatedWeight = estimateWeightFromPressure(isOccupied, rawPressure);
            items.add(BorlindoSeatItem(
              seatName: id,
              isFilled: isOccupied ? 1 : 0,
              weight: calculatedWeight,
            ));
          });
        }
      }

      if (items.isEmpty) return;

      _currentSeats = items;

      // Buat fingerprint untuk mendeteksi perubahan status kursi
      final currentFingerprint = items.map((e) => '${e.seatName}:${e.isFilled}').join(',');

      if (currentFingerprint != _lastSentFingerprint) {
        // Status kursi berubah! Debounce 3 detik sebelum kirim ke Borlindo
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 3), () {
          debugPrint('[BorlindoApi] Occupancy changed. Triggering sync...');
          sendCurrentSeats(isHeartbeat: false);
        });
      }
    } catch (e) {
      debugPrint('Error parsing seat payload for Borlindo API: $e');
    }
  }

  /// Mengirim status kursi saat ini ke endpoint API Borlindo
  Future<bool> sendCurrentSeats({bool isHeartbeat = false}) async {
    if (!_isEnabled || _currentSeats.isEmpty) return false;

    if (_busIdentity.isEmpty) {
      _setStatus(BorlindoSyncStatus.error, 'Plat/Identitas Bus belum diisi');
      return false;
    }

    if (_token == null || _token!.isEmpty) {
      final loginOk = await login();
      if (!loginOk) return false;
    }

    _setStatus(BorlindoSyncStatus.syncing, 'Mengirim data ke Borlindo...');

    final url = Uri.parse('$_baseUrl/iot-seat/$_busIdentity');
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final body = jsonEncode({
      'timestamp': timestamp,
      'seats': _currentSeats.map((s) => s.toJson()).toList(),
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        _lastSyncTime = DateTime.now();
        _lastSentFingerprint = _currentSeats.map((e) => '${e.seatName}:${e.isFilled}').join(',');

        final Map<String, dynamic> resData = jsonDecode(response.body);
        final String serverMsg = resData['message']?.toString() ?? 'Log IoT berhasil disimpan';

        // Periksa apakah ada warnings (misal: "Ada yang duduk sementara trip belum disetting")
        _latestWarnings = [];
        if (resData.containsKey('warnings') && resData['warnings'] is List) {
          for (var w in resData['warnings']) {
            if (w is Map && w['message'] != null) {
              final seatName = w['seat_name'] ?? '';
              _latestWarnings.add('Kursi $seatName: ${w['message']}');
            }
          }
        }

        final int totalFilled = _currentSeats.where((s) => s.isFilled == 1).length;
        final String statusText = '$serverMsg ($totalFilled/${_currentSeats.length} Terisi)';

        _setStatus(BorlindoSyncStatus.success, statusText);

        _log(
          '☁️ Sinkronisasi Borlindo Berhasil',
          message: 'Bus $_busIdentity: $statusText${_latestWarnings.isNotEmpty ? "\n⚠️ Warning: ${_latestWarnings.join(", ")}" : ""}',
        );

        return true;
      } else if (response.statusCode == 401) {
        // Token kadaluwarsa, hapus dan login ulang 1x
        debugPrint('[BorlindoApi] Token expired (401). Relogging...');
        _token = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyToken);

        final reLoginOk = await login();
        if (reLoginOk) {
          return sendCurrentSeats(isHeartbeat: isHeartbeat);
        } else {
          _setStatus(BorlindoSyncStatus.error, 'Sesi kadaluwarsa, gagal login ulang');
          return false;
        }
      } else {
        String errMsg = 'Gagal kirim (HTTP ${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            errMsg = errBody['message'].toString();
          }
        } catch (_) {}

        _setStatus(BorlindoSyncStatus.error, errMsg);
        _log('☁️ Sinkronisasi Borlindo Gagal', message: errMsg, isError: true);
        return false;
      }
    } on SocketException {
      _setStatus(BorlindoSyncStatus.offline, 'Offline (Tidak ada sinyal internet)');
      _log('☁️ Cloud Borlindo Offline', message: 'Sinyal tidak tersedia di jalan', isError: true);
      return false;
    } catch (e) {
      _setStatus(BorlindoSyncStatus.error, 'Error: $e');
      _log('☁️ Sinkronisasi Borlindo Exception', message: e.toString(), isError: true);
      return false;
    }
  }

  void _setStatus(BorlindoSyncStatus s, String msg) {
    _status = s;
    _statusMessage = msg;
    notifyListeners();
  }

  void _log(String title, {String? message, bool isError = false}) {
    if (onLogCallback != null) {
      onLogCallback!(title, message: message, isError: isError);
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
