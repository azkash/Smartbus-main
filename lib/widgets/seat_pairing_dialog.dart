import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class SeatPairingDialog extends StatefulWidget {
  const SeatPairingDialog({Key? key}) : super(key: key);

  @override
  State<SeatPairingDialog> createState() => _SeatPairingDialogState();
}

class _SeatPairingDialogState extends State<SeatPairingDialog> {
  String? _selectedSeatId;
  bool _isSaving = false;

  // Daftar lengkap 43 kursi bus
  static const List<String> frontSeats = ['A', 'B'];

  static const List<String> bSeats = [
    '1B', '2B', '3B',
    '4B', '5B', '6B',
    '7B', '8B', '9B',
    '11B', '12B', // 10B kosong
    '13B', '14B', '15B',
    '16B', '17B', '18B',
    '19B', '20B', '21B'
  ];

  static const List<String> aSeats = [
    '1A',
    '2A',
    '3A',
    '4A',
    '5A',
    '6A',
    '7A',
    '8A',
    '9A',
    '10A',
    '11A',
    '12A',
    '13A',
    '14A',
    '15A',
    '16A',
    '17A',
    '18A',
    '19A',
    '20A',
    '21A'
  ];

  @override
  Widget build(BuildContext context) {
    final deviceState = Provider.of<DeviceState>(context);
    final uid = deviceState.pendingPairingUid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    final registeredSeats = deviceState.registeredSeatIds;

    return Positioned.fill(
      child: WillPopScope(
        onWillPop: () async {
          deviceState.setPendingPairingUid(null);
          return false;
        },
        child: Container(
          color: Colors.black.withOpacity(0.82),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 760,
              constraints: const BoxConstraints(maxHeight: 560),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Dialog
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings_remote_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "INISIALISASI & SETUP KURSI BARU (WIRELESS PAIRING)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Terdeteksi Modul Hardware ESP32 • UID: $uid",
                                style: TextStyle(
                                  color: Colors.cyan.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8)),
                          onPressed: () {
                            deviceState.setPendingPairingUid(null);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Petunjuk & Legend
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Pilih nomor kursi tujuan untuk modul ini:",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            _buildLegendDot(
                                const Color(0xFF10B981), "Tersedia"),
                            const SizedBox(width: 12),
                            _buildLegendDot(const Color(0xFF38BDF8), "Dipilih"),
                            const SizedBox(width: 12),
                            _buildLegendDot(
                                const Color(0xFF64748B), "Sudah Aktif"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Area Grid Kursi (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bagian Kursi Depan (A & B)
                          const Text(
                            "KURSI DEPAN (Belakang Supir)",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: frontSeats
                                .map((id) =>
                                    _buildSeatButton(id, registeredSeats))
                                .toList(),
                          ),

                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 8),

                          // Bagian Sisi Kiri (Baris B)
                          const Text(
                            "SISI KIRI (Baris B: 1B - 21B)",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: bSeats
                                .map((id) =>
                                    _buildSeatButton(id, registeredSeats))
                                .toList(),
                          ),

                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 8),

                          // Bagian Sisi Kanan (Baris A)
                          const Text(
                            "SISI KANAN (Baris A: 1A - 21A)",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: aSeats
                                .map((id) =>
                                    _buildSeatButton(id, registeredSeats))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer Tombol Aksi
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedSeatId != null
                                  ? "Target: Kursi $_selectedSeatId"
                                  : "Pilih nomor kursi di atas",
                              style: TextStyle(
                                color: _selectedSeatId != null
                                    ? Colors.cyanAccent
                                    : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              "Jalur: iot_bus → Master → Seat (UDP)",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      deviceState.setPendingPairingUid(null);
                                    },
                              child: const Text(
                                "Batal",
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              onPressed: (_selectedSeatId == null || _isSaving)
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isSaving = true;
                                      });
                                      final mqtt = Provider.of<MqttService>(
                                          context,
                                          listen: false);

                                      final result = await mqtt.assignSeatId(
                                        uid: uid,
                                        seatId: _selectedSeatId!,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(result.success
                                                ? "✅ Master menerima pairing Kursi $_selectedSeatId"
                                                : "❌ ${result.message}"),
                                            backgroundColor: result.success
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFB91C1C),
                                          ),
                                        );
                                        setState(() {
                                          _isSaving = false;
                                        });
                                        if (result.success) {
                                          deviceState
                                              .setPendingPairingUid(null);
                                        }
                                      }
                                    },
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Simpan ke Kursi $_selectedSeatId",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatButton(String id, Set<String> registeredSeats) {
    final isSelected = _selectedSeatId == id;
    final isAlreadyRegistered = registeredSeats.contains(id);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSeatId = id;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : isAlreadyRegistered
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : isAlreadyRegistered
                    ? const Color(0xFF334155)
                    : const Color(0xFF10B981).withOpacity(0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          id,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : isAlreadyRegistered
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF34D399),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
