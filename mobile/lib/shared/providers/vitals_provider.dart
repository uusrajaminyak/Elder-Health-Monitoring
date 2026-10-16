import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/websocket_service.dart';
import '../../core/network/api_service.dart';
import '../models/telemetry_model.dart';
import '../models/alert_model.dart';

// --- MODEL DATA RIWAYAT ANOMALI ---
enum VitalType { oksigen, denyut, suhu, jatuh }
enum EventStatus { perluDicek, sedangDitangani, normal }

class HealthEvent {
  final String id;
  final VitalType type;
  final EventStatus status;
  final DateTime timestamp;
  final String title;
  final String value;
  final String? valueUnit;
  final String subtitle;
  final String footerText;

  HealthEvent({
    required this.id, required this.type, required this.status, required this.timestamp,
    required this.title, required this.value, this.valueUnit, required this.subtitle, required this.footerText,
  });
}

// --- PROVIDER DASAR ---
final apiServiceProvider = Provider((ref) => ApiService());

final webSocketServiceProvider = Provider((ref) {
  final service = WebSocketService();
  service.connect();
  ref.onDispose(() => service.disconnect());
  return service;
});

final webSocketStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.stream;
});

// --- STATE UTAMA (MENGGABUNGKAN TELEMETRI & RIWAYAT) ---
class VitalsState {
  final TelemetryModel? currentTelemetry;
  final List<TelemetryModel> history;
  final AlertModel? activeAlert;
  final bool isOnline;
  final List<HealthEvent> anomalyHistory; 

  VitalsState({
    this.currentTelemetry,
    this.history = const [],
    this.activeAlert,
    this.isOnline = false,
    this.anomalyHistory = const [],
  });

  VitalsState copyWith({
    TelemetryModel? currentTelemetry,
    List<TelemetryModel>? history,
    AlertModel? activeAlert,
    bool clearAlert = false,
    bool? isOnline,
    List<HealthEvent>? anomalyHistory,
  }) {
    return VitalsState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      history: history ?? this.history,
      activeAlert: clearAlert ? null : (activeAlert ?? this.activeAlert),
      isOnline: isOnline ?? this.isOnline,
      anomalyHistory: anomalyHistory ?? this.anomalyHistory,
    );
  }
}

class VitalsNotifier extends Notifier<VitalsState> {
  DateTime? _lastFallEventTime;
  
  // Timer cooldown 1 menit agar riwayat tidak spam
  DateTime? _lastSpO2Anomaly;
  DateTime? _lastBpmAnomaly;
  DateTime? _lastTempAnomaly;

