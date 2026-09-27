import 'package:flutter_test/flutter_test.dart';
import 'package:safety_protection_system/models/device_state.dart';

void main() {
  test('default master address uses router mDNS', () {
    expect(DeviceState.defaultMasterHost, 'http://bus-led.local');
  });
}
