import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/vitals_provider.dart';

class ThresholdSettingsScreen extends ConsumerStatefulWidget {
  const ThresholdSettingsScreen({super.key});

  @override
  ConsumerState<ThresholdSettingsScreen> createState() => _ThresholdSettingsScreenState();
}

class _ThresholdSettingsScreenState extends ConsumerState<ThresholdSettingsScreen> {
  double _minBpm = 60.0;
  double _maxBpm = 100.0;
  double _minSpo2 = 95.0;
  double _maxTemp = 37.5;

  bool _isLoading = false;

  void _resetToDefault() {
    setState(() {
      _minBpm = 60.0;
      _maxBpm = 100.0;
      _minSpo2 = 95.0;
      _maxTemp = 37.5;
    });
  }

  Future<void> _saveThresholds() async {
    // Validasi Hard Safety Guardrails (SRS FR-THR-02)
    if (_minSpo2 < 88) {
      _showErrorSnackBar('Batas SpO2 tidak boleh diatur di bawah 88% demi keselamatan lansia.');
      return;
    }
    if (_minBpm < 40) {
      _showErrorSnackBar('Batas minimal BPM tidak boleh di bawah 40 BPM.');
      return;
    }
    if (_maxBpm > 130) {
      _showErrorSnackBar('Batas maksimal BPM tidak boleh di atas 130 BPM.');
      return;
    }
    if (_maxTemp > 38.0) {
      _showErrorSnackBar('Batas maksimal suhu tubuh tidak boleh di atas 38,0°C.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateElderThresholds(
        elderId: '1',
        minSpo2: _minSpo2.round(),
        minBpm: _minBpm.round(),
        maxBpm: _maxBpm.round(),
        maxTemp: double.parse(_maxTemp.toStringAsFixed(1)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batas aman berhasil diperbarui.'),
            backgroundColor: AppColors.forestGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal menyimpan batas aman: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.alertRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Pengaturan untuk batas aman Nenek',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Callout Tim Perawatan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mintGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.forestGreen, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ikuti arahan tim perawatan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.forestGreen,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nilai awal ini hanya contoh. Sesuaikan batas hanya dengan arahan tim perawatan Nenek.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.forestGreen,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Kartu 1: Denyut Jantung
              _buildBpmCard(),
              const SizedBox(height: 16),

              // Kartu 2: Oksigen Darah
              _buildSpo2Card(),
              const SizedBox(height: 16),

              // Kartu 3: Suhu Tubuh
              _buildTempCard(),
              const SizedBox(height: 16),

              // Banner Guardrail
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warningText, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Batas berisiko akan ditolak. Jangan menurunkan batas oksigen untuk mengabaikan peringatan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warningText,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Simpan Batas
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveThresholds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text(
                    'Simpan Batas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Batal
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _resetToDefault,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBpmCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.favorite_border, color: AppColors.forestGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Denyut Jantung',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Batas bawah', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_minBpm.round()}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Text('kali/menit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Batas atas', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_maxBpm.round()}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Text('kali/menit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.forestGreen,
              inactiveTrackColor: AppColors.disabledCard,
              thumbColor: AppColors.forestGreen,
            ),
            child: RangeSlider(
              values: RangeValues(_minBpm, _maxBpm),
              min: 40,
              max: 140,
              divisions: 100,
              onChanged: (values) {
                setState(() {
                  _minBpm = values.start;
                  _maxBpm = values.end;
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('40 kali/menit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('140 kali/menit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '↓ Di bawah 60 / ↑ Di atas 100: perhatian',
            style: TextStyle(fontSize: 11, color: AppColors.alertRed, fontWeight: FontWeight.w500),
          ),
          const Text(
            '✓ 60–100: rentang pantau   ·   ! Mendekati batas',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSpo2Card() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.water_drop_outlined, color: AppColors.forestGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Oksigen Darah',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.mintGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Batas minimum', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_minSpo2.round()}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Text('%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.forestGreen,
              inactiveTrackColor: AppColors.disabledCard,
              thumbColor: AppColors.forestGreen,
            ),
            child: Slider(
              value: _minSpo2,
              min: 80,
              max: 100,
              divisions: 20,
              onChanged: (value) {
                setState(() => _minSpo2 = value);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('80%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('100%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '↓ Di bawah 95%: perlu perhatian',
            style: TextStyle(fontSize: 11, color: AppColors.alertRed, fontWeight: FontWeight.w500),
          ),
          const Text(
            '✓ 95–100%: rentang pantau   ·   ! Mendekati batas',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTempCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.thermostat_outlined, color: AppColors.forestGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Suhu Tubuh Maksimum',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.mintGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Batas maksimum', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _maxTemp.toStringAsFixed(1).replaceAll('.', ','),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Text('°C', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.forestGreen,
              inactiveTrackColor: AppColors.disabledCard,
              thumbColor: AppColors.forestGreen,
            ),
            child: Slider(
              value: _maxTemp,
              min: 35.0,
              max: 40.0,
              divisions: 50,
              onChanged: (value) {
                setState(() => _maxTemp = value);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('35,0 °C', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('40,0 °C', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '↑ Di atas 37,5 °C: indikasi demam',
            style: TextStyle(fontSize: 11, color: AppColors.alertRed, fontWeight: FontWeight.w500),
          ),
          const Text(
            '✓ 36,0–37,5 °C: rentang pantau normal',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}