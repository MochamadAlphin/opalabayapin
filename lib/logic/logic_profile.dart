import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogicProfile {
  // Menghubungkan ke host backend Laravel di emulator lokal
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  /// Fungsi untuk mengambil data profil user menggunakan Laravel Sanctum token
  static Future<Map<String, dynamic>> getProfile(String token) async {
    final url = Uri.parse('$baseUrl/me');
    final cleanToken = token.trim();

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'data': responseData['data'],
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Sesi login telah habis (Unauthenticated). Silakan login ulang.',
        };
      }

      return {
        'success': false,
        'message': responseData['message'] ?? 'Gagal mengambil data profil.',
      };
    } catch (e) {
      debugPrint("Error pada LogicProfile: $e");
      return {
        'success': false,
        'message': 'Tidak dapat terhubung ke server backend.',
      };
    }
  }

  /// Fungsi untuk mengubah password user ke endpoint backend Laravel
  static Future<Map<String, dynamic>> changePassword(
      String token,
      String currentPassword,
      String newPassword,
      ) async {
    final url = Uri.parse('$baseUrl/change-password');
    final cleanToken = token.trim();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      // FIX: Jika status code 200 (Berhasil)
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password berhasil diperbarui.',
        };
      }

      // FIX: Mengambil pesan kegagalan asli dari validasi closure Laravel (Password lama salah / password kurang panjang)
      return {
        'success': false,
        'message': responseData['message'] ?? 'Gagal memperbarui password.',
      };
    } catch (e) {
      debugPrint("Error pada LogicProfile (changePassword): $e");
      return {
        'success': false,
        'message': 'Gagal terhubung dengan server.',
      };
    }
  }
}