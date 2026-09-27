import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'main_control_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _busSlide;
  late Animation<double> _busOpacity;
  late Animation<double> _loadingProgress;
  late AnimationController _textController;

  final String _targetText = "SMART BUS";

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _busSlide = Tween<double>(begin: 35.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _mainController,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );

    _busOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5)),
    );

    _loadingProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainController,
          curve: const Interval(0.1, 1.0, curve: Curves.easeInOutCubic)),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mainController.forward();
        _textController.forward();
      }
    });

    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1200),
            pageBuilder: (context, anim, secondAnim) =>
                const MainControlScreen(),
            transitionsBuilder: (context, anim, secondAnim, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Widget _buildUltraCinematicText(String text) {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(text.length, (index) {
            double start = (index / text.length) * 0.7;
            double end = start + 0.3;

            double progress = CurvedAnimation(
              parent: _textController,
              curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
                  curve: Curves.easeOutQuart),
            ).value;

            double blurValue = lerpDouble(20.0, 0.0, progress) ?? 0;
            double scaleValue = lerpDouble(1.5, 1.0, progress) ?? 1.0;

            return Opacity(
              opacity: progress,
              child: ImageFiltered(
                imageFilter:
                    ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                child: Transform.scale(
                  scale: scaleValue,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      text[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: lerpDouble(15.0, 6.0, progress),
                        shadows: [
                          Shadow(
                            color:
                                Colors.blueAccent.withOpacity(progress * 0.5),
                            blurRadius: 15 * progress,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
              top: -150,
              right: -100,
              child: _GlowCircle(
                  color: Colors.blueAccent.withOpacity(0.07), size: 400)),
          Positioned(
              bottom: -150,
              left: -100,
              child: _GlowCircle(
                  color: Colors.indigoAccent.withOpacity(0.05), size: 500)),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _busSlide.value),
                      child: Opacity(
                        opacity: _busOpacity.value,
                        child: Container(
                          padding: EdgeInsets.zero,
                          child: Image.asset(
                            "assets/images/newarmd.png",
                            width: 650,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                _buildUltraCinematicText(_targetText),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    double subProgress = CurvedAnimation(
                      parent: _textController,
                      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
                    ).value;
                    return Opacity(
                      opacity: subProgress,
                      child: Text(
                        "SAFETY PROTECTION SYSTEM",
                        style: TextStyle(
                          color: Colors.blueAccent.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.5,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    double barWidth = 280;
                    return Column(
                      children: [
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                                width: barWidth,
                                height: 2.0,
                                color: Colors.white.withOpacity(0.05)),
                            Container(
                              width: barWidth * _loadingProgress.value,
                              height: 2.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent.withOpacity(0.2),
                                    Colors.blueAccent,
                                    Colors.white,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1)
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "INITIALIZING SYSTEM... ${(_loadingProgress.value * 100).toInt()}%",
                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(0.45 * _mainController.value),
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent])),
    );
  }
}
