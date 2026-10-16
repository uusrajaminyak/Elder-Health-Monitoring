import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/vitals_provider.dart';
import '../../../shared/widgets/alert_dialog_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isDialogShowing = false;
  bool _isRinging = false;

  Color _getThemeColor(int bpm, int spo2, double? temp) {
    if (spo2 > 0 && spo2 < 95) return AppColors.alertRed;
    if (bpm > 0 && (bpm < 60 || bpm > 100)) return AppColors.alertOrange;
    if (temp != null && (temp < 36.0 || temp > 37.5)) return AppColors.alertOrange;
    return AppColors.forestGreen;
  }

  Future<void> _handleRingBand() async {
    setState(() => _isRinging = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.triggerBuzzer('1');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinyal suara dikirim ke gelang.'),
            backgroundColor: AppColors.forestGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membunyikan gelang: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // REVISI KRITIS: Menggunakan ref.listen untuk memicu dialog HANYA jika ada alert baru masuk
    ref.listen<VitalsState>(vitalsProvider, (previous, next) {
      final hasNewAlert = next.activeAlert != null && previous?.activeAlert != next.activeAlert;
      if (hasNewAlert && !_isDialogShowing) {
        _isDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialogWidget(alert: next.activeAlert!),
        ).then((_) {
          _isDialogShowing = false;
        });
      }
    });

    final vitalsState = ref.watch(vitalsProvider);
    final telemetry = vitalsState.currentTelemetry;
    final bool isOnline = vitalsState.isOnline;
    final bool isWorn = telemetry?.worn ?? true;

    final statusColor = telemetry != null
        ? _getThemeColor(telemetry.bpm, telemetry.spo2, telemetry.temp)
        : Colors.grey;

    final String timeStr = telemetry != null
        ? DateFormat('HH.mm').format(telemetry.timestamp)
        : DateFormat('HH.mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Selamat Datang!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Monitoring - Nenek',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.mintGreen,
                      child: Text(
                        'N',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main Card (Online Normal vs Online Dilepas vs Offline)
                if (!isOnline) ...[
                  // Layout State Offline / Koneksi Terputus
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.offlineBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.wifi_off, color: AppColors.offlineText, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Armband Tidak Terhubung',
                              style: TextStyle(
                                color: AppColors.offlineText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Koneksi\nTerputus',
                          style: TextStyle(
                            color: AppColors.offlineText,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Internet Gelang Terputus',
                          style: TextStyle(
                            color: AppColors.offlineText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isWorn) ...[
                  // Layout State Gelang Dilepas
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wifi, color: AppColors.warningText, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Armband Terhubung',
                              style: TextStyle(color: AppColors.warningText, fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              telemetry?.charging == true
                                  ? Icons.battery_charging_full
                                  : Icons.battery_std,
                              color: AppColors.warningText,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${telemetry?.battery ?? 0}%',
                              style: const TextStyle(color: AppColors.warningText, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Icon(Icons.watch_off_outlined, color: AppColors.warningText, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'STATUS PEMAKAIAN',
                              style: TextStyle(
                                color: AppColors.warningText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dilepas',
                          style: TextStyle(
                            color: AppColors.warningText,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gelang masih terhubung, tetapi tidak sedang dipakai. Minta pendamping memasangkan kembali.',
                          style: TextStyle(color: AppColors.warningText, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dilepas sejak $timeStr · baru saja',
                          style: const TextStyle(
                            color: AppColors.warningText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Layout State Normal / Aktif
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wifi, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Armband Terhubung',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  telemetry?.charging == true
                                      ? Icons.battery_charging_full
                                      : Icons.battery_std,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${telemetry?.battery ?? 0}%',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'STATUS KESEHATAN',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              telemetry == null
                                  ? 'Menunggu...'
                                  : statusColor == AppColors.forestGreen
                                      ? 'Normal'
                                      : statusColor == AppColors.alertOrange
                                          ? 'Waspada'
                                          : 'Bahaya',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              telemetry == null
                                  ? 'Menerima sinyal telemetri dari gelang...'
                                  : statusColor == AppColors.forestGreen
                                      ? 'Semua hasil dalam batas pantau.'
                                      : 'Terdeteksi penyimpangan tanda vital!',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                            ),
                          ],
                        ),
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            statusColor == AppColors.forestGreen
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: Colors.white.withOpacity(0.15),
                            size: 110,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Timestamp Bar
                if (!isOnline) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terakhir terhubung $timeStr · baru saja',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Terakhir: gelang dilepas. Status kini belum diketahui.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Diperbarui $timeStr · baru saja',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Baseline Normal: SpO2 ≥ 95%, BPM 60-100, Suhu 36.0-37.5°C'),
                            ),
                          );
                        },
                        child: const Text(
                          'Memahami Tanda Vital',
                          style: TextStyle(
                            color: AppColors.forestGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Vertical Vital Cards
                _VitalCard(
                  icon: Icons.favorite_border,
                  title: 'Denyut Jantung',
                  value: (isOnline && isWorn) ? (telemetry != null ? '${telemetry.bpm}' : '--') : '--',
                  unit: (isOnline && isWorn) ? 'kali/menit' : 'Belum Diukur',
                  isActive: isOnline && isWorn,
                ),
                const SizedBox(height: 12),
                _VitalCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Oksigen Darah',
                  value: (isOnline && isWorn) ? (telemetry != null ? '${telemetry.spo2}' : '--') : '--',
                  unit: (isOnline && isWorn) ? '%' : 'Belum Diukur',
                  isActive: isOnline && isWorn,
                ),
                const SizedBox(height: 12),
                _VitalCard(
                  icon: Icons.thermostat_outlined,
                  title: 'Suhu Tubuh',
                  value: (isOnline && isWorn)
                      ? (telemetry?.temp != null
                          ? telemetry!.temp!.toStringAsFixed(1).replaceAll('.', ',')
                          : '--')
                      : '--',
                  unit: (isOnline && isWorn) ? '°C' : 'Belum Diukur',
                  isActive: isOnline && isWorn,
                ),
                const SizedBox(height: 20),

                // Seksi Pendamping & Tombol Aksi saat Offline / Unworn
                if (!isOnline) ...[
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.mintGreen,
                        child: Text(
                          'BS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Bu Sari — Tetangga',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Hubungi Nomor Pendamping, Guna cek Kondisi Terkini Nenek.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone),
                      label: const Text('Hubungi Pendamping'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: null, // Disabled button saat offline
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.disabledCard,
                        foregroundColor: AppColors.disabledText,
                        disabledBackgroundColor: AppColors.disabledCard,
                        disabledForegroundColor: AppColors.disabledText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.volume_off),
                      label: const Text('Bunyi Tidak Tersedia'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.disabledCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Periksa daya dan WiFi gelang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pastikan gelang menyala dan WiFi rumah aktif. Gelang baru bisa dibunyikan setelah tersambung.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (!isWorn) ...[
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.mintGreen,
                        child: Text(
                          'BS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Bu Sari — Tetangga',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Bisa mendatangi Nenek',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone),
                      label: const Text('Hubungi Pendamping'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isRinging ? null : _handleRingBand,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forestGreen,
                        side: const BorderSide(color: AppColors.forestGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isRinging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up_outlined),
                      label: const Text('Bunyikan Gelang'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bisa diminta karena internet tersambung. Bunyi baru dipastikan setelah gelang merespons.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                ],

                // Grafik Tren Real-time (Hanya jika online & dipakai)
                if (isOnline && isWorn) ...[
                  const Text(
                    'Tren Real-Time (SpO2 & BPM)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.only(right: 12, top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: vitalsState.history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.spo2.toDouble()))
                                .toList(),
                            isCurved: true,
                            color: AppColors.forestGreen,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: vitalsState.history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.bpm.toDouble()))
                                .toList(),
                            isCurved: true,
                            color: AppColors.alertRed,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Callout Banner Pemantauan Pasif
                if (isOnline) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isWorn ? AppColors.mintGreen : AppColors.disabledCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_outline,
                            color: isWorn ? AppColors.forestGreen : AppColors.disabledText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isWorn
                                ? 'Nenek tidak perlu menekan apa pun. Gelang memantau secara otomatis.'
                                : 'Saat gelang dilepas, pengukuran dihentikan. Data kosong tidak dicatat sebagai peringatan kesehatan.',
                            style: TextStyle(
                              color: isWorn ? AppColors.forestGreen : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Disclaimer Footer
                const Center(
                  child: Text(
                    'Angka contoh · Bukan pengganti pemeriksaan medis.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final bool isActive;

  const _VitalCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : AppColors.disabledCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.mintGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.forestGreen : AppColors.disabledText,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.textPrimary : AppColors.disabledText,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.textPrimary : AppColors.disabledText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? AppColors.textSecondary : AppColors.disabledText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}