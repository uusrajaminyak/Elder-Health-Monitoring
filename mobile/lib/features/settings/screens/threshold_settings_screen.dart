import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/vitals_provider.dart';

class ThresholdSettingsScreen extends ConsumerStatefulWidget {
  final String elderId;

  const ThresholdSettingsScreen({super.key, this.elderId = '1'});

  @override
  ConsumerState<ThresholdSettingsScreen> createState() => _ThresholdSettingsScreenState();
}

class _ThresholdSettingsScreenState extends ConsumerState<ThresholdSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _spo2Controller = TextEditingController();
  final _minBpmController = TextEditingController();
  final _maxBpmController = TextEditingController();
  final _maxTempController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCurrentThresholds();
  }

  Future<void> _fetchCurrentThresholds() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getElderThresholds(widget.elderId);

      _spo2Controller.text = (data['minSpo2'] ?? 95).toString();
      _minBpmController.text = (data['minBpm'] ?? 60).toString();
      _maxBpmController.text = (data['maxBpm'] ?? 100).toString();
      _maxTempController.text = (data['maxTemp'] ?? 37.5).toString();
    } catch (e) {
      _spo2Controller.text = '95';
      _minBpmController.text = '60';
      _maxBpmController.text = '100';
      _maxTempController.text = '37.5';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveThresholds() async {
    if (!_formKey.currentState!.validate()) return;

    final minSpo2 = int.tryParse(_spo2Controller.text) ?? 95;
    final minBpm = int.tryParse(_minBpmController.text) ?? 60;
    final maxBpm = int.tryParse(_maxBpmController.text) ?? 100;
    final maxTemp = double.tryParse(_maxTempController.text) ?? 37.5;

    // Client-side Hard Safety Guardrails (SRS FR-THR-02)
    if (minSpo2 < 88) {
      _showError('Pelanggaran Guardrail: Batas bawah SpO2 minimal 88%.');
      return;
    }
    if (minBpm < 40) {
      _showError('Pelanggaran Guardrail: Batas bawah BPM minimal 40.');
      return;
    }
    if (maxBpm > 130) {
      _showError('Pelanggaran Guardrail: Batas atas BPM maksimal 130.');
      return;
    }
    if (maxTemp > 38.0) {
      _showError('Pelanggaran Guardrail: Batas atas suhu maksimal 38.0°C.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateElderThresholds(
        elderId: widget.elderId,
        minSpo2: minSpo2,
        minBpm: minBpm,
        maxBpm: maxBpm,
        maxTemp: maxTemp,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Threshold berhasil diperbarui.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Threshold')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hard Safety Guardrails',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Batas aman yang ditetapkan oleh sistem untuk mencegah toleransi medis yang berbahaya.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _spo2Controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas Bawah SpO2 (%)',
                        helperText: 'Minimal 88% (Guardrail System)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minBpmController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min BPM',
                              helperText: 'Min: 40',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => (val == null || val.isEmpty) ? 'Wajib' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxBpmController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max BPM',
                              helperText: 'Max: 130',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => (val == null || val.isEmpty) ? 'Wajib' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _maxTempController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Batas Atas Suhu Kulit (°C)',
                        helperText: 'Maksimal 38.0°C (Guardrail System)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveThresholds,
                        child: _isSaving
                            ? const CircularProgressIndicator()
                            : const Text('Simpan Pengaturan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}