import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class SeatListDialog extends StatefulWidget {
  const SeatListDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SeatListDialog(),
    );
  }

  @override
  State<SeatListDialog> createState() => _SeatListDialogState();
}

class _SeatListDialogState extends State<SeatListDialog> {
  // Struktur layout kabin bus 43 kursi:
  // Kolom Depan: [A], [B]
  // 7 Kolom Baris:
  // Col 1: Top [3B, 3A], Mid [2B, 2A], Bot [1B, 1A]
  // Col 2: Top [6B, 6A], Mid [5B, 5A], Bot [4B, 4A]
  // Col 3: Top [9B, 9A], Mid [8B, 8A], Bot [7B, 7A]
  // Col 4: Top [12B, 12A], Mid [11B, 11A], Bot [null, 10A]
  // Col 5: Top [15B, 15A], Mid [14B, 14A], Bot [13B, 13A]
  // Col 6: Top [18B, 18A], Mid [17B, 17A], Bot [16B, 16A]
  // Col 7: Top [21B, 21A], Mid [20B, 20A], Bot [19B, 19A]

  static const List<Map<String, dynamic>> busColumns = [
    {
      'col': 1,
      'top': ['3B', '3A'],
      'mid': ['2B', '2A'],
      'bot': ['1B', '1A'],
    },
    {
      'col': 2,
      'top': ['6B', '6A'],
      'mid': ['5B', '5A'],
      'bot': ['4B', '4A'],
    },
    {
      'col': 3,
      'top': ['9B', '9A'],
      'mid': ['8B', '8A'],
      'bot': ['7B', '7A'],
    },
    {
      'col': 4,
      'top': ['12B', '12A'],
      'mid': ['11B', '11A'],
      'bot': [null, '10A'], // 10B kosong (tangga/toilet)
    },
    {
      'col': 5,
      'top': ['15B', '15A'],
      'mid': ['14B', '14A'],
      'bot': ['13B', '13A'],
    },
    {
      'col': 6,
      'top': ['18B', '18A'],
      'mid': ['17B', '17A'],
      'bot': ['16B', '16A'],
    },
    {
      'col': 7,
      'top': ['21B', '21A'],
      'mid': ['20B', '20A'],
      'bot': ['19B', '19A'],
    },
  ];

