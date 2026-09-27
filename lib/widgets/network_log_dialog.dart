import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class NetworkLogDialog extends StatefulWidget {
  const NetworkLogDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const NetworkLogDialog(),
    );
  }

  @override
  State<NetworkLogDialog> createState() => _NetworkLogDialogState();
}

class _NetworkLogDialogState extends State<NetworkLogDialog> {
  LogType? _selectedFilter;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    final deviceState = Provider.of<DeviceState>(context);

    final allLogs = mqtt.networkLogs;
    final filteredLogs = _selectedFilter == null
        ? allLogs
        : allLogs.where((l) => l.type == _selectedFilter).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 800,
        height: 540,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F17),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.terminal_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DIAGNOSTIK & LOGFILE JARINGAN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Status: ${mqtt.isLocalWsConnected ? '🟢 WebSocket Terhubung' : '🔴 WebSocket Terputus'} • Host: ${deviceState.mqttHost}",
                          style: TextStyle(
                            color: mqtt.isLocalWsConnected
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF87171),
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Bar Filter & Aksi
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Filter Chips
                  Row(
                    children: [
                      _buildFilterChip("Semua (${allLogs.length})", null),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "Error (${allLogs.where((l) => l.type == LogType.error).length})",
                        LogType.error,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "Aksi (${allLogs.where((l) => l.type == LogType.action).length})",
                        LogType.action,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "Sukses (${allLogs.where((l) => l.type == LogType.success).length})",
                        LogType.success,
                      ),
                    ],
                  ),

                  // Action Buttons (Salin & Hapus)
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded,
                            size: 14, color: Color(0xFF38BDF8)),
                        label: const Text(
                          "Salin Log",
                          style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final buffer = StringBuffer();
                          buffer.writeln("=== SMART BUS NETWORK LOGS ===");
                          buffer.writeln("Waktu Export: ${DateTime.now()}");
                          buffer.writeln("Host ESP32: ${deviceState.mqttHost}");
                          buffer.writeln(
                              "Status WS: ${mqtt.isLocalWsConnected}\n");
                          for (var log in allLogs) {
                            buffer.writeln(
                                "[${log.timeFormatted}] [${log.type.name.toUpperCase()}] ${log.title} ${log.message != null ? '- ' + log.message! : ''} ${log.code != null ? '(Code: ' + log.code! + ')' : ''}");
                          }
                          Clipboard.setData(
                              ClipboardData(text: buffer.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "📋 Seluruh log jaringan berhasil disalin ke Clipboard!"),
                              backgroundColor: Color(0xFF0284C7),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                        label: const Text(
                          "Bersihkan",
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                        onPressed: () => mqtt.clearLogs(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Tampilan Daftar Log (Terminal Scrollable)
            Expanded(
              child: filteredLogs.isEmpty
                  ? const Center(
                      child: Text(
                        "Belum ada log tercatat",
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildLogItem(log);
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Menampilkan ${filteredLogs.length} entri log",
                    style:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      mqtt.connect(deviceState);
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14),
                        SizedBox(width: 6),
                        Text("Uji Reconnect",
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, LogType? type) {
    final isSelected = _selectedFilter == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(NetworkLogEntry log) {
    Color tagColor;
    String tagLabel;

    switch (log.type) {
      case LogType.error:
        tagColor = const Color(0xFFEF4444);
        tagLabel = "ERROR";
        break;
      case LogType.action:
        tagColor = const Color(0xFFF59E0B);
        tagLabel = "ACTION";
        break;
      case LogType.success:
        tagColor = const Color(0xFF10B981);
        tagLabel = "SUCCESS";
        break;
      case LogType.info:
      default:
        tagColor = const Color(0xFF38BDF8);
        tagLabel = "INFO";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tagColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp & Tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.timeFormatted,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 9,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tagLabel,
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Detail Isi Log
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (log.message != null && log.message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.message!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (log.code != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Code: ${log.code}",
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
