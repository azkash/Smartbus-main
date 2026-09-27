import 'package:flutter/material.dart';

class BusWidget extends StatelessWidget {
  final Color bodyColor;
  final Color lightsColor;
  final double brightness;
  final bool showBody;
  final bool showLights;

  const BusWidget({
    Key? key,
    required this.bodyColor,
    required this.lightsColor,
    required this.brightness,
    this.showBody = true,
    this.showLights = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showBody)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                    bodyColor.withOpacity(brightness), BlendMode.srcATop),
                child: Image.asset('assets/images/bus_body.png',
                    fit: BoxFit.contain),
              ),
            if (showLights)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                    lightsColor.withOpacity(brightness), BlendMode.srcATop),
                child: Image.asset('assets/images/bus_lights.png',
                    fit: BoxFit.contain),
              ),
          ],
        ),
      ),
    );
  }
}
