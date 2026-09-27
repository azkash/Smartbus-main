import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _videoController = VideoPlayerController.asset(
      'assets/videos/dashboard.mkv',
    )..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0D13),
              Color(0xFF151A24),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final t = _controller.value;
                final sweep = (sin(t * 2 * pi) + 1) / 2;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Depth Shadow
                    Container(
                      width: size.width,
                      height: size.height,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.65),
                            blurRadius: 90,
                            spreadRadius: 18,
                          ),
                        ],
                      ),
                    ),

                    // VIDEO PLAYER RESPONSIVE
                    if (_videoController.value.isInitialized)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isLandscape =
                              constraints.maxWidth > constraints.maxHeight;

                          final screenRatio =
                              constraints.maxWidth / constraints.maxHeight;

                          final videoRatio = _videoController.value.aspectRatio;

                          BoxFit fitMode;

                          if (isLandscape) {
                            fitMode = BoxFit.cover;
                          } else {
                            // PORTRAIT = fleksibel
                            if ((screenRatio - videoRatio).abs() < 0.25) {
                              fitMode = BoxFit.cover;
                            } else {
                              fitMode = BoxFit.contain;
                            }
                          }

                          return ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment(-1 + sweep * 2, -1),
                                end: Alignment(1 + sweep * 2, 1),
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.10),
                                  Colors.white.withOpacity(0.0),
                                ],
                                stops: const [0.4, 0.5, 0.6],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.screen,
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: fitMode,
                                child: SizedBox(
                                  width: _videoController.value.size.width,
                                  height: _videoController.value.size.height,
                                  child: VideoPlayer(_videoController),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const CircularProgressIndicator(),

                    // AMOLED VIGNETTE
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              radius: 1.2,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
