import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiLogin {
  // Ganti URL sesuai dengan host server Laravel kamu (misal jika lokal emulator: 10.0.2.2)
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  /// Fungsi untuk melakukan request login ke backend Laravel Sanctum
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {

        // Backend Laravel membungkus user di dalam objek 'data'
        final rawData = responseData['data'] ?? {};

        // 🎯 KUNCI UTAMA: Kita amankan 'lokasi_id' dari fungsi me() Laravel kamu
        List<dynamic> lokasiUserParsed = [];
        if (rawData['lokasi_id'] != null) {
          lokasiUserParsed = [
            {'lokasi_id': rawData['lokasi_id']}
          ];
        } else if (rawData['lokasi_user'] != null) {
          lokasiUserParsed = rawData['lokasi_user'];
        } else if (rawData['perkim_lokasi_user'] != null) {
          lokasiUserParsed = rawData['perkim_lokasi_user'];
        }

        // 🎯 SINKRONISASI TOTAL: Duplikat ke semua kemungkinan key yang dicari Flutter
        final Map<String, dynamic> optimizedUser = {
          'id': rawData['id'],
          'name': rawData['name'],
          'email': rawData['email'],
          'lokasi_id': rawData['lokasi_id'],
          'lokasi_user': lokasiUserParsed,       // Sesuai backend
          'perkim_lokasi_user': lokasiUserParsed, // Sesuai Log Terminal Flutter kamu!
        };

        return {
          'success': true,
          'message': responseData['message'] ?? 'Login berhasil',
          'token': responseData['token'] ?? responseData['access_token'],
          'user': optimizedUser,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Email atau password salah',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server. Periksa koneksi Anda.',
      };
    }
  }
}