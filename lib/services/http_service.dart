import 'package:http/http.dart' as http;
import 'dart:convert';

class HttpService {
  // Fungsi untuk kirim data ke alat/ESP32 via HTTP Post
  static Future<void> sendPost(
      String ip, String endpoint, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('http://$ip/$endpoint');
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 2));

      print("HTTP Sent: ${response.statusCode}");
    } catch (e) {
      print("HTTP Error: $e");
    }
  }
}
