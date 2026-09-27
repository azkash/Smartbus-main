import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../models/control_panel_state.dart';
import '../services/mqtt_service.dart';
import 'glass_card.dart';

class AmbientLightCard extends StatefulWidget {
  final double? height;
  const AmbientLightCard({super.key, this.height});

  @override
  State<AmbientLightCard> createState() => _AmbientLightCardState();
}

class _AmbientLightCardState extends State<AmbientLightCard> {
  int _lastMqttSendTimestamp = 0;
  double? _lastValidAngle;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ControlPanelState>();
    final mqtt = context.read<MqttService>();
    final s = context.watch<DeviceState>();

    bool isWheelActive = !p.animationOn;

    final List<Color> colorPresets = [
      const Color(0xFF00FF00),
      const Color(0xFFFFFFFF),
      const Color(0xFFFF0000),
      const Color(0xFF0000FF),
      const Color(0xFFFFFF00),
      const Color(0xFF00FFFF),
      const Color(0xFFFF00FF),
      const Color(0xFFFF8C00),
      const Color(0xFF8A2BE2),
      const Color(0xFFFF1493),
    ];

    return GlassCard(
      height: widget.height,
      title: "RGB CONTROL",
      trailing: GestureDetector(
        onTap: () {
          bool targetAnimationState = isWheelActive;
          p.toggleAnimation(targetAnimationState);

          if (targetAnimationState) {
            mqtt.sendControlHttp(s.mqttHost, "animation_off");
          } else {
            mqtt.setRgb(s.mqttHost, p.currentColor.red, p.currentColor.green,
                p.currentColor.blue);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 75,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isWheelActive
                ? Colors.blueAccent.withOpacity(0.2)
                : Colors.black.withOpacity(0.2),
            border: Border.all(
              color: isWheelActive ? Colors.blueAccent : Colors.white10,
              width: 1.5,
            ),
            boxShadow: isWheelActive
                ? [
                    BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ]
                : [],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 7,
                left: isWheelActive ? 12 : 38,
                child: Text(
                  isWheelActive ? "ON" : "OFF",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isWheelActive ? Colors.blueAccent : Colors.white38,
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: isWheelActive
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWheelActive ? Colors.white : Colors.white54,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double wheelSize = (constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight) *
                    0.85;

                if (wheelSize <= 0) wheelSize = 100;

                final hsvColor = HSVColor.fromColor(p.currentColor);
                double angle = (hsvColor.hue / 360) * 2 * pi;
                double radiusRing = wheelSize / 2;
                double thumbSize = 30;
                double radiusThumb = radiusRing - (thumbSize / 2);

                return Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isWheelActive ? 1.0 : 0.15,
                    child: SizedBox(
                      width: wheelSize,
                      height: wheelSize,
                      child: GestureDetector(
                        onPanStart: isWheelActive
                            ? (_) => _lastValidAngle = null
                            : null,
                        onPanUpdate: isWheelActive
                            ? (details) => _handleColorSelection(
                                details.localPosition,
                                Size(wheelSize, wheelSize),
                                p,
                                mqtt,
                                s,
                                isDrag: true)
                            : null,
                        onTapDown: isWheelActive
                            ? (details) => _handleColorSelection(
                                details.localPosition,
                                Size(wheelSize, wheelSize),
                                p,
                                mqtt,
                                s,
                                isDrag: false)
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: wheelSize + 14,
                              height: wheelSize + 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                    width: 1),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.transparent
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: wheelSize,
                              height: wheelSize,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.yellow,
                                    Colors.green,
                                    Colors.cyan,
                                    Colors.blue,
                                    Colors.purple,
                                    Colors.red
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: wheelSize * 0.82,
                              height: wheelSize * 0.82,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0A0E14),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    radius: 0.85,
                                    colors: [
                                      p.currentColor.withOpacity(0.15),
                                      Colors.black.withOpacity(0.6)
                                    ],
                                    stops: const [0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: (wheelSize / 2) +
                                  (radiusThumb * cos(angle)) -
                                  (thumbSize / 2),
                              top: (wheelSize / 2) +
                                  (radiusThumb * sin(angle)) -
                                  (thumbSize / 2),
                              child: Container(
                                width: thumbSize,
                                height: thumbSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: isWheelActive
                                      ? [
                                          BoxShadow(
                                              color: p.currentColor
                                                  .withOpacity(0.6),
                                              blurRadius: 15,
                                              spreadRadius: 2)
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                        color: p.currentColor,
                                        shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isWheelActive
                                      ? p.currentColor.toHex()
                                      : "#DISABLED",
                                  style: TextStyle(
                                      color: isWheelActive
                                          ? Colors.white
                                          : Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isWheelActive ? 1.0 : 0.25,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25, left: 15, right: 15),
              child: SizedBox(
                height: 65,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: isWheelActive
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: colorPresets
                        .map((color) => _buildTeslaColorItem(
                            color, p, mqtt, s, isWheelActive))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleColorSelection(Offset pos, Size size, ControlPanelState p,
      MqttService mqtt, DeviceState s,
      {required bool isDrag}) {
    double centerX = size.width / 2;
    double centerY = size.height / 2;

    double targetAngle = atan2(pos.dy - centerY, pos.dx - centerX);
    if (targetAngle < 0) targetAngle += 2 * pi;

    targetAngle = targetAngle - (pi / 12);
    if (targetAngle < 0) targetAngle += 2 * pi;

    double finalAngle = targetAngle;

    if (isDrag && _lastValidAngle != null) {
      double angleDifference = targetAngle - _lastValidAngle!;

      if (angleDifference > pi) angleDifference -= 2 * pi;
      if (angleDifference < -pi) angleDifference += 2 * pi;

      finalAngle = _lastValidAngle! + (angleDifference * 0.18);

      if (finalAngle < 0) finalAngle += 2 * pi;
      if (finalAngle > 2 * pi) finalAngle -= 2 * pi;
    }

    _lastValidAngle = finalAngle;

    double hue = (finalAngle / (2 * pi)) * 360;
    Color newColor =
        HSVColor.fromAHSV(1.0, hue.clamp(0.0, 359.9), 1.0, 1.0).toColor();

    p.setColor(newColor);

    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    if (!isDrag || (currentTimestamp - _lastMqttSendTimestamp > 200)) {
      _lastMqttSendTimestamp = currentTimestamp;
      mqtt.setRgb(s.mqttHost, newColor.red, newColor.green, newColor.blue);
    }
  }

  Widget _buildTeslaColorItem(Color color, ControlPanelState p,
      MqttService mqtt, DeviceState s, bool isWheelActive) {
    bool isSelected = p.currentColor.value == color.value;
    return GestureDetector(
      onTap: isWheelActive
          ? () {
              p.setColor(color);
              _lastValidAngle = null;
              mqtt.setRgb(s.mqttHost, color.red, color.green, color.blue);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 32,
        height: isSelected && isWheelActive ? 55 : 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withOpacity(isSelected && isWheelActive ? 0.9 : 0.4),
          border: Border.all(
              color:
                  isSelected && isWheelActive ? Colors.white : Colors.white10),
        ),
        child: isSelected && isWheelActive
            ? const Icon(Icons.check, size: 12, color: Colors.white)
            : null,
      ),
    );
  }
}

extension on Color {
  String toHex() =>
      '#${value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
