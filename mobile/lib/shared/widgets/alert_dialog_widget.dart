import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../providers/vitals_provider.dart';

class AlertDialogWidget extends ConsumerStatefulWidget {
  final AlertModel alert;

  const AlertDialogWidget({super.key, required this.alert});

  @override
  ConsumerState<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends ConsumerState<AlertDialogWidget> {
  bool _isLoading = false;

  Future<void> _handleAck(bool isFalseAlarm) async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.acknowledgeAlert(
        alertId: widget.alert.id,
        handledBy: 'Keluarga Wali',
        isFalseAlarm: isFalseAlarm,
      );

      ref.read(vitalsProvider.notifier).clearActiveAlert();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFalseAlarm
                  ? 'Alarm ditandai sebagai alarm palsu.'
                  : 'Terima kasih, penanganan insiden telah dicatat.',
            ),
            backgroundColor: isFalseAlarm ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim konfirmasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.alert.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.alert.description, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Timer eskalasi Telegram berjalan (3 menit). Segera konfirmasi!',
                    style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          OutlinedButton(
            onPressed: () => _handleAck(true),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text('Alarm Palsu'),
          ),
          ElevatedButton(
            onPressed: () => _handleAck(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Saya Tangani'),
          ),
        ]
      ],
    );
  }
}