class ApiConstants {
  // Ganti 'localhost' ke '10.0.2.2' jika menggunakan Android Emulator,
  // atau pakai IP Laptop (contoh: '192.168.1.10') jika uji coba di HP Android fisik.
  static const String host = 'localhost';
  static const String port = '3000';

  static const String baseUrl = 'http://$host:$port/api';
  static const String wsUrl = 'ws://$host:$port';
}