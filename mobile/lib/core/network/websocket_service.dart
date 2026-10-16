import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConstants.wsUrl));
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _streamController.add(data);
        },
        onError: (error) {
          if (!_streamController.isClosed) {
            _streamController.addError(error);
          }
        },
        onDone: () {
          if (!_streamController.isClosed) {
            _streamController.addError('WebSocket Terputus');
          }
        },
      );
    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _streamController.close();
  }
}