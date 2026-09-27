import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_state.dart';
import '../models/control_panel_state.dart';
import '../services/mqtt_service.dart';
import 'glass_card.dart';
import 'playlist_editor_dialog.dart';

class RgbControlCard extends StatefulWidget {
  final double? height;
  const RgbControlCard({super.key, this.height});

  @override
  State<RgbControlCard> createState() => _RgbControlCardState();
}

class _RgbControlCardState extends State<RgbControlCard> {
  int _localActiveMode = 0;
  String? _activeCustomAnimId;
  late final CustomModePreset _customMode12Preset;
  bool _isLoadingPreset = true;

  final List<Map<String, dynamic>> _hardwareModes = [
    {"id": 1, "name": "Rainbow Glitter"},
    {"id": 2, "name": "Confetti Party"},
    {"id": 3, "name": "Sinelon Wave"},
    {"id": 4, "name": "BPM Rhythm"},
    {"id": 5, "name": "Juggle Bounce"},
    {"id": 6, "name": "Fire Flame"},
    {"id": 7, "name": "Aurora Glow"},
    {"id": 8, "name": "Binary Counter"},
    {"id": 9, "name": "Palette Wave"},
    {"id": 10, "name": "Dual Scanner"},
    {"id": 11, "name": "Color Bounce"},
    {"id": 12, "name": "Snake / Custom"},
  ];

  @override
  void initState() {
    super.initState();
    _customMode12Preset = CustomModePreset(modeId: 12, colors: []);
    _loadMode12FromLocal();
  }

  Future<void> _loadMode12FromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('rgb_mode_12_preset');

