# SmartBus Head Unit

Flutter head-unit application for the router-centric SmartBus network.

## Network architecture

- Router SSID: `iot_bus`
- ESP32 Master: DHCP client, advertised as `bus-led.local`
- Head unit to Master: WebSocket `ws://bus-led.local:81`
- Seats to Master: UDP on the shared router LAN
- Master web monitor: `http://bus-led.local/`

The retired `Seat-Monitoring-Bus`, `Seat-GW-*`, and `192.168.4.1`
topology must not be used. Gateway selection is not part of seat pairing.

## Run

```powershell
flutter pub get
flutter run
```

On Windows, enable Developer Mode before building Flutter applications that
use plugins, because Flutter needs symbolic-link support.

The `firmware/` directory mirrors the canonical seat and master projects from
the workspace `iot/` directory. `Code_Gateway_v1.0` is retained only as a
legacy reference and must not be flashed for the router-centric deployment.

