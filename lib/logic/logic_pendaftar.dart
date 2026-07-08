import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class LogicPendaftar {
  // Endpoint API utama mengarah ke pendaftaran di Laravel
  static const String apiPendaftaranUrl = "http://10.0.2.2:8000/api/pendaftar";

  // Kunci Rahasia (Key) & IV AES-256 yang wajib sama persis dengan backend Laravel
  static const String _secretKeyString = "12345678901234567890123456789012";
  static const String _ivString = "1234567890123456";

  /// Fungsi Helper untuk mengenkripsi teks ke format AES dengan prefix 's0:'
  static String _enkripsiData(String text) {
    if (text.isEmpty) return text;
    try {
      final key = encrypt.Key.fromUtf8(_secretKeyString);
      final iv = encrypt.IV.fromUtf8(_ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      final encrypted = encrypter.encrypt(text, iv: iv);
      return "s0:${encrypted.base64}";
    } catch (e) {
      debugPrint("❌ Gagal enkripsi AES: $e");
      return text;
    }
  }

  /// Menggunakan Base64 Hash String agar match 100% dengan dekripsi crypto framework backend
  static String _buatHashSHA256(String text) {
    if (text.isEmpty) return text;
    try {
      final bytes = utf8.encode(text);
      final digest = sha256.convert(bytes);

      // Mengubah format hash menjadi format Base64 terstandardisasi
      final base64Hash = base64.encode(digest.bytes);
      return "s0:$base64Hash";
    } catch (e) {
      debugPrint("❌ Gagal membuat hash SHA-256: $e");
      return text;
    }
  }

  /// Fungsi utama untuk mendaftar dan mengirimkan data terenkripsi ke backend Laravel
  static Future<bool> kirimPendaftaran({
    required String namaLengkap,
    required String noTelp,
    required dynamic lokasiId, // Menerima rusunawa.id dari UI
    String? filePath,
    String? token,
  }) async {
    try {
      debugPrint("=======================================================");
      debugPrint("🚀 MEMULAI PROSES KIRIM PENDAFTARAN");
      debugPrint("🔍 DETEKSI INPUT lokasiId DARI UI: '$lokasiId' (Type: ${lokasiId.runtimeType})");
      debugPrint("=======================================================");

      // 1. PARSING INPUT SECARA AGRESIF
      int parsedLokasiId = 1;

      if (lokasiId is int) {
        parsedLokasiId = lokasiId;
      } else if (lokasiId != null) {
        String cleanStr = lokasiId.toString().trim();
        int? directId = int.tryParse(cleanStr);
        if (directId != null) {
          parsedLokasiId = directId;
        } else {
          // Jika tidak sengaja berupa objek atau text kosong
          debugPrint("⚠️ WARNING: lokasiId berupa string non-angka ('$cleanStr'). Fallback ke ID 1.");
          parsedLokasiId = 1;
        }
      }

      // CEK PERINGATAN LOGIS
      if (parsedLokasiId == 1) {
        debugPrint("🚨 [ALERT DARI LOGIC]: ID yang diproses bernilai 1.");
        debugPrint("👉 Jika kamu merasa memilih Rusun selain ID 1 di UI, artinya variabel yang kamu kirim dari halaman Form UI masih tersangkut data default/belum terupdate!");
      } else {
        debugPrint("🎯 SINKRONISASI BERHASIL: ID Aman Terbaca -> $parsedLokasiId");
      }

      // 2. GENERATE TANGGAL & TIMESTAMP NAMA FILE DOKUMEN
      final DateTime sekarang = DateTime.now();
      final String tglDaftarHariIni =
          "${sekarang.year}-${sekarang.month.toString().padLeft(2, '0')}-${sekarang.day.toString().padLeft(2, '0')}";

      final int acak = Random().nextInt(9000) + 1000;
      final String waktuUnik = "${sekarang.hour}${sekarang.minute}${sekarang.second}_$acak";

      String ekstensi = ".pdf";
      if (filePath != null && filePath.contains('.')) {
        ekstensi = ".${filePath.split('.').last}";
      }

      // Gabungkan nama file dokumen pendukung secara otomatis
      String namaFileDinamis = "lokasi_${parsedLokasiId}_${tglDaftarHariIni.replaceAll('-', '')}_$waktuUnik$ekstensi";

      // 3. PROSES ENKRIPSI TOTAL DATA (Format s0:...)
      String namaTerenkripsi = _enkripsiData(namaLengkap.trim());
      String telpTerenkripsi = _enkripsiData(noTelp.trim());
      String telpHash = _buatHashSHA256(noTelp.trim());
      String suketTerenkripsi = _enkripsiData("suket/$namaFileDinamis");

      // Payload JSON disesuaikan agar Laravel menerima lokasi_id murni hasil pilihan
      final Map<String, dynamic> payload = {
        'nama': namaTerenkripsi,
        'telp_pendaftar': telpTerenkripsi,
        'telp_pendaftar_hash': telpHash,
        'suket': suketTerenkripsi,
        'lokasi_id': parsedLokasiId,
        'status_daftar': 1,
        'tgl_daftar': tglDaftarHariIni,
      };

      debugPrint("📡 JSON Payload Akhir yang OTW dikirim: ${jsonEncode(payload)}");

      // 4. KIRIM PAYLOAD KE BACKEND LARAVEL VIA HTTP POST
      final response = await http.post(
        Uri.parse(apiPendaftaranUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      debugPrint("📡 Server Response Status Code: ${response.statusCode}");
      debugPrint("📄 Response Body Raw dari Laravel: ${response.body}");

      if (response.body.isEmpty) return false;
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final statusSuccess = responseData['success'];
        if (statusSuccess == true || statusSuccess == 'true') {
          debugPrint("✅ Sukses besar! Data terkirim ke database.");
          return true;
        } else {
          debugPrint("⚠️ Backend menolak data: ${responseData['message']}");
          return false;
        }
      } else if (response.statusCode == 422) {
        debugPrint("❌ VALIDASI LARAVEL GAGAL!");
        if (responseData['errors'] != null) {
          final Map<String, dynamic> errors = responseData['errors'];
          errors.forEach((key, value) => debugPrint("👉 FIELD [ $key ] BERMASALAH: $value"));
        }
        return false;
      } else {
        debugPrint("❌ Gagal dengan status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Fatal Exception Jaringan/Parsing: $e");
      return false;
    }
  }
}