      if (cachedData != null) {
        final List<dynamic> decodedList = jsonDecode(cachedData);
        List<Color> savedColors =
            decodedList.map((hexStr) => Color(int.parse(hexStr))).toList();
        _customMode12Preset.colors = savedColors;
      }
    } catch (e) {
      debugPrint("Gagal memuat memori lokal preset mode 12: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreset = false;
        });
      }
    }
  }

  Future<void> _saveMode12ToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> dataToSave = _customMode12Preset.colors
          .map((color) => color.value.toString())
          .toList();
      await prefs.setString('rgb_mode_12_preset', jsonEncode(dataToSave));
    } catch (e) {
      debugPrint("Gagal mengamankan preset mode 12: $e");
    }
  }

  void _sendModeToHardware(
      int modeId, DeviceState s, ControlPanelState p, MqttService mqtt) {
    _activeCustomAnimId = null;

    if (mounted) {
      setState(() {
        _localActiveMode = modeId;
      });
    }
    p.setMode(modeId);

    try {
      mqtt.sendControlHttp(s.mqttHost, "mode_$modeId");
    } catch (e) {
      debugPrint("Gagal mengirim perintah mode ke hardware: $e");
    }
  }

  void _startCustomMode12Loop(
      DeviceState s, ControlPanelState p, MqttService mqtt) async {
    final String animId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeCustomAnimId = animId;

    if (mounted) {
      setState(() {
        _localActiveMode = 12;
      });
    }
    p.setMode(12);

    try {
      mqtt.sendControlHttp(s.mqttHost, "mode_12");
    } catch (e) {}

    if (_customMode12Preset.colors.isEmpty) {
      const Color defaultColor = Colors.white;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) p.setColor(defaultColor);
      });
      try {
        mqtt.setRgb(s.mqttHost, defaultColor.red, defaultColor.green,
            defaultColor.blue);
      } catch (e) {}
      return;
    }

    int localColorIndex = 0;

    while (mounted && _activeCustomAnimId == animId) {
      if (!p.animationOn || _customMode12Preset.colors.isEmpty) break;

      Color currentColor = _customMode12Preset
          .colors[localColorIndex % _customMode12Preset.colors.length];
      int nextIndex = (localColorIndex + 1) % _customMode12Preset.colors.length;
      Color targetColor = _customMode12Preset.colors[nextIndex];

      int steps = 25;
      for (int i = 0; i <= steps; i++) {
        if (!mounted || _activeCustomAnimId != animId || !p.animationOn) break;

        double t = i / steps;
        Color interpolatedColor =
            Color.lerp(currentColor, targetColor, t) ?? targetColor;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && p.animationOn) p.setColor(interpolatedColor);
        });

        if (i % 5 == 0 || i == steps) {
          try {
            mqtt.setRgb(s.mqttHost, interpolatedColor.red,
                interpolatedColor.green, interpolatedColor.blue);
          } catch (e) {}
        }
        await Future.delayed(const Duration(milliseconds: 20));
      }

      if (mounted && _activeCustomAnimId == animId && p.animationOn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) p.setColor(targetColor);
        });
        try {
          mqtt.setRgb(
              s.mqttHost, targetColor.red, targetColor.green, targetColor.blue);
        } catch (e) {}
      }

      localColorIndex++;
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ControlPanelState>();
    final s = context.watch<DeviceState>();
    final mqtt = context.read<MqttService>();

    if (!p.animationOn && _localActiveMode != 0) {
      _localActiveMode = 0;
      _activeCustomAnimId = null;
    }

    if (_isLoadingPreset) {
      return const SizedBox(
        height: 150,
        child:
            Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return GlassCard(
      height: widget.height,
      title: "LIGHTING MODES",
      trailing: GestureDetector(
        onTap: () {
          bool v = !p.animationOn;
          p.toggleAnimation(v);
          if (!v) {
            setState(() {
              _localActiveMode = 0;
              _activeCustomAnimId = null;
            });
            mqtt.sendControlHttp(s.mqttHost, "animation_off");
          } else if (p.mode > 0) {
            if (p.mode == 12) {
              _startCustomMode12Loop(s, p, mqtt);
            } else {
              _sendModeToHardware(p.mode, s, p, mqtt);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 75,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: p.animationOn
                ? Colors.blueAccent.withOpacity(0.2)
                : Colors.black.withOpacity(0.2),
            border: Border.all(
              color: p.animationOn ? Colors.blueAccent : Colors.white10,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 7,
                left: p.animationOn ? 12 : 38,
                child: Text(
                  p.animationOn ? "ON" : "OFF",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          p.animationOn ? Colors.blueAccent : Colors.white38),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: p.animationOn
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        double spacing = 8.0;
        double availableHeight = constraints.maxHeight;
        double availableWidth = constraints.maxWidth;

        double itemHeight = (availableHeight - (spacing * 2)) / 3;
        double itemWidth = (availableWidth - (spacing * 3)) / 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemCount: _hardwareModes.length,
          itemBuilder: (context, i) {
            final modeItem = _hardwareModes[i];
            int m = modeItem["id"];
            bool active = _localActiveMode == m;

            return GestureDetector(
              onTap: () {
                if (!p.animationOn) return;
                if (_localActiveMode == m && m != 12) return;

                if (m == 12) {
                  _startCustomMode12Loop(s, p, mqtt);
                } else {
                  _sendModeToHardware(m, s, p, mqtt);
                }
              },
              onLongPress: () async {
                if (!p.animationOn || m != 12) return;

                setState(() {
                  _activeCustomAnimId = null;
                });

                final List<Color>? updatedColors =
                    await showDialog<List<Color>>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      PlaylistEditorDialog(preset: _customMode12Preset),
                );

                if (updatedColors != null) {
                  setState(() {
                    _customMode12Preset.colors = updatedColors;
                    _customMode12Preset.currentStep = 0;
                  });
                  await _saveMode12ToLocal();
                  _startCustomMode12Loop(s, p, mqtt);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: !p.animationOn
                      ? Colors.white.withOpacity(0.02)
                      : (active
                          ? Colors.blueAccent
                          : Colors.white.withOpacity(0.05)),
                  border: Border.all(
                    color: !p.animationOn
                        ? Colors.white.withOpacity(0.05)
                        : (active
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white.withOpacity(0.1)),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    if (active && p.animationOn)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle)),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$m",
                                style: TextStyle(
                                  color: !p.animationOn
                                      ? Colors.white12
                                      : (active
                                          ? Colors.white
                                          : Colors.white38),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (m == 12 && p.animationOn)
                                Icon(
                                  Icons.palette_outlined,
                                  size: 11,
                                  color:
                                      active ? Colors.white70 : Colors.white24,
                                )
                            ],
                          ),
                          Text(
                            modeItem["name"],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: !p.animationOn
                                  ? Colors.white10
                                  : (active ? Colors.white : Colors.white70),
                              fontSize: 9,
                              fontWeight: active && p.animationOn
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
