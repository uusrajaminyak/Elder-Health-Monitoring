import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnecting = false;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  void connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final uri = Uri.parse(ApiConstants.wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnecting = false;

      print('📱 [FLUTTER WS] Terhubung ke ${ApiConstants.wsUrl}');

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            _streamController.add(data);
          } catch (e) {
            print('❌ [FLUTTER WS ERROR] Gagal parse JSON WebSocket: $e');
          }
        },
        onError: (error) {
          print('❌ [FLUTTER WS ERROR] Error koneksi: $error');
          _scheduleReconnect();
        },
        onDone: () {
          print('⚠️ [FLUTTER WS] Koneksi terputus.');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      print('❌ [FLUTTER WS ERROR] Gagal membuat koneksi: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print('🔄 [FLUTTER WS] Mencoba menyambung ulang WebSocket...');
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _streamController.close();
  }
}