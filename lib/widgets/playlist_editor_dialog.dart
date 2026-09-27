import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:collection/collection.dart';
import '../models/control_panel_state.dart';

class PlaylistEditorDialog extends StatefulWidget {
  final CustomModePreset preset;

  const PlaylistEditorDialog({
    super.key,
    required this.preset,
  });

  @override
  State<PlaylistEditorDialog> createState() => _PlaylistEditorDialogState();
}

class _PlaylistEditorDialogState extends State<PlaylistEditorDialog> {
  late List<Color> _tempColors;
  Color _pickerColor = const Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _tempColors = List.from(widget.preset.colors);
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    bool isDataIdentical =
        const ListEquality().equals(widget.preset.colors, _tempColors);

    return AlertDialog(
      backgroundColor: const Color(0xFF1A222D).withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "MODE ${widget.preset.modeId}: PLAYLIST EDIT",
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  SlidePicker(
                    pickerColor: _pickerColor,
                    onColorChanged: (Color color) {
                      setState(() {
                        _pickerColor = color;
                      });
                    },
                    colorModel: ColorModel.rgb,
                    enableAlpha: false,
                    displayThumbColor: true,
                    showParams: false,
                    indicatorBorderRadius:
                        const BorderRadius.all(Radius.circular(10)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pickerColor,
                      foregroundColor: _pickerColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      minimumSize: const Size(double.infinity, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_to_photos_outlined, size: 16),
                    label: Text(
                      "Masukkan Warna (${_colorToHex(_pickerColor)})",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        _tempColors.add(_pickerColor);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Antrean Warna Saat Ini (${_tempColors.length}):",
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 75,
              child: _tempColors.isEmpty
                  ? const Center(
                      child: Text(
                        "Belum ada warna. Silakan pilih di atas!",
                        style: TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                            fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tempColors.length,
                      itemBuilder: (context, index) {
                        Color colorItem = _tempColors[index];
                        Color textColor = colorItem.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white;

                        return Stack(
                          children: [
                            Container(
                              width: 75,
                              margin: const EdgeInsets.only(
                                  right: 10, top: 5, bottom: 5),
                              decoration: BoxDecoration(
                                color: colorItem,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: colorItem.withOpacity(0.2),
                                      blurRadius: 4),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Step $index",
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _colorToHex(colorItem),
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 8),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _tempColors.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 8),
                                ),
                              ),
                            )
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actionsPadding:
          const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 8),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            foregroundColor: Colors.redAccent.withOpacity(0.8),
            backgroundColor: _tempColors.isEmpty
                ? Colors.transparent
                : Colors.redAccent.withOpacity(0.06),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _tempColors.isEmpty
              ? null
              : () {
                  setState(() {
                    _tempColors.clear();
                  });
                },
          icon: Icon(Icons.delete_outline_rounded,
              size: 16,
              color: _tempColors.isEmpty
                  ? Colors.white10
                  : Colors.redAccent.withOpacity(0.8)),
          label: Text(
            "CLEAR ALL",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _tempColors.isEmpty
                  ? Colors.white10
                  : Colors.redAccent.withOpacity(0.8),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                foregroundColor: Colors.white54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.04), width: 1),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text(
                "CANCEL",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDataIdentical
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDataIdentical
                      ? Colors.white.withOpacity(0.03)
                      : Colors.blueAccent,
                  foregroundColor:
                      isDataIdentical ? Colors.white24 : Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isDataIdentical
                            ? Colors.white.withOpacity(0.02)
                            : Colors.white24,
                        width: 1),
                  ),
                ),
                onPressed: isDataIdentical
                    ? null
                    : () {
                        Navigator.of(context).pop(_tempColors);
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "SAVE & APPLY",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              isDataIdentical ? Colors.white24 : Colors.white,
                          letterSpacing: 0.8),
                    ),
                    if (!isDataIdentical) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
