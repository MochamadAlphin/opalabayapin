import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =========================================================================
// 1. MODEL DATA RUSUNAWA (FIXED AUTOMATIC PATH DISCOVERY)
// =========================================================================
class RusunawaModel {
  final String id;
  final String name;
  final String location;
  final String price;
  final int availableUnits;
  final List<String> facilities;
  String? imageUrl;

  RusunawaModel({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.availableUnits,
    required this.facilities,
    this.imageUrl,
  });

  factory RusunawaModel.fromJson(Map<String, dynamic> json) {
    String? extractedUrl;

    // Ambil ID Rusunawa sesuai response backend 'id_rusunawa'
    final String currentRusunId = json['id_rusunawa']?.toString() ??
        json['id']?.toString() ??
        '';

    // ============================================================
    // FIXED UTAMA: NORMALISASI VARIATIF STRUKTUR DATA GAMBAR
    // ============================================================
    final dynamic gambarData = json['gambar'];

    if (gambarData != null) {
      String? rawPath;

      if (gambarData is Map) {
        rawPath = gambarData['url_gambar']?.toString() ??
            gambarData['path_file']?.toString() ??
            gambarData['url']?.toString();
      }
      else if (gambarData is List && gambarData.isNotEmpty) {
        final firstItem = gambarData.first;
        if (firstItem is Map) {
          rawPath = firstItem['url_gambar']?.toString() ?? firstItem['path_file']?.toString();
        } else if (firstItem is String) {
          rawPath = firstItem;
        }
      }
      else if (gambarData is String) {
        rawPath = gambarData;
      }

      // Normalisasi URL File Asset dari Storage Laravel
      if (rawPath != null &&
          rawPath.trim().isNotEmpty &&
          rawPath.trim().toLowerCase() != 'null') {
        String cleanUrl = rawPath.trim();

        // Alihkan localhost ke IP Gateway Emulator Android
        cleanUrl = cleanUrl.replaceAll('localhost', '10.0.2.2');
        cleanUrl = cleanUrl.replaceAll('127.0.0.1', '10.0.2.2');

        // Jika backend mengirim path lokal / nama file mentah
        if (!cleanUrl.startsWith('http')) {
          if (cleanUrl.startsWith('/')) {
            cleanUrl = cleanUrl.substring(1);
          }

          // 🛠️ FIX UNTUK ROW DATABASE 1 & 2 (Mentah tanpa folder 'gedung/')
          // Jika string tidak mengandung slash '/' dan tidak diawali 'storage'
          if (!cleanUrl.contains('/') && !cleanUrl.startsWith('storage')) {
            cleanUrl = 'gedung/$cleanUrl';
          }

          // Antisipasi jika path sudah mengandung 'gedung/' tapi belum ada 'storage/'
          if (!cleanUrl.startsWith('storage/') && !cleanUrl.startsWith('public/')) {
            cleanUrl = 'storage/$cleanUrl';
          }

          cleanUrl = "http://10.0.2.2:8000/$cleanUrl";
        }

        extractedUrl = cleanUrl;
      }
    }

    // ============================================================
    // EKSTRAKSI FASILITAS
    // ============================================================
    List<String> extractedFacilities = [];
    final fasilitasData = json['fasilitas'];
    if (fasilitasData != null) {
      if (fasilitasData is List) {
        extractedFacilities = fasilitasData.map((e) => e.toString()).toList();
      } else if (fasilitasData is String) {
        try {
          final decoded = jsonDecode(fasilitasData);
          if (decoded is List) {
            extractedFacilities = decoded.map((e) => e.toString()).toList();
          } else if (fasilitasData.trim().isNotEmpty) {
            extractedFacilities = [fasilitasData];
          }
        } catch (_) {
          if (fasilitasData.trim().isNotEmpty) {
            extractedFacilities = [fasilitasData];
          }
        }
      }
    }

    if (extractedFacilities.isEmpty) {
      extractedFacilities = [
        'Area Terbuka Hijau',
        'Aula',
        'Sarana Olah Raga',
        'Keamanan 24Jam',
      ];
    }

    // ============================================================
    // PARSING HARGA SEWA SEARA AKURAT
    // ============================================================
    String rawPrice = json['harga_sewa']?.toString() ??
        json['mulai_dari']?.toString() ??
        json['harga']?.toString() ?? '0';

    if (rawPrice.trim().isEmpty || rawPrice == 'null') {
      rawPrice = '0';
    }

    return RusunawaModel(
      id: currentRusunId,
      name: json['nama_rusunawa']?.toString() ??
          json['nama_lokasi']?.toString() ??
          json['nama']?.toString() ??
          'Tanpa Nama',
      location: json['alamat']?.toString() ??
          json['alamat_lokasi']?.toString() ??
          'Alamat tidak tersedia',
      price: rawPrice,
      availableUnits: json['sisa_unit'] is int
          ? json['sisa_unit']
          : int.tryParse(json['sisa_unit']?.toString() ?? '0') ?? 0,
      facilities: extractedFacilities,
      imageUrl: extractedUrl,
    );
  }
}

// =========================================================================
// 2. LOGIC REGISTER (API BRIDGE)
// =========================================================================
class LogicRegister {
  static const String baseUrl = "http://10.0.2.2:8000";
  static const String apiRusunawaUrl = "$baseUrl/api/rusunawa-registrasi";

  static Future<List<RusunawaModel>> fetchRusunawaWithImages({
    String? token,
  }) async {
    try {
      debugPrint("🚀 Requesting API: $apiRusunawaUrl");

      final response = await http.get(
        Uri.parse(apiRusunawaUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      debugPrint("📡 Response Code: ${response.statusCode}");

      if (response.statusCode != 200) {
        debugPrint("❌ Server Error Body: ${response.body}");
        throw Exception("Server Error ${response.statusCode}");
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final dynamic rawData = responseData['data'];

      if (rawData == null || rawData is! List) {
        debugPrint("⚠️ Data respon kosong atau formatnya bukan berupa List");
        return [];
      }

      final List<RusunawaModel> list = [];

      for (final item in rawData) {
        try {
          if (item is Map<String, dynamic>) {
            final rusun = RusunawaModel.fromJson(item);

            debugPrint(
              "🎯 Mapped: ${rusun.name} -> Gambar: ${rusun.imageUrl}",
            );

            list.add(rusun);
          } else {
            debugPrint("⚠️ Item di dalam list data bukan berupa Map: $item");
          }
        } catch (e) {
          debugPrint("❌ Gagal parsing item data: $e | Konten Data: $item");
        }
      }

      debugPrint("✅ Sinkronisasi sukses! Total data dimuat: ${list.length}");
      return list;
    } catch (e) {
      debugPrint("🆘 Masalah Koneksi / Ekstraksi JSON: $e");
      return [];
    }
  }
}