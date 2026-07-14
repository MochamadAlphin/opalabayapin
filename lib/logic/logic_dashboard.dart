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

  // Statistik Properti & Penghuni Akumulatif (Global)
  int totalPenghuni = 0;
  int totalUnit = 0;
  int unitTerisi = 0;
  int unitKosong = 0;
  int kontrakAkanHabis = 0;

  // Tempat menyimpan hasil rincian breakdown data per ruko/rusunawa khusus Pimpinan
  List<Map<String, dynamic>> statistikPerLokasi = [];

  // Demografi Umur Penghuni
  int jmlBalita = 0;
  int jmlAnak = 0;
  int jmlRemaja = 0;
  int jmlDewasa = 0;
  int jmlLansia = 0;

  // Ringkasan Jadwal Antrean Wawancara Calon Penghuni
  int totalAntreanWawancancara = 0;
  int wawancaraTerlewatAlert = 0;
  int belumDiwawancara = 0;
  int wawancaraHariIni = 0;
  int wawancaraBesok = 0;
  int wawancaraMingguIni = 0;

  // 🎯 Menyimpan seluruh daftar wawancara murni hasil fetch API untuk proses filter di UI
  List<Map<String, dynamic>> semuaDaftarWawancaraMurni = [];

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

  /// 🎯 Fungsi baru untuk mengambil list wawancara yang telah difilter berdasarkan lokasi dari UI
  List<Map<String, dynamic>> getFilteredWawancara(int? selectedLokasiId) {
    if (selectedLokasiId == null) {
      return semuaDaftarWawancaraMurni;
    }
    return semuaDaftarWawancaraMurni
        .where((wawancara) => wawancara['lokasi_id'] == selectedLokasiId)
        .toList();
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
      debugPrint("--- REFRESH DATA DASHBOARD PERKIM ---");

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

          // Deteksi apakah user login bermode pimpinan
          String roleUser = (userData['role'] ?? '').toString().toLowerCase();
          isPimpinan = (roleUser == 'pimpinan');

          allowedLokasiIds.clear();

          // Jika petugas biasa, filter lokasi aktif dimuat. Jika pimpinan, load seluruh lokasi
          if (!isPimpinan && userData['lokasi_id'] != null) {
            int? idLoc = _safeParseInt(userData['lokasi_id']);
            if (idLoc != null) {
              allowedLokasiIds.add(idLoc);
            }
          }

          debugPrint("🔒 Hak Akses Terbuka: ${isPimpinan ? 'Pimpinan (Semua Lokasi Terbuka)' : 'Petugas Terbatas ($allowedLokasiIds)'}");
        }
      } else {
        throw 'Server Error Profile Status: ${resProfile.statusCode}';
      }

      // =========================================================================
      // 2. PARALEL REQUEST DATA HIRARKI DAN PENDAFTAR
      // =========================================================================
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/lokasi-hirarki'), headers: headers),
        http.get(Uri.parse('$baseUrl/pendaftar'), headers: headers),
      ].map((future) => future.timeout(const Duration(seconds: 7))));

      // =========================================================================
      // 3. PARSING UNIT, GEDUNG, DAN PENGHUNI KONTRAK
      // =========================================================================
      if (responses[0].statusCode == 200) {
        final Map<String, dynamic> body = json.decode(responses[0].body);
        _processLokasiHirarki(body['data'] ?? body);
      } else {
        throw 'Server Error Lokasi Status: ${responses[0].statusCode}';
      }

      // =========================================================================
      // 4. PARSING ANTREAN WAWANCARA
      // =========================================================================
      if (responses[1].statusCode == 200) {
        final dynamic body = json.decode(responses[1].body);
        _processPendaftarWawancara(body['data'] ?? body);
      } else {
        throw 'Server Error Pendaftar Status: ${responses[1].statusCode}';
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
    totalUnit = 0;
    unitTerisi = 0;
    unitKosong = 0;
    totalPenghuni = 0;
    kontrakAkanHabis = 0;
    statistikPerLokasi = [];
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
    semuaDaftarWawancaraMurni = []; // Reset penampung data wawancara
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
      if (item == null || item is! Map) continue;

      var lokasi = item['lokasi'];
      if (lokasi == null || lokasi is! Map) continue;

      int? currentLokasiId = _safeParseInt(lokasi['id']);

      // Jika bukan pimpinan, lakukan pembatasan filter lokasi_id
      if (!isPimpinan && allowedLokasiIds.isNotEmpty && currentLokasiId != null) {
        if (!allowedLokasiIds.contains(currentLokasiId)) {
          continue;
        }
      }

      String namaLokasi = lokasi['nama_lokasi'] ?? 'Rusunawa';
      int unitTerisiLokasi = 0;
      int unitKosongLokasi = 0;
      int totalUnitLokasi = 0;
      int penghuniLokasi = 0;

      var gedungList = lokasi['gedung'] ?? lokasi['gedungs'];
      if (gedungList != null && gedungList is List) {
        for (var gedung in gedungList) {
          if (gedung == null || gedung is! Map) continue;

          var unitList = gedung['unit'] ?? gedung['units'];
          if (unitList == null || unitList is! List) continue;

          for (var unit in unitList) {
            if (unit == null || unit is! Map) continue;

            bool isUnitTerisi = false;
            if (unit['is_terisi'] != null) {
              var rawIsTerisi = unit['is_terisi'];
              isUnitTerisi = (rawIsTerisi == 1 || rawIsTerisi == true || rawIsTerisi.toString() == '1');
            }

            var kontraks = unit['kontrak'] ?? unit['kontraks'];
            dynamic activeContract;

            if (kontraks != null && kontraks is List) {
              for (var k in kontraks) {
                if (k == null || k is! Map) continue;
                var rawStatus = k['status_kontrak'];
                if (rawStatus == 1 || rawStatus == true || rawStatus.toString() == '1') {
                  activeContract = k;
                  break;
                }
              }
            }

            if (isUnitTerisi || activeContract != null) {
              unitTerisi++;
              unitTerisiLokasi++;

              if (activeContract != null && activeContract['tgl_akhir'] != null) {
                try {
                  String tglEnding = activeContract['tgl_akhir'].toString().split(' ')[0];
                  DateTime tglAkhir = DateTime.parse(tglEnding);
                  int sisaHari = tglAkhir.difference(todayZeroHour).inDays;
                  if (sisaHari >= 0 && sisaHari <= 7) {
                    kontrakAkanHabis++;
                  }
                } catch (_) {}
              }

              if (activeContract != null) {
                List<String> penghuniKeys = ['penghuni_satu', 'penghuni_dua', 'penghuni_tiga', 'penghuni_empat', 'penghuni_id1'];
                for (var key in penghuniKeys) {
                  if (activeContract[key] != null) {
                    _checkAndParsePenghuni(activeContract[key]);
                    penghuniLokasi++;
                  }
                }

                var listPenghuniDirect = activeContract['penghuni'] ?? activeContract['penghunis'];
                if (listPenghuniDirect != null) {
                  _checkAndParsePenghuni(listPenghuniDirect);
                  if (listPenghuniDirect is List) {
                    penghuniLokasi += listPenghuniDirect.length;
                  } else {
                    penghuniLokasi++;
                  }
                }
              }
            } else {
              unitKosong++;
              unitKosongLokasi++;
            }
            totalUnit++;
            totalUnitLokasi++;
          }
        }
      }

      // Menyimpan data statistik internal per lokasi tunggal
      statistikPerLokasi.add({
        "id": currentLokasiId,
        "nama_lokasi": namaLokasi,
        "total_unit": totalUnitLokasi,
        "unit_terisi": unitTerisiLokasi,
        "unit_kosong": unitKosongLokasi,
        "total_penghuni": penghuniLokasi,
      });
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
      debugPrint("Gagal parse umur penghuni: $e");
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

      dynamic lokasiRaw = p['lokasi'];
      int? pendaftarLocationsId = _safeParseInt(p['lokasi_id'] ?? (lokasiRaw is Map ? lokasiRaw['id'] : null));

      if (!isPimpinan && allowedLokasiIds.isNotEmpty) {
        if (pendaftarLocationsId != null && !allowedLokasiIds.contains(pendaftarLocationsId)) {
          continue;
        }
      }

      var fieldTanggal = p['tgl_wawancara'] ?? p['tanggal_wawancara'];

      String namaLokasiTujuan = "Rusunawa";
      if (lokasiRaw is Map && lokasiRaw['nama_lokasi'] != null) {
        namaLokasiTujuan = lokasiRaw['nama_lokasi'].toString();
      } else if (lokasiRaw is String && lokasiRaw.isNotEmpty) {
        namaLokasiTujuan = lokasiRaw;
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
            "lokasi_id": pendaftarLocationsId, // 🎯 Disimpan untuk filtering di UI
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
            "lokasi_id": pendaftarLocationsId,
            "is_overdue": false,
          });
        }
      } else {
        tempMasaDepan.add({
          "nama": p['nama'] ?? "Tanpa Nama",
          "tgl_wawancara": "Belum Terjadwal",
          "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
          "lokasi_tujuan": namaLokasiTujuan,
          "lokasi_id": pendaftarLocationsId,
          "is_overdue": false,
        });
      }
    }

    // Menggabungkan urutan data secara sinkron
    semuaDaftarWawancaraMurni = [
      ...tempOverdue,
      ...tempHariIni,
      ...tempBesok,
      ...tempMasaDepan
    ];
  }

  void _notify() => onUpdate?.call();
}