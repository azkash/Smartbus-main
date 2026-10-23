import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class PassengerWebView extends StatefulWidget {
  const PassengerWebView({Key? key}) : super(key: key);

  @override
  State<PassengerWebView> createState() => _PassengerWebViewState();
}

class _PassengerWebViewState extends State<PassengerWebView> {
  late final WebViewController _controller;
  bool _isPageLoaded = false;
  DeviceState? _deviceState;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF03070C))
      ..addJavaScriptChannel(
        'FlutterBridgeChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = jsonDecode(message.message);
            final action = data['action'];
            final seatId = data['id'];

            if (action == 'clearCall') {
              debugPrint("Pengemudi menekan Oke untuk kursi: $seatId");
              final mqtt = Provider.of<MqttService>(context, listen: false);
              final s = Provider.of<DeviceState>(context, listen: false);

              // Hapus dari state aktif
              s.clearCall(seatId.toString());

              // Kirim perintah ke master melalui WebSocket lokal.
              mqtt.sendControlHttp(s.mqttHost, "clearCall_$seatId");

              // 2. Jalur Online (MQTT): Publish ke broker MQTT jika terkoneksi
              if (mqtt.isConnected) {
                mqtt.publish(mqtt.topicPub, {
                  "action": "clearCall",
                  "id": seatId,
                });
              }
            } else if (action == 'assignSeatId' || action == 'setSeatId') {
              final newId = data['id']?.toString() ?? '';
              final uid = data['uid']?.toString() ?? '';
              final mqtt = Provider.of<MqttService>(context, listen: false);

              final result = await mqtt.assignSeatId(
                uid: uid,
                seatId: newId,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.success
                        ? "✅ Master menerima pairing Kursi $newId"
                        : "❌ ${result.message}"),
                    backgroundColor: result.success
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFB91C1C),
                  ),
                );
              }
            } else if (action == 'unpairSeat' || action == 'clearSeatId') {
              final seatTarget = (data['id'] ?? data['seatId'])?.toString() ?? '';
              if (seatTarget.isNotEmpty) {
                final mqtt = Provider.of<MqttService>(context, listen: false);
                final s = Provider.of<DeviceState>(context, listen: false);
                await mqtt.unpairSeat(seatTarget);
                s.unpairSeatLocal(seatTarget);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Pairing Kursi $seatTarget berhasil dihapus"),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            debugPrint("Gagal mengurai pesan dari React WebView: $e");
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isPageLoaded = true;
              });
              _sendCurrentPayloadToWeb();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost:8080/'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newDeviceState = Provider.of<DeviceState>(context);
    if (_deviceState != newDeviceState) {
      _deviceState?.removeListener(_onDeviceStateChanged);
      _deviceState = newDeviceState;
      _deviceState?.addListener(_onDeviceStateChanged);
    }
  }

  @override
  void dispose() {
    _deviceState?.removeListener(_onDeviceStateChanged);
    super.dispose();
  }

  void _onDeviceStateChanged() {
    _sendCurrentPayloadToWeb();
  }

  void _sendCurrentPayloadToWeb() {
    if (_isPageLoaded && _deviceState != null) {
      final payload = _deviceState!.lastSeatPayload;
      debugPrint("Suntikkan data status kursi ke WebView: $payload");

      // Gunakan Base64 encoding untuk mencegah crash sintaks JavaScript jika payload mengandung tanda kutip
      final bytes = utf8.encode(payload);
      final base64Payload = base64Encode(bytes);

      _controller.runJavaScript(
          "if (window.updateSeatDataFromFlutter) { window.updateSeatDataFromFlutter(atob('$base64Payload')); }");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
