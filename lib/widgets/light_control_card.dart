import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../models/control_panel_state.dart';
import '../services/mqtt_service.dart';
import 'glass_card.dart';

class LightControlCard extends StatefulWidget {
  final double? height;
  const LightControlCard({super.key, this.height});

  @override
  State<LightControlCard> createState() => _LightControlCardState();
}

class _LightControlCardState extends State<LightControlCard> {
  Timer? _autoTimer;

  void _startAuto(DeviceState s, ControlPanelState p, MqttService mqtt) {
    if (!p.auto) return;
    _autoTimer?.cancel();
    p.setStaticBlue();
    bool down = s.dimmerLevel >= 100;
    double lvl = s.dimmerLevel;

    if (lvl <= 0 && !down) mqtt.setPower(s.mqttHost, true);

    _autoTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted) return;
      setState(() {
        lvl += down ? -20 : 20;
        if (lvl <= 0 || lvl >= 100) {
          lvl = lvl.clamp(0, 100);
          t.cancel();
          if (lvl == 0) mqtt.setPower(s.mqttHost, false);
        }
        s.setDimmer(lvl);
        mqtt.sendControlHttp(s.mqttHost, "bright_${lvl.toInt()}");
      });
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ControlPanelState>();
    final s = context.watch<DeviceState>();
    final mqtt = context.read<MqttService>();

    return GlassCard(
      height: widget.height,
      title: "LIGHT CONTROL",
      trailing: GestureDetector(
        onTap: () {
          bool v = !p.auto;
          p.setAuto(v);
          if (!v) {
            _autoTimer?.cancel();
            s.setDimmer(0);
            mqtt.setPower(s.mqttHost, false);
            mqtt.sendControlHttp(s.mqttHost, "bright_0");
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 75,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: p.auto
                ? Colors.cyanAccent.withOpacity(0.15)
                : Colors.black.withOpacity(0.2),
            border: Border.all(
              color: p.auto ? Colors.cyanAccent : Colors.white10,
              width: 1.5,
            ),
            boxShadow: p.auto
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 7,
                left: p.auto ? 12 : 38,
                child: Text(
                  p.auto ? "ON" : "OFF",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: p.auto ? Colors.cyanAccent : Colors.white38,
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment:
                    p.auto ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.auto ? Colors.white : Colors.white54,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
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
                double size = (constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight) *
                    0.85;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: p.auto ? 1.0 : 0.15,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: size + 20,
                        height: size + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(
                                  p.auto ? (s.dimmerLevel / 250) : 0),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: size,
                        height: size,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      SizedBox(
                        width: size,
                        height: size,
                        child: CircularProgressIndicator(
                          value: s.dimmerLevel / 100,
                          strokeWidth: size * 0.08,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(Colors.blueGrey, Colors.cyanAccent,
                                    s.dimmerLevel / 100) ??
                                Colors.blueAccent,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${s.dimmerLevel.round()}",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: size * 0.3,
                                fontWeight: FontWeight.w100,
                                letterSpacing: -2),
                          ),
                          Text(
                            "LEVEL",
                            style: TextStyle(
                                color: Colors.cyanAccent.withOpacity(0.5),
                                fontSize: (size * 0.07).clamp(8, 12),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: p.auto ? 1.0 : 0.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "BRIGHTNESS",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        "${s.dimmerLevel.round()}%",
                        style: TextStyle(
                          color: p.auto ? Colors.blueAccent : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 30,
                      activeTrackColor: Colors.blueAccent.withOpacity(0.2),
                      inactiveTrackColor: Colors.transparent,
                      thumbShape: p.auto
                          ? _CustomSliderThumb()
                          : SliderComponentShape.noThumb,
                      trackShape: const RoundedRectSliderTrackShape(),
                      overlayColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: s.dimmerLevel,
                      max: 100,
                      onChanged: p.auto
                          ? (v) {
                              _autoTimer?.cancel();
                              p.setStaticBlue();
                              s.setDimmer(v);
                              mqtt.setPower(s.mqttHost, v > 0);
                              mqtt.sendControlHttp(
                                  s.mqttHost, "bright_${v.toInt()}");
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: p.auto ? Colors.white10 : Colors.white.withOpacity(0.02),
              ),
              gradient: LinearGradient(
                colors: p.auto
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.01)
                      ]
                    : [
                        Colors.transparent,
                        Colors.transparent,
                      ],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: p.auto ? () => _startAuto(s, p, mqtt) : null,
              child: Center(
                child: Text(
                  s.dimmerLevel >= 100 ? "GRADUAL DIM" : "GRADUAL BRIGHT",
                  style: TextStyle(
                    color: p.auto ? Colors.white70 : Colors.white10,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSliderThumb extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(6, 30);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 255, 255)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 4, height: 25),
        const Radius.circular(2),
      ),
      paint,
    );
  }
}
