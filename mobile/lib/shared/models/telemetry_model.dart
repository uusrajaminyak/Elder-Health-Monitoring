class TelemetryModel {
  final int bpm;
  final int spo2;
  final double? temp;
  final int signalQuality;
  final int battery;
  final bool charging;
  final bool worn;
  final DateTime timestamp;

  TelemetryModel({
    required this.bpm,
    required this.spo2,
    this.temp,
    required this.signalQuality,
    required this.battery,
    required this.charging,
    required this.worn,
    required this.timestamp,
  });

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    return TelemetryModel(
      bpm: json['bpm'] ?? 0,
      spo2: json['spo2'] ?? 0,
      temp: json['temp'] != null ? (json['temp'] as num).toDouble() : null,
      signalQuality: json['signal_quality'] ?? 0,
      battery: json['battery'] ?? 0,
      charging: json['charging'] ?? false,
      worn: json['worn'] ?? true,
      timestamp: json['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['ts'] as int) * 1000)
          : DateTime.now(),
    );
  }
}