  @override
  VitalsState build() {
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      webSocketStreamProvider,
      (previous, next) {
        next.when(
          data: (message) => updateFromWebSocket(message),
          error: (error, stackTrace) => state = state.copyWith(isOnline: false),
          loading: () => state = state.copyWith(isOnline: false),
        );
      },
    );
    return VitalsState(isOnline: false, anomalyHistory: []);
  }

  void updateFromWebSocket(Map<String, dynamic> message) {
    try {
      final String? type = message['type']?.toString();
      final now = DateTime.now();

      if (type == 'TELEMETRY_UPDATE') {
        final rawData = message['data'];
        if (rawData != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);
          final telemetry = TelemetryModel.fromJson(data);

          final updatedHistory = [...state.history, telemetry];
          if (updatedHistory.length > 30) updatedHistory.removeAt(0);

          List<HealthEvent> newAnomalies = [];

          // 1. CEK SUHU (< 36.0 atau > 37.5) -> Menangkap 124.9 / 125.0 °C
          if (telemetry.temp != null && (telemetry.temp! < 36.0 || telemetry.temp! > 37.5)) {
            if (_lastTempAnomaly == null || now.difference(_lastTempAnomaly!).inMinutes >= 1) {
              _lastTempAnomaly = now;
              newAnomalies.add(HealthEvent(
                id: 'temp-${now.millisecondsSinceEpoch}', type: VitalType.suhu, status: EventStatus.perluDicek,
                timestamp: telemetry.timestamp, title: telemetry.temp! > 37.5 ? 'Suhu tubuh tinggi' : 'Suhu tubuh rendah',
                value: telemetry.temp!.toStringAsFixed(1).replaceAll('.', ','), valueUnit: '°C', subtitle: 'Terdeteksi dari sensor', footerText: 'Belum ditandai ditangani',
              ));
            }
          }

          // 2. CEK OKSIGEN (< 95%)
          if (telemetry.spo2 > 0 && telemetry.spo2 < 95) {
            if (_lastSpO2Anomaly == null || now.difference(_lastSpO2Anomaly!).inMinutes >= 1) {
              _lastSpO2Anomaly = now;
              newAnomalies.add(HealthEvent(
                id: 'spo2-${now.millisecondsSinceEpoch}', type: VitalType.oksigen, status: EventStatus.perluDicek,
                timestamp: telemetry.timestamp, title: 'Oksigen darah rendah', value: '${telemetry.spo2}%', subtitle: 'Terdeteksi dari sensor', footerText: 'Belum ditandai ditangani',
              ));
            }
          }

          // 3. CEK DETAK JANTUNG (< 60 atau > 100)
          if (telemetry.bpm > 0 && (telemetry.bpm < 60 || telemetry.bpm > 100)) {
            if (_lastBpmAnomaly == null || now.difference(_lastBpmAnomaly!).inMinutes >= 1) {
              _lastBpmAnomaly = now;
              newAnomalies.add(HealthEvent(
                id: 'bpm-${now.millisecondsSinceEpoch}', type: VitalType.denyut, status: EventStatus.sedangDitangani,
                timestamp: telemetry.timestamp, title: telemetry.bpm > 100 ? 'Denyut jantung tinggi' : 'Denyut jantung rendah',
                value: '${telemetry.bpm}', valueUnit: 'kali/menit', subtitle: 'Terdeteksi dari sensor', footerText: 'Dalam pemantauan',
              ));
            }
          }

          final updatedAnomalies = [...newAnomalies, ...state.anomalyHistory];

          state = state.copyWith(
            currentTelemetry: telemetry,
            history: updatedHistory,
            isOnline: true,
            anomalyHistory: updatedAnomalies, 
          );
        }
      } else if (type == 'FALL_EVENT') {
        if (_lastFallEventTime != null && now.difference(_lastFallEventTime!).inSeconds < 10) return;

        final rawData = message['data'];
        if (rawData != null) {
          _lastFallEventTime = now;
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);
          
          final alert = AlertModel(
            id: data['id']?.toString() ?? now.millisecondsSinceEpoch.toString(),
            type: 'FALL_CANDIDATE', 
            title: 'Kemungkinan Jatuh Terdeteksi!',
            description: 'G-Force tinggi terdeteksi (${data['peak_g'] ?? 0}g).', 
            status: 'PENDING', 
            createdAt: now,
          );

          // Peringatan kuning dihapus: mengambil nilai langsung tanpa ?? karena non-nullable
          final fallAnomaly = HealthEvent(
            id: alert.id, 
            type: VitalType.jatuh, 
            status: EventStatus.perluDicek,
            timestamp: alert.createdAt, 
            title: alert.title,
            value: 'Jatuh', 
            subtitle: alert.description, 
            footerText: 'Segera periksa',
          );

          state = state.copyWith(
            activeAlert: alert,
            isOnline: true,
            anomalyHistory: [fallAnomaly, ...state.anomalyHistory], 
          );
        }
      } else if (type == 'DEVICE_STATUS') {
        final bool isOnline = message['isOnline'] == true;
        state = state.copyWith(isOnline: isOnline);
      }
    } catch (e) {
      // print('[VITALS NOTIFIER ERROR]: $e'); // Dimatikan agar tidak muncul warning avoid_print
    }
  }

  void clearActiveAlert() {
    state = state.copyWith(clearAlert: true);
  }
}

final vitalsProvider = NotifierProvider<VitalsNotifier, VitalsState>(VitalsNotifier.new);

// --- PROVIDER PENGHUBUNG RIWAYAT (AGAR DI DASHBOARD/HISTORY TIDAK ERROR) ---
final anomalyHistoryProvider = Provider<List<HealthEvent>>((ref) {
  final vitalsState = ref.watch(vitalsProvider);
  return vitalsState.anomalyHistory;
});