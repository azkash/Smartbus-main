import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../models/control_panel_state.dart';
import 'corner_bracket_painter.dart';

class BusPreviewCard extends StatelessWidget {
  final double? height;
  const BusPreviewCard({Key? key, this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ControlPanelState>();
    final s = context.watch<DeviceState>();

    double lightIntensity =
        (p.brightness * (s.dimmerLevel / 100)).clamp(0.0, 1.0);

    final Color dynamicGlowColor =
        p.currentColor.withOpacity(p.isActive ? lightIntensity : 0.0);

    return Container(
      height: height,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF000102),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 320,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dynamicGlowColor.withOpacity(lightIntensity * 0.3),
                    blurRadius: 130,
                    spreadRadius: 45,
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 240,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dynamicGlowColor.withOpacity(lightIntensity * 0.5),
                    blurRadius: 80,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 160,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dynamicGlowColor.withOpacity(lightIntensity),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: CornerBracketPainter(
                  color: p.isActive
                      ? dynamicGlowColor.withOpacity(0.3 * lightIntensity)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
              child: Image.asset(
                "assets/images/dimmerImage.png",
                width: double.infinity,
                fit: BoxFit.contain,
                opacity: const AlwaysStoppedAnimation(0.9),
              ),
            ),
            Positioned(
              bottom: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: dynamicGlowColor,
                      blurRadius: 30 * lightIntensity,
                      spreadRadius: 6 * lightIntensity,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: Text(
                p.isActive
                    ? "EMITTING: ${(lightIntensity * 100).toInt()}%"
                    : "OFF",
                style: TextStyle(
                  color: p.isActive ? dynamicGlowColor : Colors.white10,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
