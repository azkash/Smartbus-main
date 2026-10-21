import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/borlindo_api_service.dart';

class BorlindoSyncDialog extends StatefulWidget {
  const BorlindoSyncDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const BorlindoSyncDialog(),
    );
  }

  @override
  State<BorlindoSyncDialog> createState() => _BorlindoSyncDialogState();
}

class _BorlindoSyncDialogState extends State<BorlindoSyncDialog> {
  late TextEditingController _busIdentityController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _baseUrlController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final api = Provider.of<BorlindoApiService>(context, listen: false);
    _busIdentityController = TextEditingController(text: api.busIdentity);
    _usernameController = TextEditingController(text: api.username);
    _passwordController = TextEditingController(text: api.password);
    _baseUrlController = TextEditingController(text: api.baseUrl);
  }

  @override
  void dispose() {
    _busIdentityController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _saveSettings(BorlindoApiService api) {
    api.updateConfig(
      busIdentity: _busIdentityController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Pengaturan Borlindo Cloud tersimpan'),
        backgroundColor: Color(0xFF0284C7),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<BorlindoApiService>(context);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (api.status) {
      case BorlindoSyncStatus.success:
        statusColor = const Color(0xFF10B981);
        statusLabel = 'TERHUBUNG';
        statusIcon = Icons.cloud_done_rounded;
        break;
      case BorlindoSyncStatus.syncing:
      case BorlindoSyncStatus.loggingIn:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'SINKRONISASI';
        statusIcon = Icons.cloud_sync_rounded;
        break;
      case BorlindoSyncStatus.error:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'ERROR';
        statusIcon = Icons.cloud_off_rounded;
        break;
      case BorlindoSyncStatus.offline:
        statusColor = const Color(0xFF94A3B8);
        statusLabel = 'OFFLINE';
        statusIcon = Icons.wifi_off_rounded;
        break;
      case BorlindoSyncStatus.idle:
      default:
        statusColor = const Color(0xFF64748B);
        statusLabel = 'STANDBY';
        statusIcon = Icons.cloud_queue_rounded;
        break;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 720,
        height: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F17),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF0EA5E9).withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.85),
              blurRadius: 28,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            // HEADER MODAL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTEGRASI CLOUD BORLINDO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Ticketing Reconciliation & Real-time IoT Seat Log',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BADGE STATUS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // BODY FORM & STATUS
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BANNER STATUS TERAKHIR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  api.statusMessage,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (api.lastSyncTime != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Terakhir sinkron: ${api.lastSyncTime!.hour.toString().padLeft(2, '0')}:${api.lastSyncTime!.minute.toString().padLeft(2, '0')}:${api.lastSyncTime!.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Switch(
                            value: api.isEnabled,
                            activeColor: const Color(0xFF38BDF8),
                            onChanged: (val) {
                              api.updateConfig(isEnabled: val);
                            },
                          ),
                        ],
                      ),
                    ),

                    if (api.latestWarnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                api.latestWarnings.join('\n'),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // FORM INPUTS
                    Row(
                      children: [
                        // PLAT NOMOR BUS
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _busIdentityController,
                            label: 'IDENTITAS ARMADA / PLAT BUS',
                            hint: 'DD7214RFABC',
                            icon: Icons.directions_bus_rounded,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // USERNAME PARTNER
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _usernameController,
                            label: 'USERNAME / NO. HP PARTNER',
                            hint: '085876409220',
                            icon: Icons.person_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // PASSWORD
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _passwordController,
                            label: 'PASSWORD API',
                            hint: '••••••••',
                            icon: Icons.lock_rounded,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onTogglePassword: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        // BASE URL
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _baseUrlController,
                            label: 'API BASE URL',
                            hint: 'https://v2-api.borlindo.com/api/partner/v2',
                            icon: Icons.link_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // TABEL ESTIMASI THRESHOLD TEKANAN
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.scale_rounded, color: Color(0xFF38BDF8), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'AMBANG BATAS ESTIMASI BOBOT (FSR ADC THRESHOLD)',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildThresholdBadge('< 200 ADC', '20 kg (Tas/Ringan)'),
                              _buildThresholdBadge('200-400 ADC', '30 kg (Anak)'),
                              _buildThresholdBadge('400-800 ADC', '45 kg (Remaja)'),
                              _buildThresholdBadge('800-1600 ADC', '60 kg (Dewasa Normal)'),
                              _buildThresholdBadge('1600-2600 ADC', '75 kg (Dewasa Besar)'),
                              _buildThresholdBadge('> 2600 ADC', '85 kg (Dewasa Berat)'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (api.currentSeats.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'PREVIEW STATUS KURSI & BOBOT TERDETEKSI (${api.currentSeats.length} Kursi):',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D131F),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: api.currentSeats.map((s) {
                              final isFilled = s.isFilled == 1;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFilled
                                      ? const Color(0xFF10B981).withOpacity(0.15)
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFilled
                                        ? const Color(0xFF10B981).withOpacity(0.4)
                                        : Colors.white10,
                                  ),
                                ),
                                child: Text(
                                  'Kursi ${s.seatName}: ${isFilled ? "${s.weight} kg" : "Kosong"}',
                                  style: TextStyle(
                                    color: isFilled ? const Color(0xFF34D399) : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // FOOTER ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16),
                    label: const Text(
                      'TES LOGIN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () async {
                      _saveSettings(api);
                      await api.login();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text(
                      'KIRIM LOG SEKARANG',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () async {
                      _saveSettings(api);
                      await api.sendCurrentSeats(isHeartbeat: false);
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text(
                      'SIMPAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      _saveSettings(api);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF161F30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(icon, color: Colors.white38, size: 16),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  onPressed: onTogglePassword,
                  splashRadius: 16,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdBadge(String adcRange, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$adcRange: ',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
