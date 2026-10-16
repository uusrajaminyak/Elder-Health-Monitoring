import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/providers/vitals_provider.dart';
import '../../../shared/widgets/alert_dialog_widget.dart';
import '../../settings/screens/threshold_settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isDialogShowing = false;

  Color _getStatusColor(int bpm, int spo2, double? temp) {
    if (spo2 > 0 && spo2 < 95) return Colors.red;
    if (bpm > 0 && (bpm < 60 || bpm > 100)) return Colors.orange;
    if (temp != null && (temp < 36.0 || temp > 37.5)) return Colors.orange;
    return Colors.green;
  }

  void _checkAndShowAlert(vitalsState) {
    if (vitalsState.activeAlert != null && !_isDialogShowing) {
      _isDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialogWidget(alert: vitalsState.activeAlert!),
        ).then((_) {
          _isDialogShowing = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vitalsState = ref.watch(vitalsProvider);
    final telemetry = vitalsState.currentTelemetry;

    // Memicu Modal Pop-up jika ada insiden aktif
    _checkAndShowAlert(vitalsState);

    final statusColor = telemetry != null
        ? _getStatusColor(telemetry.bpm, telemetry.spo2, telemetry.temp)
        : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero-Band Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Threshold',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThresholdSettingsScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 8,
              backgroundColor: vitalsState.isOnline ? Colors.green : Colors.red,
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!vitalsState.isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Pemantauan Tidak Aktif - Gelang Offline',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),

              Card(
                color: statusColor.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: statusColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        statusColor == Colors.green
                            ? Icons.check_circle
                            : statusColor == Colors.orange
                                ? Icons.warning
                                : Icons.error,
                        color: statusColor,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Oma Mary (BAND-001)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              telemetry == null
                                  ? 'Menunggu Telemetri...'
                                  : statusColor == Colors.green
                                      ? 'Kondisi Stabil / Normal'
                                      : statusColor == Colors.orange
                                          ? 'Waspada Anomali Vital'
                                          : 'PERINGATAN KRITIS',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      telemetry?.worn == true ? Icons.watch : Icons.watch_off,
                      size: 18,
                    ),
                    label: Text(telemetry?.worn == true ? 'Dipakai' : 'Dilepas'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      telemetry?.charging == true ? Icons.battery_charging_full : Icons.battery_std,
                      size: 18,
                    ),
                    label: Text('${telemetry?.battery ?? 0}%'),
                  ),
                  if (telemetry != null && telemetry.signalQuality < 2) ...[
                    const SizedBox(width: 8),
                    const Chip(
                      backgroundColor: Colors.amberAccent,
                      label: Text('Data kurang andal', style: TextStyle(fontSize: 12)),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _VitalTile(
                      title: 'SpO2',
                      value: telemetry != null ? '${telemetry.spo2}%' : '--',
                      icon: Icons.water_drop,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VitalTile(
                      title: 'BPM',
                      value: telemetry != null ? '${telemetry.bpm}' : '--',
                      icon: Icons.favorite,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VitalTile(
                      title: 'Suhu',
                      value: telemetry?.temp != null ? '${telemetry!.temp!.toStringAsFixed(1)}°C' : '--',
                      icon: Icons.thermostat,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Tren Real-Time (SpO2 & BPM)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: vitalsState.history
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.spo2.toDouble()))
                            .toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                      ),
                      LineChartBarData(
                        spots: vitalsState.history
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.bpm.toDouble()))
                            .toList(),
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _VitalTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}