  void _showUnpairConfirmation(BuildContext context, String seatId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Text(
              "Hapus Pairing Kursi $seatId?",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin menghapus pairing Kursi $seatId?\n\nModul ESP32 kursi ini akan di-reset kembali ke RandomID dan dihapus dari master.",
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Batal", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              final mqtt = Provider.of<MqttService>(context, listen: false);
              final deviceState = Provider.of<DeviceState>(context, listen: false);

              // 1. Kirim unpair via WebSocket ke Master (Master broadcast UDP port 5759 ke modul kursi)
              await mqtt.unpairSeat(seatId);

              // 2. Update state lokal seketika
              deviceState.unpairSeatLocal(seatId);

              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text("Pairing Kursi $seatId berhasil dihapus"),
                    ],
                  ),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            label: const Text("Hapus Pairing"),
          ),
        ],
      ),
    );
  }

  void _showUnassignedInfo(BuildContext context, String seatId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kursi $seatId belum dipasangkan modul (belum ada client seat)."),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white38, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatItem(BuildContext context, String id, Set<String> registeredSeats) {
    // Sesuai instruksi:
    // ABU-ABU = sudah paired (ada client seat yang paired)
    // HIJAU = belum ada client seat yang paired (kosong)
    final bool isPaired = registeredSeats.contains(id);

    final Color bgColor = isPaired
        ? const Color(0xFF334155) // Abu-abu
        : const Color(0xFF065F46).withOpacity(0.55); // Hijau

    final Color borderColor = isPaired
        ? const Color(0xFF64748B) // Abu-abu border
        : const Color(0xFF10B981); // Hijau terang border

    final Color textColor = isPaired
        ? Colors.white
        : const Color(0xFFA7F3D0);

    final Color badgeColor = isPaired
        ? const Color(0xFF94A3B8)
        : const Color(0xFF34D399);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isPaired) {
            _showUnpairConfirmation(context, id);
          } else {
            _showUnassignedInfo(context, id);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isPaired
                    ? Colors.black26
                    : const Color(0xFF10B981).withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                id,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: isPaired
                      ? Colors.black45
                      : const Color(0xFF064E3B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isPaired ? "PAIRED" : "KOSONG",
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 1, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Icon(Icons.block_rounded, color: Colors.white24, size: 16),
      ),
    );
  }

  Widget _buildSeatPair(BuildContext context, List<String?> pair, Set<String> registeredSeats) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pair[0] != null)
          _buildSeatItem(context, pair[0]!, registeredSeats)
        else
          _buildEmptyPlaceholder(),
        const SizedBox(width: 4),
        if (pair.length > 1 && pair[1] != null)
          _buildSeatItem(context, pair[1]!, registeredSeats)
        else if (pair.length > 1)
          _buildEmptyPlaceholder(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = Provider.of<DeviceState>(context);
    final registeredSeats = deviceState.registeredSeatIds;
    final int pairedCount = registeredSeats.length;
    final int availableCount = (43 - pairedCount).clamp(0, 43);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 950,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF070C18),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DAFTAR & STATUS KURSI BUS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Kapasitas: 43 Jok • Paired: $pairedCount Jok (Abu-Abu) • Belum Paired: $availableCount Jok (Hijau)",
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Petunjuk & Legend
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "💡 Klik kursi abu-abu untuk menghapus pairing (Unpair)",
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      _buildLegendDot(const Color(0xFF334155), "Abu-abu: Paired (Klik = Unpair)"),
                      const SizedBox(width: 16),
                      _buildLegendDot(const Color(0xFF065F46), "Hijau: Belum Paired"),
                    ],
                  ),
                ],
              ),
            ),

            // Area Layout Kabin Bus (Horizontal Scrollable)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF030712).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Depan Bus: Supir & Kursi A, B
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon Supir (DRV)
                            Container(
                              width: 48,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_bus_rounded, color: Colors.blueAccent, size: 16),
                                  Text("DRV", style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Kursi A
                            _buildSeatItem(context, 'A', registeredSeats),
                            const SizedBox(height: 6),
                            // Kursi B
                            _buildSeatItem(context, 'B', registeredSeats),
                            const SizedBox(height: 12),
                            // Ron cabin label
                            Container(
                              width: 48,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text("PINTU", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Garis Sekat Depan
                      Container(
                        width: 1.5,
                        height: 260,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: Colors.white12,
                      ),

                      // 7 Kolom Kursi Kabin Bus
                      ...busColumns.map((colData) {
                        final int colNum = colData['col'] as int;
                        final List<String> top = List<String>.from(colData['top']);
                        final List<String> mid = List<String>.from(colData['mid']);
                        final List<dynamic> bot = colData['bot'] as List<dynamic>;

                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Label Kolom
                              Text(
                                "KOLOM $colNum",
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Baris Atas (misal 3B, 3A)
                              _buildSeatPair(context, top, registeredSeats),
                              const SizedBox(height: 6),

                              // Baris Tengah (misal 2B, 2A)
                              _buildSeatPair(context, mid, registeredSeats),
                              const SizedBox(height: 10),

                              // Aisle / Gang Pembatas tengah
                              Container(
                                width: 100,
                                height: 1,
                                color: Colors.white10,
                              ),
                              const SizedBox(height: 10),

                              // Baris Bawah (misal 1B, 1A)
                              _buildSeatPair(
                                context,
                                bot.map((e) => e as String?).toList(),
                                registeredSeats,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Status sinkron otomatis dengan Master ESP32 via WebSocket",
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Tutup", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
