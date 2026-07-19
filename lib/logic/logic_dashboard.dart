import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardLogic {
  final String baseUrl = "http://10.0.2.2:8000/api";

  String? authToken;
  VoidCallback? onUpdate;

  DashboardLogic({this.authToken, this.onUpdate});

  // State operasional utama
  bool isLoading = false;
  String adminName = "Admin";
  bool isPimpinan = false; // Flag penanda role pimpinan

  // Menyimpan daftar lokasi_id dari hak akses user biasa
  List<int> allowedLokasiIds = [];
  int? _myLokasiId;

  // =========================================================================
  // RINGKASAN GLOBAL — Diambil dari objek 'summary' API /unit
  // =========================================================================
  int totalGedung = 0;
  int totalUnit = 0;
  int unitTerisi = 0;
  int unitKosong = 0;      // Dihitung secara dinamis dari summary /unit agar kompatibel dengan UI
  int unitPerbaikan = 0;
  int unitTersedia = 0;
  double okupansi = 0;
  double occupancy = 0.0; // Sinkronisasi penamaan variabel lama agar UI tetap aman

  // =========================================================================
  // RINCIAN PER LOKASI — Menampilkan breakdown per lokasi (TANPA GEDUNG)
  // =========================================================================
  List<Map<String, dynamic>> statistikPerLokasi = [];

  // Demografi Umur Penghuni & Variabel Kontrak Lama (Dipertahankan untuk mencegah error di UI)
  int totalPenghuni = 0;
  int kontrakAkanHabis = 0;
  int jmlBalita = 0;
  int jmlAnak = 0;
  int jmlRemaja = 0;
  int jmlDewasa = 0;
  int jmlLansia = 0;
  int jmlManula = 0;

  // Ringkasan Jadwal Antrean Wawancara Calon Penghuni (Dipertahankan dari kode lama)
  int totalAntreanWawancancara = 0;
  int wawancaraTerlewatAlert = 0;
  int belumDiwawancara = 0;
  int wawancaraHariIni = 0;
  int wawancaraBesok = 0;
  int wawancaraMingguIni = 0;
  List<Map<String, dynamic>> semuaDaftarWawancaraMurni = [];

  // Metadata Pagination untuk Wawancara Terlewat
  int currentPageWawancara = 1;
  int lastPageWawancara = 1;
  int totalWawancara = 0;
  int perPageWawancara = 5;

  Map<String, String> _getHeaders(String? explicitToken) {
    final tokenToUse = explicitToken ?? authToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (tokenToUse != null && tokenToUse.isNotEmpty) 'Authorization': 'Bearer $tokenToUse',
    };
  }

  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final strValue = value.toString().trim();
    if (strValue.isEmpty || strValue.toLowerCase() == 'null') return null;
    return int.tryParse(strValue);
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, dynamic>> getFilteredWawancara(int? selectedLokasiId) {
    if (selectedLokasiId == null) {
      return semuaDaftarWawancaraMurni;
    }
    return semuaDaftarWawancaraMurni
        .where((wawancara) => wawancara['lokasi_id'] == selectedLokasiId)
        .toList();
  }

  Future<void> fetchDashboardData({String? updatedToken, int page = 1, int? lokasiId}) async {
    if (updatedToken != null) {
      authToken = updatedToken;
    }
    currentPageWawancara = page;

    isLoading = true;
    _notify();
    
    // Reset data selain pagination agar UI tidak flickering parah jika diperlukan, 
    // tapi biasanya data ringkasan tetap dipertahankan.
    if (page == 1) _resetStatistics();

    final Map<String, String> headers = _getHeaders(updatedToken);

    try {
      debugPrint("--- REFRESH DATA DASHBOARD PERKIM (Page: $page) ---");

      // =========================================================================
      // 1. CEK IDENTITAS USER DAN VALIDASI ROLE
      // =========================================================================
      final resProfile = await http.get(Uri.parse('$baseUrl/me'), headers: headers)
          .timeout(const Duration(seconds: 7));

      if (resProfile.statusCode == 401) {
        throw 'Unauthenticated';
      }

      if (resProfile.statusCode == 200) {
        final dynamic profileBody = json.decode(resProfile.body);
        Map<String, dynamic>? userData;

        if (profileBody is Map<String, dynamic>) {
          userData = profileBody['data'];
        }

        if (userData != null) {
          adminName = (userData['name'] ?? "Admin").toString();

          final roleUser = (userData['role'] ?? '').toString().toLowerCase();
          isPimpinan = (roleUser == 'pimpinan');

          _myLokasiId = _safeParseInt(userData['lokasi_id']);
          allowedLokasiIds.clear();
          if (_myLokasiId != null) {
            allowedLokasiIds.add(_myLokasiId!);
          }

          debugPrint("🔒 Hak Akses: ${isPimpinan ? 'Pimpinan (Semua Lokasi)' : 'Petugas (lokasi_id=$_myLokasiId)'}");
        }
      } else {
        throw 'Server Error Profile Status: ${resProfile.statusCode}';
      }

      // =========================================================================
      // 2. AMBIL DATA DARI ENDPOINT /unit, /pendaftar/wawancara-terlewat, DAN /penghuni SECARA PARALEL
      // =========================================================================
      String urlUnit = '$baseUrl/unit';
      if (!isPimpinan && _myLokasiId != null) {
        urlUnit += '?lokasi_id=$_myLokasiId';
      }

      // Hit endpoint pendaftar/wawancara-terlewat dengan pagination
      String urlWawancara = '$baseUrl/pendaftar/wawancara-terlewat?per_page=$perPageWawancara&page=$page';
      
      // Filter lokasi: Jika Pimpinan kirim lokasiId dari UI, jika Petugas kirim _myLokasiId
      int? filterLokasiId = isPimpinan ? lokasiId : _myLokasiId;
      if (filterLokasiId != null) {
        urlWawancara += '&lokasi_id=$filterLokasiId';
      }

      final responses = await Future.wait([
        http.get(Uri.parse(urlUnit), headers: headers),
        http.get(Uri.parse(urlWawancara), headers: headers),
        http.get(Uri.parse('$baseUrl/penghuni/statistik-demografi'), headers: headers),
      ].map((future) => future.timeout(const Duration(seconds: 7))));

      // Parsing Response GET /unit
      if (responses[0].statusCode == 200) {
        final Map<String, dynamic> body = json.decode(responses[0].body);
        _processUnitData(body);
      } else {
        throw 'Server Error Unit Status: ${responses[0].statusCode}';
      }

      // Parsing Response GET /pendaftar/wawancara-terlewat
      if (responses[1].statusCode == 200) {
        final dynamic body = json.decode(responses[1].body);
        _processPendaftarWawancaraTerlewat(body);
      } else {
        throw 'Server Error Wawancara Status: ${responses[1].statusCode}';
      }

      // Parsing Response GET /penghuni/statistik-demografi
      if (responses[2].statusCode == 200) {
        final dynamic body = json.decode(responses[2].body);
        _processDemografiData(body);
      } else {
        debugPrint('⚠️ Server Error Demografi Status: ${responses[2].statusCode}');
      }

    } catch (e) {
      debugPrint("❌ Exception Dashboard Logic: $e");
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void _resetStatistics() {
    totalGedung = 0;
    totalUnit = 0;
    unitTerisi = 0;
    unitKosong = 0;
    unitPerbaikan = 0;
    unitTersedia = 0;
    okupansi = 0;
    occupancy = 0.0;
    statistikPerLokasi = [];

    totalPenghuni = 0;
    kontrakAkanHabis = 0;
    jmlBalita = 0;
    jmlAnak = 0;
    jmlRemaja = 0;
    jmlDewasa = 0;
    jmlLansia = 0;
    jmlManula = 0;

    totalAntreanWawancancara = 0;
    wawancaraTerlewatAlert = 0;
    belumDiwawancara = 0;
    wawancaraHariIni = 0;
    wawancaraBesok = 0;
    wawancaraMingguIni = 0;
    semuaDaftarWawancaraMurni = [];
  }

  // =========================================================================
  // 🎯 PARSING DATA UNIT DARI ENDPOINT /unit 
  // =========================================================================
  void _processUnitData(Map<String, dynamic> body) {
    final bool success = body['success'] == true;
    if (!success) {
      debugPrint("⚠️ Response /unit success=false: ${body['message']}");
      return;
    }

    final Map<String, dynamic>? summary = body['summary'];
    if (summary != null) {
      totalGedung = _safeParseInt(summary['total_gedung']) ?? 0;
      totalUnit = _safeParseInt(summary['total_unit']) ?? 0;
      unitTerisi = _safeParseInt(summary['total_unit_terisi']) ?? 0;
      unitPerbaikan = _safeParseInt(summary['total_unit_perbaikan']) ?? 0;
      unitTersedia = _safeParseInt(summary['unit tersedia'] ?? summary['unit_tersedia']) ?? 0;
      okupansi = _safeParseDouble(summary['okupansi']);
      occupancy = okupansi;

      // Perhitungan dinamis unit kosong untuk keperluan UI lama Anda
      unitKosong = totalUnit - unitTerisi - unitPerbaikan;
    }

    final List<dynamic>? data = body['data'];
    if (data != null) {
      statistikPerLokasi = data.map<Map<String, dynamic>>((item) {
        final Map<String, dynamic> m = item as Map<String, dynamic>;

        int itemTotalUnit = _safeParseInt(m['total_unit']) ?? 0;
        int itemUnitTerisi = _safeParseInt(m['total_unit_terisi']) ?? 0;
        int itemUnitPerbaikan = _safeParseInt(m['total_unit_perbaikan']) ?? 0;

        return {
          "id": _safeParseInt(m['id_lokasi']),
          "nama_lokasi": (m['nama_lokasi'] ?? 'Tanpa Lokasi').toString(),
          "total_gedung": _safeParseInt(m['total_gedung']) ?? 0,
          "total_unit": itemTotalUnit,
          "unit_terisi": itemUnitTerisi,
          "unit_kosong": itemTotalUnit - itemUnitTerisi - itemUnitPerbaikan,
          "unit_perbaikan": itemUnitPerbaikan,
          "unit_tersedia": _safeParseInt(m['unit_tersedia']) ?? 0,
          "okupansi": _safeParseDouble(m['okupansi']),
        };
      }).toList();
    }
  }

  // =========================================================================
  // 🎯 PARSING ANTREAN WAWANCARA TERLEWAT (Endpoint Baru dengan Pagination)
  // =========================================================================
  void _processPendaftarWawancaraTerlewat(dynamic responseBody) {
    if (responseBody == null || responseBody['success'] != true) return;

    final List<dynamic> data = responseBody['data'] ?? [];
    final Map<String, dynamic>? meta = responseBody['meta'];

    if (meta != null) {
      currentPageWawancara = _safeParseInt(meta['current_page']) ?? 1;
      lastPageWawancara = _safeParseInt(meta['last_page']) ?? 1;
      totalWawancara = _safeParseInt(meta['total']) ?? 0;
      perPageWawancara = _safeParseInt(meta['per_page']) ?? 5;
    }

    semuaDaftarWawancaraMurni = data.map<Map<String, dynamic>>((item) {
      return {
        "id": item['id'],
        "nama": item['nama'] ?? "Tanpa Nama",
        "tgl_wawancara": item['tgl_wawancara'] ?? "Belum Terjadwal",
        "lokasi_tujuan": item['nama_lokasi'] ?? "Rusunawa",
        "hari_terlewat": item['hari_terlewat'] ?? 0,
        "is_overdue": true,
      };
    }).toList();
    
    // Sinkronisasi variabel lama agar UI tidak error jika menggunakannya
    totalAntreanWawancancara = totalWawancara;
    wawancaraTerlewatAlert = totalWawancara;
  }

  // =========================================================================
  // 🎯 PARSING DEMOGRAFI PENGHUNI
  // =========================================================================
  void _processDemografiData(Map<String, dynamic> body) {
    if (body['success'] != true) return;
    final Map<String, dynamic>? data = body['data'];
    if (data != null) {
      totalPenghuni = _safeParseInt(data['total_penghuni']) ?? 0;
      jmlBalita = _safeParseInt(data['jml_balita']) ?? 0;
      jmlAnak = _safeParseInt(data['jml_anak']) ?? 0;
      jmlRemaja = _safeParseInt(data['jml_remaja']) ?? 0;
      jmlDewasa = _safeParseInt(data['jml_dewasa']) ?? 0;
      jmlLansia = _safeParseInt(data['jml_lansia']) ?? 0;
      jmlManula = _safeParseInt(data['jml_manula']) ?? 0;
    }
  }

  void _notify() => onUpdate?.call();
}