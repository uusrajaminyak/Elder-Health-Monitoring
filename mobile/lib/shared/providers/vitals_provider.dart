import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/websocket_service.dart';
import '../../core/network/api_service.dart';
import '../models/telemetry_model.dart';
import '../models/alert_model.dart';

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

class VitalsState {
  final TelemetryModel? currentTelemetry;
  final List<TelemetryModel> history;
  final AlertModel? activeAlert;
  final bool isOnline;

  VitalsState({
    this.currentTelemetry,
    this.history = const [],
    this.activeAlert,
    this.isOnline = false,
  });

  VitalsState copyWith({
    TelemetryModel? currentTelemetry,
    List<TelemetryModel>? history,
    AlertModel? activeAlert,
    bool clearAlert = false, // Flag untuk mereset activeAlert secara eksplisit
    bool? isOnline,
  }) {
    return VitalsState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      history: history ?? this.history,
      activeAlert: clearAlert ? null : (activeAlert ?? this.activeAlert),
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class VitalsNotifier extends Notifier<VitalsState> {
  DateTime? _lastFallEventTime;

  @override
  VitalsState build() {
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      webSocketStreamProvider,
      (previous, next) {
        next.when(
          data: (message) => updateFromWebSocket(message),
          error: (error, stackTrace) {
            state = state.copyWith(isOnline: false);
          },
          loading: () {
            state = state.copyWith(isOnline: false);
          },
        );
      },
    );

    return VitalsState(isOnline: false);
  }

  void updateFromWebSocket(Map<String, dynamic> message) {
    try {
      final String? type = message['type']?.toString();

      if (type == 'TELEMETRY_UPDATE') {
        final rawData = message['data'];
        if (rawData != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);
          final telemetry = TelemetryModel.fromJson(data);

          final updatedHistory = [...state.history, telemetry];
          if (updatedHistory.length > 30) {
            updatedHistory.removeAt(0);
          }

          state = state.copyWith(
            currentTelemetry: telemetry,
            history: updatedHistory,
            isOnline: true,
          );
        }
      } else if (type == 'FALL_EVENT') {
        final now = DateTime.now();
        // Guard Anti-Spam: Abaikan event jatuh jika jaraknya kurang dari 10 detik
        if (_lastFallEventTime != null && now.difference(_lastFallEventTime!).inSeconds < 10) {
          return;
        }

        final rawData = message['data'];
        if (rawData != null) {
          _lastFallEventTime = now;
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData as Map);

          // PENTING: Instansiasi eksplisit AlertModel untuk menghindari TypeError pada Flutter Web
          final alert = AlertModel(
            id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'FALL_CANDIDATE',
            title: 'Kemungkinan Jatuh Terdeteksi!',
            description: 'G-Force tinggi terdeteksi (${data['peak_g'] ?? 0}g).',
            status: 'PENDING',
            createdAt: DateTime.now(),
          );

          state = state.copyWith(
            activeAlert: alert,
            isOnline: true,
          );
        }
      } else if (type == 'DEVICE_STATUS') {
        final bool isOnline = message['isOnline'] == true;
        state = state.copyWith(isOnline: isOnline);
      }
    } catch (e) {
      // Menangkap error parsing agar tidak merusak state Riverpod
      print('[VITALS NOTIFIER ERROR]: $e');
    }
  }

  void clearActiveAlert() {
    state = state.copyWith(clearAlert: true);
  }
}

final vitalsProvider = NotifierProvider<VitalsNotifier, VitalsState>(VitalsNotifier.new);