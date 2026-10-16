import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class ApiService {
  final String baseUrl = ApiConstants.baseUrl;

  Future<Map<String, dynamic>> getElderThresholds(String elderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/elders/$elderId/thresholds'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Gagal mengambil data threshold');
  }

  Future<void> updateElderThresholds({
    required String elderId,
    required int minSpo2,
    required int minBpm,
    required int maxBpm,
    required double maxTemp,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/elders/$elderId/thresholds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'minSpo2': minSpo2,
        'minBpm': minBpm,
        'maxBpm': maxBpm,
        'maxTemp': maxTemp,
      }),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Gagal memperbarui threshold');
    }
  }

  Future<void> acknowledgeAlert({
    required String alertId,
    required String handledBy,
    required bool isFalseAlarm,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/alerts/$alertId/ack'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'handledBy': handledBy,
        'isFalseAlarm': isFalseAlarm,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal mengonfirmasi alarm');
    }
  }

  // Metode pemicu fitur Find My Band
  Future<void> triggerBuzzer(String elderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/elders/$elderId/trigger-buzzer'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal membunyikan gelang');
    }
  }
}