import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient setup(String broker, String clientId, int port) {
  final client = MqttServerClient(broker, clientId);
  client.port = port;
  return client;
}
