import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../models/alert_model.dart';
import '../providers/vitals_provider.dart';
import '../../features/dashboard/screens/handled_alert_screen.dart';

class AlertDialogWidget extends ConsumerStatefulWidget {
  final AlertModel alert;

  const AlertDialogWidget({
    super.key,
    required this.alert,
  });

  @override
  ConsumerState<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends ConsumerState<AlertDialogWidget> {
  bool _isLoading = false;

  Future<void> _handleAcknowledge({required bool isFalseAlarm}) async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.acknowledgeAlert(
        alertId: widget.alert.id,
        handledBy: 'Keluarga',
        isFalseAlarm: isFalseAlarm,
      );

      final now = DateTime.now();

      // 1. Bersihkan state alert di Riverpod
      ref.read(vitalsProvider.notifier).clearActiveAlert();

      if (mounted) {
        // 2. TUTUP DIALOG TERLEBIH DAHULU agar Overlay Flutter Web bersih & _isDialogShowing = false
        Navigator.of(context).pop();

        if (!isFalseAlarm) {
          // 3. Pindah ke HandledAlertScreen via Navigator utama
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => HandledAlertScreen(handledTime: now),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ditandai sebagai alarm palsu.'),
              backgroundColor: AppColors.alertOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status alarm: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryAlertRed = Color(0xFFB3261E);
    const darkAlertRed = Color(0xFF8B1212);
    final String timeStr = DateFormat('HH.mm').format(widget.alert.createdAt);

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: primaryAlertRed,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Header Peringatan Darurat
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: darkAlertRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PERINGATAN DARURAT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Judul & Timestamp
                const Text(
                  'Jatuh\nTerdeteksi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hari ini, $timeStr · laporan diterima dari gelang',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nenek terdeteksi jatuh. Ikuti langkah ini:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // Langkah 1: Kartu Pendamping Terdekat (White Card)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: darkAlertRed,
                            child: Text(
                              'BS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Bu Sari — Tetangga',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: darkAlertRed,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Hubungi Nomor Pendamping, Guna cek Kondisi Terkini Nenek.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menghubungi Bu Sari: 0812-3456-7890'),
                                backgroundColor: AppColors.forestGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkAlertRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.phone),
                          label: const Text(
                            '1. Hubungi Orang Terdekat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hubungi orang terdekat yang bisa mendatangi Nenek secepatnya untuk mengecek kondisinya.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 24),

                // Langkah 2: Tombol Saya Tangani (Matikan Alarm)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleAcknowledge(isFalseAlarm: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: darkAlertRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: darkAlertRed)
                        : const Text(
                            '2. Saya Tangani (Matikan Alarm)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Menandai Anda menangani kejadian. Ini bukan bukti Nenek sudah pulih.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Langkah 3: Tombol Alarm Palsu
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _handleAcknowledge(isFalseAlarm: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '3. Ini Alarm Palsu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.verified_outlined, color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Perlu konfirmasi sebelum menutup peringatan.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Banner Bantuan / Eskalasi Darurat
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: darkAlertRed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Orang terdekat belum menemui Nenek atau butuh bantuan?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Minta orang terdekat mengecek Nenek secepatnya. Jika kondisinya mendesak, segera hubungi layanan darurat setempat.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}