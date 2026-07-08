import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL mengarah ke emulator lokal laptop yang terhubung ke Laragon
  static const String baseUrl = "http://10.0.2.2:8000/api";

  // Client HTTP reusable
  final http.Client client = http.Client();

  // Header standar untuk komunikasi JSON API
  Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================================
  // 🎯 CORE INTERCEPTOR (Helper Utama Penanganan Server Mati untuk Semua Method)
  // =========================================================================
  Future<http.Response> _safeRequest(Future<http.Response> Function() requestCall) async {
    try {
      // Jalankan request HTTP dan batasi waktu respon maksimal 7 detik
      final response = await requestCall().timeout(const Duration(seconds: 7));
      return response;
    } on SocketException {
      // Otomatis terpicu jika Laragon mati, salah IP, atau tidak ada internet
      throw 'Server sedang pemeliharaan. Silakan coba beberapa saat lagi.';
    } on TimeoutException {
      // Otomatis terpicu jika server Laragon overload atau lambat merespon
      throw 'Koneksi terputus. Server sedang pemeliharaan.';
    } catch (e) {
      // Error sistem tidak terduga lainnya
      throw 'Terjadi kesalahan sistem.';
    }
  }

  // =========================================================================
  // 1. FUNCTION GET
  // =========================================================================
  Future<http.Response> get(String endpoint, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return _safeRequest(() => client.get(
      url,
      headers: _getHeaders(token),
    ));
  }

  // =========================================================================
  // 2. FUNCTION POST
  // =========================================================================
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body, String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return _safeRequest(() => client.post(
      url,
      headers: _getHeaders(token),
      body: body != null ? json.encode(body) : null,
    ));
  }

  // =========================================================================
  // 3. FUNCTION PUT
  // =========================================================================
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body, String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return _safeRequest(() => client.put(
      url,
      headers: _getHeaders(token),
      body: body != null ? json.encode(body) : null,
    ));
  }

  // =========================================================================
  // 4. FUNCTION DELETE
  // =========================================================================
  Future<http.Response> delete(String endpoint, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return _safeRequest(() => client.delete(
      url,
      headers: _getHeaders(token),
    ));
  }

  // Jangan lupa menutup client jika Service dihancurkan untuk mencegah memory leak
  void dispose() {
    client.close();
  }
}