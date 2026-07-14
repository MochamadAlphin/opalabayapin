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

  // 🎯 Variabel global penampung Unit Perbaikan (status_jual == 0 atau 'perbaikan')
  int unitPerbaikan = 0;

  // Tempat menyimpan hasil rincian breakdown data per ruko/rusunawa khusus Pimpinan
  List<Map<String, dynamic>> statistikPerLokasi = [];

  // Demografi Umur Penghuni (Kategori Lansia & Manula Terpisah secara Presisi)
  int jmlBalita = 0;
  int jmlAnak = 0;
  int jmlRemaja = 0;
  int jmlDewasa = 0;
  int jmlLansia = 0;  // Lansia (46 - 59 tahun)
  int jmlManula = 0;  // Manula (>= 60 tahun)

  // Ringkasan Jadwal Antrean Wawancara Calon Penghuni
  int totalAntreanWawancancara = 0;
  int wawancaraTerlewatAlert = 0;
  int belumDiwawancara = 0;
  int wawancaraHariIni = 0;
  int wawancaraBesok = 0;
  int wawancaraMingguIni = 0;

  // Menyimpan seluruh daftar wawancara murni hasil fetch API untuk proses filter di UI
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
    unitPerbaikan = 0; // Reset unit perbaikan
    totalPenghuni = 0;
    kontrakAkanHabis = 0;
    statistikPerLokasi = [];
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

      if (!isPimpinan && allowedLokasiIds.isNotEmpty && currentLokasiId != null) {
        if (!allowedLokasiIds.contains(currentLokasiId)) {
          continue;
        }
      }

      String namaLokasi = lokasi['nama_lokasi'] ?? 'Rusunawa';
      int unitTerisiLokasi = 0;
      int unitKosongLokasi = 0;
      int unitPerbaikanLokasi = 0; // Penampung lokal per lokasi
      int totalUnitLokasi = 0;
      int penghuniLokasi = 0;

      // Sinkron dengan LocationController@index (backend) yang mengirim key 'gedung' & 'unit'
      // (singular). Fallback 'gedungs' / 'units' tetap dipertahankan untuk kompatibilitas
      // ke belakang seandainya backend suatu saat berubah balik memakai nama relasi Eloquent.
      var staticGedungs = lokasi['gedung'] ?? lokasi['gedungs'];
      var gedungList = staticGedungs;
      if (gedungList != null && gedungList is List) {
        for (var gedung in gedungList) {
          if (gedung == null || gedung is! Map) continue;

          var unitList = gedung['unit'] ?? gedung['units'];
          if (unitList == null || unitList is! List) continue;

          for (var unit in unitList) {
            if (unit == null || unit is! Map) continue;

            // 🎯 PERBAIKAN EVALUASI: Deteksi status_jual secara aman (bisa int, String, atau boolean)
            // Backend (LocationController@index) mengirim nilai kolom `status_jual` APA ADANYA
            // dari database (varchar '0' / '1'), jadi jalur `else` (String) di bawah ini yang
            // akan selalu dipakai untuk kasus normal — tapi int/bool tetap dijaga untuk jaga-jaga.
            var statusJualRaw = unit['status_jual'];
            bool isPerbaikan = false;

            if (statusJualRaw != null) {
              if (statusJualRaw is int && statusJualRaw == 0) {
                isPerbaikan = true;
              } else if (statusJualRaw is bool && statusJualRaw == false) {
                isPerbaikan = true;
              } else {
                String statusStr = statusJualRaw.toString().trim().toLowerCase();
                if (statusStr == '0' || statusStr == 'perbaikan' || statusStr == 'false') {
                  isPerbaikan = true;
                }
              }
            }

            if (isPerbaikan) {
              unitPerbaikan++;
              unitPerbaikanLokasi++;
            } else {
              // Jika status_jual bernilai selain perbaikan (aktif/tersedia), hitung status unit seperti biasa (terisi / kosong)
              bool isUnitTerisi = false;
              if (unit['is_terisi'] != null) {
                var rawIsTerisi = unit['is_terisi'];
                isUnitTerisi = (rawIsTerisi == 1 ||
                    rawIsTerisi == true ||
                    rawIsTerisi.toString().trim().toLowerCase() == '1' ||
                    rawIsTerisi.toString().trim().toLowerCase() == 'true');
              }

              var kontraks = unit['kontrak'] ?? unit['kontraks'];
              dynamic activeContract;

              if (kontraks != null && kontraks is List) {
                for (var k in kontraks) {
                  if (k == null || k is! Map) continue;
                  var rawStatus = k['status_kontrak'];
                  if (rawStatus == 1 ||
                      rawStatus == true ||
                      rawStatus.toString().trim() == '1') {
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
            }

            // Tetap dihitung ke dalam total unit agar data sinkron di grafik/UI
            totalUnit++;
            totalUnitLokasi++;
          }
        }
      }

      // Menyimpan data statistik internal per lokasi tunggal (termasuk unit_perbaikan)
      statistikPerLokasi.add({
        "id": currentLokasiId,
        "nama_lokasi": namaLokasi,
        "total_unit": totalUnitLokasi,
        "unit_terisi": unitTerisiLokasi,
        "unit_kosong": unitKosongLokasi,
        "unit_perbaikan": unitPerbaikanLokasi, // Ditambahkan ke breakdown lokasi pimpinan
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

      DateTime target2026 = DateTime(2026, DateTime.now().month, DateTime.now().day);

      // Hitung perbedaan tahun dasar
      int umur = target2026.year - tglLahir.year;

      // Evaluasi apakah tanggal lahir hari ini di tahun 2026 sudah terlewati atau belum
      if (target2026.month < tglLahir.month ||
          (target2026.month == tglLahir.month && target2026.day < tglLahir.day)) {
        umur--;
      }

      // Penentuan Kategori Umur Presisi (Termasuk batas ketat usia Balita/Anak di umur 5 tahun)
      if (umur < 5) {
        jmlBalita++;
      } else if (umur == 5) {
        // Cek secara presisi apakah hari ini sudah melewati hari ulang tahun ke-5 atau belum
        DateTime tglUltahKe5 = DateTime(tglLahir.year + 5, tglLahir.month, tglLahir.day);
        if (target2026.isAfter(tglUltahKe5)) {
          jmlAnak++; // Lebih dari 5 tahun (walau 1 hari) masuk kategori Anak
        } else {
          jmlBalita++; // Tepat umur 5 tahun ke bawah masuk Balita
        }
      } else if (umur <= 11) {
        jmlAnak++;
      } else if (umur <= 25) {
        jmlRemaja++;
      } else if (umur <= 45) {
        jmlDewasa++;
      } else if (umur <= 59) {
        jmlLansia++;
      } else {
        jmlManula++; // >= 60 Tahun (Manula)
      }
    } catch (e) {
      debugPrint("Gagal parse umur penghuni: $e");
    }
  }

  void _processPendaftarWawancara(dynamic pendaftarList) {
    if (pendaftarList == null || pendaftarList is! List) return;

    final DateTime now = DateTime.now();
    final DateTime targetHariIni = DateTime(2026, now.month, now.day);

    List<Map<String, dynamic>> listWawancaraDiproses = [];

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

          listWawancaraDiproses.add({
            "nama": p['nama'] ?? "Tanpa Nama",
            "tgl_wawancara": labelTanggal,
            "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
            "lokasi_tujuan": namaLokasiTujuan,
            "lokasi_id": pendaftarLocationsId,
            "is_overdue": isOverdue,
            "tgl_datetime": tglWawancaraMurni,
            "selisih_hari": selisihHari,
          });

        } catch (e) {
          listWawancaraDiproses.add({
            "nama": p['nama'] ?? "Tanpa Nama",
            "tgl_wawancara": "Format Salah",
            "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
            "lokasi_tujuan": namaLokasiTujuan,
            "lokasi_id": pendaftarLocationsId,
            "is_overdue": false,
            "tgl_datetime": DateTime(2099, 12, 31),
            "selisih_hari": 9999,
          });
        }
      } else {
        listWawancaraDiproses.add({
          "nama": p['nama'] ?? "Tanpa Nama",
          "tgl_wawancara": "Belum Terjadwal",
          "jam": p['jam_wawancara'] ?? p['jam'] ?? "--:-- WIB",
          "lokasi_tujuan": namaLokasiTujuan,
          "lokasi_id": pendaftarLocationsId,
          "is_overdue": false,
          "tgl_datetime": DateTime(2099, 12, 31),
          "selisih_hari": 9999,
        });
      }
    }

    // SINKRONISASI FILTER: Urutkan dari jadwal paling lama ke paling baru (kronologis ascending)
    listWawancaraDiproses.sort((a, b) {
      final tglA = a['tgl_datetime'] as DateTime;
      final tglB = b['tgl_datetime'] as DateTime;
      return tglA.compareTo(tglB);
    });

    semuaDaftarWawancaraMurni = listWawancaraDiproses.map((e) {
      return {
        "nama": e['nama'],
        "tgl_wawancara": e['tgl_wawancara'],
        "jam": e['jam'],
        "lokasi_tujuan": e['lokasi_tujuan'],
        "lokasi_id": e['lokasi_id'],
        "is_overdue": e['is_overdue'],
      };
    }).toList();
  }

  void _notify() => onUpdate?.call();
}
