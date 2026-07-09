import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardLogic {
  final String baseUrl = "http://10.0.2.2:8000/api";

  String? authToken;
  VoidCallback? onUpdate;

  DashboardLogic({this.authToken, this.onUpdate});

  // State operasional
  bool isLoading = false;
  String adminName = "Admin";

  // Menyimpan daftar lokasi_id dari tabel pivot perkim_lokasi_user
  List<int> allowedLokasiIds = [];

  // Statistik Properti & Penghuni
  int totalPenghuni = 0;
  int totalUnit = 0;
  int unitTerisi = 0;
  int unitKosong = 0;
  int kontrakAkanHabis = 0;

  // Demografi Umur
  int jmlBalita = 0;
  int jmlAnak = 0;
  int jmlRemaja = 0;
  int jmlDewasa = 0;
  int jmlLansia = 0;

  // Antrean Wawancara
  int totalAntreanWawancancara = 0;
  int wawancaraTerlewatAlert = 0;
  int belumDiwawancara = 0;
  int wawancaraHariIni = 0;
  int wawancaraBesok = 0;
  int wawancaraMingguIni = 0;
  List<Map<String, dynamic>> daftarWawancara = [];

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
    String strValue = value.toString().trim();
    if (strValue.isEmpty || strValue.toLowerCase() == 'null') return null;
    return int.tryParse(strValue);
  }

  Future<void> fetchDashboardData({String? updatedToken}) async {
    if (updatedToken != null) {
      authToken = updatedToken;
    }

    isLoading = true;
    _notify();
    _resetStatistics();

    final Map<String, String> headers = _getHeaders(updatedToken);

    try {
      debugPrint("--- REFRESH DATA DASHBOARD SIRAJA (TAHUN 2026) ---");

      // =========================================================================
      // 1. AMBIL PROFIL USER & EKSTRAKSI RELASI PIVOT
      // =========================================================================
      // Ditambahkan timeout perlindungan 7 detik agar tidak gantung saat Laragon beku
      final resProfile = await http.get(Uri.parse('$baseUrl/me'), headers: headers)
          .timeout(const Duration(seconds: 7));

      // Jika token tidak valid / kedaluwarsa, lemparkan eror otentikasi
      if (resProfile.statusCode == 401) {
        throw 'Unauthenticated';
      }

      if (resProfile.statusCode == 200) {
        final dynamic profileBody = json.decode(resProfile.body);
        Map<String, dynamic>? userData;

        if (profileBody is Map<String, dynamic>) {
          userData = profileBody['data'] ?? profileBody['user'] ?? profileBody;
        }

        if (userData != null) {
          adminName = (userData['name'] ?? "Admin").toString();
          allowedLokasiIds.clear();

          var lokasiUserRaw = userData['lokasi_user'] ?? userData['perkim_lokasi_user'] ?? userData['lokasi_users'];

          if (lokasiUserRaw is List) {
            for (var item in lokasiUserRaw) {
              if (item is int) {
                if (!allowedLokasiIds.contains(item)) {
                  allowedLokasiIds.add(item);
                }
              } else if (item is Map) {
                int? idLoc = _safeParseInt(item['lokasi_id'] ?? item['id']);
                if (idLoc != null && !allowedLokasiIds.contains(idLoc)) {
                  allowedLokasiIds.add(idLoc);
                }
              }
            }
          } else if (lokasiUserRaw is Map) {
            int? idLoc = _safeParseInt(lokasiUserRaw['lokasi_id'] ?? lokasiUserRaw['id']);
            if (idLoc != null && !allowedLokasiIds.contains(idLoc)) {
              allowedLokasiIds.add(idLoc);
            }
          }

          if (allowedLokasiIds.isEmpty && userData['lokasi_id'] != null) {
            int? idLoc = _safeParseInt(userData['lokasi_id']);
            if (idLoc != null) allowedLokasiIds.add(idLoc);
          }

          debugPrint("🔒 Hak Akses Berhasil Dikunci Berdasarkan perkim_lokasi_user ID: $allowedLokasiIds");
        }
      } else {
        // Jika server mengembalikan status selain 200/401 (misal 500 / 502 HTML error)
        throw 'Server Error Profile Status: ${resProfile.statusCode}';
      }

      // =========================================================================
      // 2. AMBIL DATA PARALEL DARI API LARAVEL
      // =========================================================================
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/lokasi-hirarki'), headers: headers),
        http.get(Uri.parse('$baseUrl/pendaftar'), headers: headers),
      ].map((future) => future.timeout(const Duration(seconds: 7)))); // Terapkan perlindungan timeout ke semua request paralel

      // =========================================================================
      // 3. PARSING DATA HIRARKI LOKASI & KONTRAK
      // =========================================================================
      if (responses[0].statusCode == 200) {
        final Map<String, dynamic> body = json.decode(responses[0].body);
        _processLokasiHirarki(body['data'] ?? body);
      } else {
        throw 'Server Error Lokasi Status: ${responses[0].statusCode}';
      }

      // =========================================================================
      // 4. PARSING DATA ANTREAN WAWANCARA
      // =========================================================================
      if (responses[1].statusCode == 200) {
        final dynamic body = json.decode(responses[1].body);
        _processPendaftarWawancara(body['data'] ?? body);
      } else {
        throw 'Server Error Pendaftar Status: ${responses[1].statusCode}';
      }

    } catch (e) {
      debugPrint("❌ Fatal Exception Dashboard Logic caught: $e");
      // 🎯 FIX UTAMA: Melempar kembali (rethrow) error agar ditangkap blok try-catch di UI DashboardScreen
      rethrow;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  void _resetStatistics() {
    totalUnit = 0;
    unitTerisi = 0;
    unitKosong = 0;
    totalPenghuni = 0;
    kontrakAkanHabis = 0;
    jmlBalita = 0;
    jmlAnak = 0;
    jmlRemaja = 0;
    jmlDewasa = 0;
    jmlLansia = 0;
    totalAntreanWawancancara = 0;
    wawancaraTerlewatAlert = 0;
    belumDiwawancara = 0;
    wawancaraHariIni = 0;
    wawancaraBesok = 0;
    wawancaraMingguIni = 0;
    daftarWawancara = [];
  }

  void _processLokasiHirarki(dynamic lokasiUserList) {
    if (lokasiUserList == null) return;

    List<dynamic> rawList = [];
    if (lokasiUserList is List) {
      rawList = lokasiUserList;
    } else if (lokasiUserList is Map) {
      rawList = lokasiUserList['lokasi'] ?? [lokasiUserList];
    }

    final DateTime todayZeroHour = DateTime(2026, DateTime.now().month, DateTime.now().day);

    for (var item in rawList) {
      if (item == null) continue;

      var lokasi = (item['lokasi'] != null && item['lokasi'] is Map) ? item['lokasi'] : item;
      if (lokasi is! Map) continue;

      int? currentLokasiId = _safeParseInt(lokasi['id'] ?? item['lokasi_id']);

      if (allowedLokasiIds.isNotEmpty && currentLokasiId != null) {
        if (!allowedLokasiIds.contains(currentLokasiId)) {
          continue;
        }
      }

      var gedungList = lokasi['gedung'] ?? lokasi['gedungs'];
      if (gedungList == null || gedungList is! List) continue;

      for (var gedung in gedungList) {
        if (gedung == null || gedung is! Map) continue;

        var unitList = gedung['unit'] ?? gedung['units'];
        if (unitList == null || unitList is! List) continue;

        for (var unit in unitList) {
          if (unit == null || unit is! Map) continue;

          var kontraks = unit['kontrak'] ?? unit['kontraks'];
          dynamic activeContract;

          if (kontraks != null && kontraks is List) {
            for (var k in kontraks) {
              if (k == null || k is! Map) continue;

              var rawStatus = k['status_kontrak'];
              bool isActive = false;

              if (rawStatus is int) {
                isActive = (rawStatus == 1);
              } else if (rawStatus is bool) {
                isActive = rawStatus;
              } else if (rawStatus != null) {
                String strStatus = rawStatus.toString().trim().toLowerCase();
                isActive = (strStatus == '1' || strStatus == 'true');
              }

              if (isActive) {
                activeContract = k;
                break;
              }
            }
          }

          if (activeContract != null) {
            unitTerisi++;

            if (activeContract['tgl_akhir'] != null) {
              try {
                String tglEnding = activeContract['tgl_akhir'].toString().split(' ')[0];
                DateTime tglAkhir = DateTime.parse(tglEnding);
                int sisaHari = tglAkhir.difference(todayZeroHour).inDays;
                if (sisaHari >= 0 && sisaHari <= 7) {
                  kontrakAkanHabis++;
                }
              } catch (_) {}
            }

            for (int i = 1; i <= 4; i++) {
              var penghuniData = activeContract['penghuni_id$i'] ?? activeContract['penghuni$i'];
              if (penghuniData != null) {
                _checkAndParsePenghuni(penghuniData);
              }
            }

            var listPenghuniDirect = activeContract['penghuni'] ?? activeContract['penghunis'];
            if (listPenghuniDirect != null) {
              _checkAndParsePenghuni(listPenghuniDirect);
            }

          } else {
            unitKosong++;
          }
          totalUnit++;
        }
      }
    }
  }

  void _checkAndParsePenghuni(dynamic pData) {
    if (pData == null) return;
    if (pData is List) {
      for (var item in pData) {
        _parsePenghuniUmur(item);
      }
    } else if (pData is Map) {
      _parsePenghuniUmur(pData);
    }
  }

  void _parsePenghuniUmur(dynamic p) {
    if (p == null || p is! Map || p['tgl_lahir'] == null) return;

    totalPenghuni++;
    try {
      String tglLahirRaw = p['tgl_lahir'].toString().split(' ')[0];
      DateTime tglLahir = DateTime.parse(tglLahirRaw);

      int tahunSekarang = 2026;
      int umur = tahunSekarang - tglLahir.year;

      DateTime now2026 = DateTime(2026, DateTime.now().month, DateTime.now().day);
      if (now2026.month < tglLahir.month || (now2026.month == tglLahir.month && now2026.day < tglLahir.day)) {
        umur--;
      }

      if (umur <= 5) {
        jmlBalita++;
      } else if (umur <= 11) {
        jmlAnak++;
      } else if (umur <= 25) {
        jmlRemaja++;
      } else if (umur <= 45) {
        jmlDewasa++;
      } else {
        jmlLansia++;
      }
    } catch (e) {
      debugPrint("Gagal memproses kalkulasi umur: $e");
    }
  }

  void _processPendaftarWawancara(dynamic pendaftarList) {
    if (pendaftarList == null || pendaftarList is! List) return;

    final DateTime now = DateTime.now();
    final DateTime targetHariIni = DateTime(2026, now.month, now.day);

    List<Map<String, dynamic>> tempOverdue = [];
    List<Map<String, dynamic>> tempHariIni = [];
    List<Map<String, dynamic>> tempBesok = [];
    List<Map<String, dynamic>> tempMasaDepan = [];

    for (var p in pendaftarList) {
      if (p == null || p is! Map) continue;

      if (allowedLokasiIds.isNotEmpty) {
        dynamic lokasiRaw = p['lokasi'];
        int? pendaftarLocationsId = _safeParseInt(p['lokasi_id'] ?? (lokasiRaw is Map ? lokasiRaw['id'] : null));

        if (pendaftarLocationsId != null && !allowedLokasiIds.contains(pendaftarLocationsId)) {
          continue;
        }
      }

      var fieldTanggal = p['tgl_wawancara'] ?? p['tanggal_wawancara'];

      dynamic lokasiObj = p['lokasi'];
      String namaLokasiTujuan = "Rusun Perkim";
      if (lokasiObj is Map && lokasiObj['nama_lokasi'] != null) {
        namaLokasiTujuan = lokasiObj['nama_lokasi'].toString();
      } else if (lokasiObj is String && lokasiObj.isNotEmpty) {
        namaLokasiTujuan = lokasiObj;
      }

      if (fieldTanggal != null && fieldTanggal.toString().trim().isNotEmpty) {
        try {
          String tglRaw = fieldTanggal.toString().trim().split(' ')[0];
          DateTime tglWawancara = DateTime.parse(tglRaw);
          DateTime tglWawancaraMurni = DateTime(tglWawancara.year, tglWawancara.month, tglWawancara.day);

          int selisihHari = tglWawancaraMurni.difference(targetHariIni).inDays;
          bool isOverdue = false;
          String labelTanggal = tglRaw;

          if (selisihHari >= 0 && selisihHari <= 7) {
            wawancaraMingguIni++;
          }

          if (selisihHari == 0) {
            wawancaraHariIni++;
            labelTanggal = "Hari ini";
            totalAntreanWawancancara++;
            belumDiwawancara++;
          } else if (selisihHari == 1) {
            wawancaraBesok++;
            labelTanggal = "Besok";
            totalAntreanWawancancara++;
            belumDiwawancara++;
          } else if (selisihHari < 0) {
            wawancaraTerlewatAlert++;
            isOverdue = true;
            labelTanggal = "Terlewat (${-selisihHari} hari)";
          } else {
            labelTanggal = "$selisihHari hari lagi";
            totalAntreanWawancancara++;
            belumDiwawancara++;
          }

          var itemWawancara = {
            "nama": p['nama'] ?? "Tanpa Nama",
            "tgl_wawancara": labelTanggal,
            "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
            "lokasi_tujuan": namaLokasiTujuan,
            "is_overdue": isOverdue,
          };

          if (isOverdue) {
            tempOverdue.add(itemWawancara);
          } else if (selisihHari == 0) {
            tempHariIni.add(itemWawancara);
          } else if (selisihHari == 1) {
            tempBesok.add(itemWawancara);
          } else {
            tempMasaDepan.add(itemWawancara);
          }

        } catch (e) {
          tempMasaDepan.add({
            "nama": p['nama'] ?? "Tanpa Nama",
            "tgl_wawancara": "Format Salah",
            "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
            "lokasi_tujuan": namaLokasiTujuan,
            "is_overdue": false,
          });
        }
      } else {
        tempMasaDepan.add({
          "nama": p['nama'] ?? "Tanpa Nama",
          "tgl_wawancara": "Belum Terjadwal",
          "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
          "lokasi_tujuan": namaLokasiTujuan,
          "is_overdue": false,
        });
      }
    }

    List<Map<String, dynamic>> urutanSinkron = [
      ...tempOverdue,
      ...tempHariIni,
      ...tempBesok,
      ...tempMasaDepan
    ];

    daftarWawancara = urutanSinkron.take(3).toList();
  }

  void _notify() => onUpdate?.call();
}