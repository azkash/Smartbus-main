import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient setup(String broker, String clientId, int port) {
  final client = MqttBrowserClient('ws://$broker', clientId);
  client.port = 8080;

  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

  return client;
}
