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
    this.isOnline = true,
  });

  VitalsState copyWith({
    TelemetryModel? currentTelemetry,
    List<TelemetryModel>? history,
    AlertModel? activeAlert,
    bool? isOnline,
  }) {
    return VitalsState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      history: history ?? this.history,
      activeAlert: activeAlert,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

// Menggunakan Notifier (Riverpod 2.0+ Standard)
class VitalsNotifier extends Notifier<VitalsState> {
  @override
  VitalsState build() {
    // Mendengarkan stream WebSocket secara otomatis saat provider diinisialisasi
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      webSocketStreamProvider,
      (_, next) {
        next.whenData((message) => updateFromWebSocket(message));
      },
    );
    return VitalsState();
  }

  void updateFromWebSocket(Map<String, dynamic> message) {
    final type = message['type'];
    if (type == 'TELEMETRY_UPDATE') {
      final data = message['data'];
      final telemetry = TelemetryModel.fromJson(data);

      final updatedHistory = [...state.history, telemetry];
      if (updatedHistory.length > 30) {
        updatedHistory.removeAt(0);
      }

      state = state.copyWith(
        currentTelemetry: telemetry,
        history: updatedHistory,
      );
    } else if (type == 'FALL_EVENT') {
      final data = message['data'];
      state = state.copyWith(
        activeAlert: AlertModel(
          id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'FALL_CANDIDATE',
          title: 'Kemungkinan Jatuh Terdeteksi!',
          description: 'G-Force tinggi terdeteksi (${data['peak_g']}g).',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ),
      );
    } else if (type == 'DEVICE_STATUS') {
      state = state.copyWith(isOnline: message['isOnline'] ?? false);
    }
  }

  void clearActiveAlert() {
    state = state.copyWith(activeAlert: null);
  }
}

final vitalsProvider = NotifierProvider<VitalsNotifier, VitalsState>(VitalsNotifier.new);