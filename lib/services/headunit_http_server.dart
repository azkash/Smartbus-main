import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../models/device_state.dart';

class HeadunitHttpServer {
  HttpServer? _server;

  Future<void> start(
    BuildContext context,
    DeviceState deviceState,
    void Function(String seatNumber, double weight, bool isOccupied)
        onSeatTriggered,
  ) async {
    var handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler((Request request) async {
      final path = request.url.path;

      // 1. Endpoint Penerimaan Data Sensor
      if (path == 'data' && request.method == 'POST') {
        try {
          String payload = await request.readAsString();
          final Map<String, dynamic> data = jsonDecode(payload);

          int sensorState = data['sensorState'] ?? 0;
          int reading = data['reading'] ?? 0;
          double? espVoltage = data['voltage'] != null
              ? (data['voltage'] as num).toDouble()
              : null;

          if (espVoltage != null) {
            deviceState.updateVoltage(espVoltage);
          }

          // Forward data status ke React WebView
          if (data.containsKey('seats')) {
            deviceState.updateSeatPayload(jsonEncode(data['seats']));
          } else if (data.containsKey('seatId') || data.containsKey('id')) {
            final seatId = (data['seatId'] ?? data['id']).toString();
            final isOccupied = data['occupied'] == true ||
                data['occupied'] == 1 ||
                data['occupied'] == "1" ||
                sensorState == 1;
            final isCalling = data['calling'] == true || data['calling'] == 1;
            final isSeatbelt = data['seatbelt'] == true ||
                data['seatbelt'] == 1 ||
                data['seatbelt'] == "1";
            final isSeatbeltWarning = data['seatbeltWarning'] == true ||
                data['seatbeltWarning'] == 1 ||
                data['seatbeltWarning'] == "1";
            Map<String, dynamic> webPayload = {
              seatId: {
                "occupied": isOccupied,
                "seatbelt": isSeatbelt,
                "seatbeltWarning": isSeatbeltWarning,
                "calling": isCalling,
                "online": true
              }
            };
            deviceState.updateSeatPayload(jsonEncode(webPayload));
            onSeatTriggered(seatId, reading.toDouble(), isOccupied);
          } else {
            // Forward payload langsung ke WebView
            deviceState.updateSeatPayload(payload);
            onSeatTriggered("SEAT", reading.toDouble(), sensorState == 1);
          }

          return Response.ok('Headunit Received Successfully');
        } catch (e) {
          return Response.internalServerError(body: 'Error parsing JSON');
        }
      }

      // 2. Routing GET untuk Aset Statis React WebView (Offline-First)
      if (request.method == 'GET') {
        // Jika path kosong/root, arahkan ke index.html
        String assetPath = path.isEmpty || path == '/' ? 'index.html' : path;
        String fullAssetKey = 'assets/web_app/dist/$assetPath';

        try {
          final byteData = await rootBundle.load(fullAssetKey);
          final bytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          return Response.ok(
            bytes,
            headers: {
              'Content-Type': _getContentType(assetPath),
              'Access-Control-Allow-Origin': '*',
            },
          );
        } catch (e) {
          return Response.notFound('File $assetPath tidak ditemukan');
        }
      }

      return Response.notFound('Endpoint tidak ditemukan');
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      debugPrint('Headunit HttpServer berjalan di port 8080');
    } catch (e) {
      debugPrint('Gagal mengaktifkan server di port 8080: $e');
    }
  }

  void stop() {
    _server?.close();
    _server = null;
  }
}

String _getContentType(String path) {
  if (path.endsWith('.html')) return 'text/html; charset=utf-8';
  if (path.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (path.endsWith('.css')) return 'text/css; charset=utf-8';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.ico')) return 'image/x-icon';
  return 'application/octet-stream';
}
