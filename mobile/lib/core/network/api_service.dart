import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  final http.Client _client = http.Client();

  // GET /api/elders/:id/vitals
  Future<Map<String, dynamic>> getElderVitals(String elderId) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/elders/$elderId/vitals'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mengambil data vitals: ${response.body}');
    }
  }

  // GET /api/elders/:id/thresholds
  Future<Map<String, dynamic>> getElderThresholds(String elderId) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/elders/$elderId/thresholds'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mengambil threshold: ${response.body}');
    }
  }

  // PUT /api/elders/:id/thresholds (Validasi Hard Safety Guardrails)
  Future<Map<String, dynamic>> updateElderThresholds({
    required String elderId,
    required int minSpo2,
    required int minBpm,
    required int maxBpm,
    required double maxTemp,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConstants.baseUrl}/elders/$elderId/thresholds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'minSpo2': minSpo2,
        'minBpm': minBpm,
        'maxBpm': maxBpm,
        'maxTemp': maxTemp,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else if (response.statusCode == 400) {
      // Ditolak backend karena melanggar guardrails
      throw Exception(data['message'] ?? 'Pelanggaran batas aman guardrails');
    } else {
      throw Exception('Gagal memperbarui threshold');
    }
  }

  // GET /api/elders/:id/events
  Future<List<dynamic>> getElderEvents(String elderId) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}/elders/$elderId/events'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mengambil riwayat event');
    }
  }

  // POST /api/alerts/:id/ack (Konfirmasi Alarm)
  Future<Map<String, dynamic>> acknowledgeAlert({
    required String alertId,
    required String handledBy,
    required bool isFalseAlarm,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/alerts/$alertId/ack'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'handledBy': handledBy,
        'isFalseAlarm': isFalseAlarm,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mengonfirmasi alarm');
    }
  }
}