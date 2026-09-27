import 'package:flutter/material.dart';

class WifiSignalIcon extends StatelessWidget {
  final int level; // 0: No Signal, 1: Low, 2: Mid, 3: Full
  final bool isConnected;
  final double size;

  const WifiSignalIcon({
    super.key,
    required this.level,
    required this.isConnected,
    this.size = 17,
  });

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
      return Icon(Icons.wifi_off, color: Colors.redAccent, size: size);
    }

    Color iconColor;
    IconData iconData;

    if (level >= 3) {
      iconColor = Colors.greenAccent;
      iconData = Icons.network_wifi;
    } else if (level == 2) {
      iconColor = Colors.greenAccent.withOpacity(0.8);
      iconData = Icons.network_wifi_3_bar;
    } else if (level == 1) {
      iconColor = Colors.amber;
      iconData = Icons.network_wifi_1_bar;
    } else {
      iconColor = Colors.redAccent;
      iconData = Icons.signal_wifi_0_bar;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Icon(
        iconData,
        key: ValueKey(iconData),
        color: iconColor,
        size: size,
        shadows: [
          Shadow(color: iconColor.withOpacity(0.4), blurRadius: 8),
        ],
      ),
    );
  }
}
