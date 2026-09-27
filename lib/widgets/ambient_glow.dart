import 'package:flutter/material.dart';

class AmbientGlow extends StatelessWidget {
  final Color color;
  const AmbientGlow({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 150,
            spreadRadius: 30,
          )
        ],
      ),
    );
  }
}
