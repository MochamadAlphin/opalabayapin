import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogicProfile {
  // 🎯 DISESUAIKAN: Menggunakan variabel non-static, sama persis dengan DashboardLogic
  final String baseUrl = "http://10.0.2.2:8000/api";

  // Helper untuk generate header standar (Sama seperti DashboardLogic)
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  /// Fungsi untuk mengambil data profil user menggunakan Laravel Sanctum token
  Future<Map<String, dynamic>> getProfile(String token) async {
    final Map<String, String> headers = _getHeaders(token);

    try {
      debugPrint("--- REFRESH DATA PROFILE SIRAJA (TAHUN 2026) ---");

      // Menggunakan http.get langsung dengan proteksi timeout 7 detik
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: headers,
      ).timeout(const Duration(seconds: 7));

      // 🎯 DISESUAIKAN: Langsung throw 'Unauthenticated' jika 401, biar ditendang ke login oleh UI
      if (response.statusCode == 401) {
        throw 'Unauthenticated';
      }

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw 'Server Error Profile Status: Respon kosong';
        }

        final dynamic responseData = json.decode(response.body);
        Map<String, dynamic>? userData;

        if (responseData is Map<String, dynamic>) {
          userData = responseData['data'] ?? responseData['user'] ?? responseData;
        }

        if (userData != null) {
          return {
            'success': true,
            'data': userData,
          };
        }

        throw 'Data profil tidak valid';
      } else {
        throw 'Server Error Profile Status: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint("❌ Fatal Exception Profile Logic (getProfile) caught: $e");
      // 🎯 FIX UTAMA: Melempar kembali (rethrow) error agar ditangkap blok try-catch di UI
      rethrow;
    }
  }

  /// Fungsi untuk mengubah password user ke endpoint backend Laravel
  Future<Map<String, dynamic>> changePassword(
      String token,
      String currentPassword,
      String newPassword,
      ) async {
    final Map<String, String> headers = _getHeaders(token);

    try {
      debugPrint("--- POST CHANGE PASSWORD SIRAJA (TAHUN 2026) ---");

      // Menggunakan http.post langsung dengan payload JSON encoded & timeout 7 detik
      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: headers,
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 401) {
        throw 'Unauthenticated';
      }

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw 'Server Error Password Status: Respon kosong';
        }

        final Map<String, dynamic> responseData = json.decode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password berhasil diperbarui.',
        };
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal memperbarui password.',
        };
      }
    } catch (e) {
      debugPrint("❌ Fatal Exception Profile Logic (changePassword) caught: $e");
      // 🎯 FIX UTAMA: Melempar kembali (rethrow) error agar ditangkap blok try-catch di UI
      rethrow;
    }
  }
}