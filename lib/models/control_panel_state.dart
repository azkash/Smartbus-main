import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class CustomModePreset {
  final int modeId;
  List<Color> colors;
  int currentStep;

  CustomModePreset({
    required this.modeId,
    required this.colors,
    this.currentStep = 0,
  });

  Color getNextColor() {
    if (colors.isEmpty) return const Color(0xFFFFFFFF);
    Color next = colors[currentStep % colors.length];
    currentStep++;
    return next;
  }

  void resetPlaylist() {
    colors.clear();
    currentStep = 0;
  }
}

class ControlPanelState with ChangeNotifier {
  bool animationOn = false, auto = true, isActive = false;
  int mode = 0, _step = 0;
  double brightness = 1.0;
  Color currentColor = Colors.white;
  Timer? _timer;
  final Random _random = Random();

  void setStaticBlue() {
    _timer?.cancel();
    mode = 0;
    isActive = true;
    currentColor = const Color(0xFF0000FF);
    notifyListeners();
  }

  void setMode(int m) {
    if (mode == m) {
      stopAnimation();
      return;
    }
    mode = m;
    isActive = true;
    _startAnim(m);
  }

  void setColor(Color c) {
    _timer?.cancel();
    mode = 0;
    isActive = true;
    currentColor = c;
    notifyListeners();
  }

  void stopAnimation() {
    _timer?.cancel();
    mode = 0;
    isActive = false;
    currentColor = Colors.white;
    notifyListeners();
  }

  void toggleAnimation(bool v) {
    animationOn = v;
    if (!v) {
      _timer?.cancel();
      isActive = false;
    } else if (mode != 0) {
      _startAnim(mode);
    }
    notifyListeners();
  }

  void _startAnim(int m) {
    _timer?.cancel();
    _step = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!animationOn) return;
      switch (m) {
        case 1:
          currentColor = (_step % 2 == 0) ? Colors.white : Colors.transparent;
          break;
        case 2:
          currentColor = Colors.red
              .withOpacity(((sin(_step * 0.8) + 1) / 2).clamp(0.2, 1.0));
          break;
        case 3:
          currentColor = (_step % 6 < 2)
              ? Colors.blue
              : (_step % 6 >= 3 && _step % 6 < 5)
                  ? Colors.red
                  : Colors.transparent;
          break;
        case 4:
          currentColor = Colors.orangeAccent
              .withOpacity([0.2, 0.4, 0.7, 1.0, 0.7, 0.4][_step % 6]);
          break;
        case 5:
          currentColor =
              HSVColor.fromAHSV(1.0, (_step * 15) % 360, 1.0, 1.0).toColor();
          break;
        case 6:
          currentColor = Colors.deepPurpleAccent
              .withOpacity(((cos(_step * 0.2) + 1) / 2).clamp(0.1, 1.0));
          break;
        case 7:
          currentColor = ((_step % 15) < 6 && (_step % 15) % 2 == 0)
              ? Colors.orange
              : Colors.transparent;
          break;
        case 8:
          if (_step % 2 == 0)
            currentColor = Color.fromARGB(255, _random.nextInt(256),
                _random.nextInt(256), _random.nextInt(256));
          break;
      }
      _step++;
      notifyListeners();
    });
  }

  void setBrightness(double v) {
    brightness = v;
    notifyListeners();
  }

  void setAuto(bool v) {
    auto = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
