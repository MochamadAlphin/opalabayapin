  import 'package:flutter/material.dart';
  import '../logic/logic_dashboard.dart';
  import 'login_screen.dart';

  class DashboardScreen extends StatefulWidget {
    final String token;

    const DashboardScreen({super.key, required this.token});

    @override
    State<DashboardScreen> createState() => _DashboardScreenState();
  }

  class _DashboardScreenState extends State<DashboardScreen> {
    late final DashboardLogic _logic;
    final Color _activeColor = const Color(0xFF102E5A);

    // 🎯 Menyimpan ID lokasi terpilih untuk menyaring antrean wawancara (null berarti Semua Lokasi)
    int? _selectedLokasiId;

    // 🎯 STATE BARU: Pagination untuk Antrean Wawancara (5 data per halaman)
    int _currentPage = 1;
    final int _perPage = 5;

    @override
    void initState() {
      super.initState();
      _logic = DashboardLogic(
        authToken: widget.token,
        onUpdate: () {
          if (mounted) {
            setState(() {});
          }
        },
      );
      _loadDashboardData();
    }

    /// Memuat data dashboard dengan penanganan error pemeliharaan backend
    Future<void> _loadDashboardData() async {
      if (!mounted) return;

      try {
        await _logic.fetchDashboardData(updatedToken: widget.token);
      } catch (e) {
        if (mounted) {
          _handleServerMaintenance();
        }
      }
    }

    /// Fungsi interseptor untuk menendang pengguna kembali ke login saat server mati
    void _handleServerMaintenance() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.gpp_maybe_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sistem sedang dalam pemeliharaan (Maintenance). Koneksi ke backend terputus, silakan masuk kembali nanti.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }

    @override
    Widget build(BuildContext context) {
      double rasioOkupansiAngka = _logic.totalUnit > 0 ? (_logic.unitTerisi / _logic.totalUnit) : 0.0;
      String rasioOkupansiTeks = "${(rasioOkupansiAngka * 100).toStringAsFixed(0)}%";
      int totalPgh = _logic.totalPenghuni;

      // 🎯 KONDISI LOGIKA ROLE: Pimpinan menggunakan list terfilter, yang lain menggunakan list biasa bawaan
      final List<Map<String, dynamic>> wawancaraList = _logic.getFilteredWawancara(
        _logic.isPimpinan ? _selectedLokasiId : null,
      );

      // 🎯 LOGIKA PAGINATION AMAN: Memotong list data untuk halaman aktif saja
      final int totalWawancara = wawancaraList.length;
      final int totalPages = (totalWawancara / _perPage).ceil();

      // Proteksi jika halaman aktif melebihi total halaman baru akibat filter lokasi berubah
      if (_currentPage > totalPages && totalPages > 0) {
        _currentPage = totalPages;
      } else if (totalPages == 0) {
        _currentPage = 1;
      }

      final int startIndex = (_currentPage - 1) * _perPage;
      final int endIndex = (startIndex + _perPage) > totalWawancara ? totalWawancara : (startIndex + _perPage);

      // Potongan list yang akan dirender di layar saat ini
      final List<Map<String, dynamic>> paginatedWawancaraList = totalWawancara > 0
          ? wawancaraList.sublist(startIndex, endIndex)
          : [];

      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 16.0,
          title: Text(
            _logic.isPimpinan ? 'APTRANS Executive Dashboard' : 'Perkim Dashboard',
            style: TextStyle(color: _activeColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: _activeColor),
              onPressed: () => _loadDashboardData(),
            ),
          ],
        ),
        body: _logic.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Ucapan Selamat Datang
                Text(
                  'Halo, ${_logic.adminName} 👋',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _activeColor),
                ),
                const SizedBox(height: 2),
                Text(
                  _logic.isPimpinan
                      ? 'Monitoring Sistem Eksekutif Seluruh Wilayah Perkim.'
                      : 'Sistem Manajemen Hunian Terintegrated Perkim.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // 2. Alert Card Antrean Wawancara Utama
                if (_logic.belumDiwawancara > 0 ||
                    _logic.wawancaraHariIni > 0 ||
                    _logic.wawancaraBesok > 0 ||
                    _logic.wawancaraMingguIni > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gpp_maybe_rounded, color: Colors.red.shade800, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Perhatian Sistem Utama',
                              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 0.5, color: Colors.redAccent),

                        Text(
                          '• Terdapat ${_logic.belumDiwawancara} calon penghuni baru yang belum diwawancara.\n'
                              '• Jadwal Wawancara HARI INI: ${_logic.wawancaraHariIni} orang terdata.\n'
                              '• Jadwal Wawancara BESOK: ${_logic.wawancaraBesok} orang terdata.',
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, color: Colors.red.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Masuk Pekan Ini (H-7): Terdapat ${_logic.wawancaraMingguIni} pendaftar terjadwal dalam 7 hari ke depan.',
                                  style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 3. Card Rasio Okupansi Properti (Akumulasi Semua Lokasi)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _activeColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _logic.isPimpinan ? 'Rasio Total Keterisian Unit (Global Seluruh Rusun)' : 'Rasio Keterisian Unit Properti (Okupansi)',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rasioOkupansiTeks,
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_logic.unitTerisi} Terisi / ${_logic.totalUnit} Unit',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: rasioOkupansiAngka,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Grid Ringkasan Kamar & Jiwa (Total Akumulatif)
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                  children: [
                    _buildSummaryCard(
                      icon: Icons.people_alt_outlined,
                      title: 'Total Penghuni',
                      value: '${_logic.totalPenghuni} Jiwa',
                      iconColor: Colors.red,
                    ),
                    _buildSummaryCard(
                      icon: Icons.home_rounded,
                      title: 'Unit Terisi',
                      value: '${_logic.unitTerisi} Unit',
                      iconColor: Colors.green,
                    ),
                    _buildSummaryCard(
                      icon: Icons.meeting_room_outlined,
                      title: 'Unit Kosong',
                      value: '${_logic.unitKosong} Unit',
                      iconColor: Colors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Real-Time Per Lokasi Wilayah (Khusus Role Pimpinan)
                if (_logic.isPimpinan) ...[
                  Text(
                    'Kondisi Hunian Per Lokasi Wilayah',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _activeColor),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rincian data keterisian unit kamar dan jumlah jiwa masing-masing rusunawa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  _logic.statistikPerLokasi.isEmpty
                      ? const Center(child: Text("Tidak ada data rincian per lokasi.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _logic.statistikPerLokasi.length,
                    itemBuilder: (context, index) {
                      final lokasiData = _logic.statistikPerLokasi[index];
                      double okupansiLokal = lokasiData['total_unit'] > 0
                          ? (lokasiData['unit_terisi'] / lokasiData['total_unit'])
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    lokasiData['nama_lokasi'].toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _activeColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _activeColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${(okupansiLokal * 100).toStringAsFixed(0)}% Terisi",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _activeColor),
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 16, thickness: 0.5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: _buildLocalItemStat("Total Unit", lokasiData['total_unit'].toString(), Colors.grey.shade700)),
                                Expanded(child: _buildLocalItemStat("Terisi", lokasiData['unit_terisi'].toString(), Colors.green)),
                                Expanded(child: _buildLocalItemStat("Kosong", lokasiData['unit_kosong'].toString(), Colors.amber.shade700)),
                                Expanded(child: _buildLocalItemStat("Penghuni", "${lokasiData['total_penghuni']} Jiwa", Colors.red)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. Demografi Umur (Global)
                Text(
                  'Kategori Demografi Umur Penghuni (Global)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _activeColor),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kategori umur berdasarkan Klasifikasi Standar Kemenkes Nomor 25(Tahun 2009).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildAgeProgressRow('Balita (0-5 tahun)', _logic.jmlBalita, totalPgh, Colors.red),
                      const SizedBox(height: 12),
                      _buildAgeProgressRow('Anak-anak (6-11 tahun)', _logic.jmlAnak, totalPgh, Colors.orange),
                      const SizedBox(height: 12),
                      _buildAgeProgressRow('Remaja (12-25 tahun)', _logic.jmlRemaja, totalPgh, Colors.blue),
                      const SizedBox(height: 12),
                      _buildAgeProgressRow('Dewasa (26-45 tahun)', _logic.jmlDewasa, totalPgh, Colors.green),
                      const SizedBox(height: 12),
                      _buildAgeProgressRow('Lansia (>45 tahun)', _logic.jmlLansia, totalPgh, Colors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 7. Judul Section Antrean Wawancara
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Antrean Wawancara Pendaftar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _activeColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: _activeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(
                          _logic.isPimpinan
                              ? (_selectedLokasiId == null
                              ? 'Semua Wilayah ($totalWawancara)'
                              : 'Filter Aktif ($totalWawancara)')
                              : 'Aktif ($totalWawancara)',
                          style: TextStyle(color: _activeColor, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // 8. KHUSUS PIMPINAN: WIDGET DROPDOWN FILTER LOKASI WAWANCARA
                if (_logic.isPimpinan) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedLokasiId,
                        hint: const Text("Pilih Lokasi Wawancara", style: TextStyle(fontSize: 13)),
                        isExpanded: true,
                        icon: Icon(Icons.filter_list_rounded, color: _activeColor),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("Semua Lokasi / Wilayah Hunian", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          ..._logic.statistikPerLokasi.map((lokasi) {
                            final int? lokasiId = lokasi['id'] is int
                                ? lokasi['id'] as int
                                : int.tryParse(lokasi['id'].toString());

                            return DropdownMenuItem<int?>(
                              value: lokasiId,
                              child: Text(
                                lokasi['nama_lokasi'].toString(),
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (int? newValue) {
                          setState(() {
                            _selectedLokasiId = newValue;
                            _currentPage = 1; // 🎯 Reset halaman ke 1 setiap kali pimpinan ganti lokasi filter
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 🎯 9. Daftar Antrean Wawancara (Menggunakan List Ter-paginasi)
                paginatedWawancaraList.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.assignment_late_outlined, color: Colors.grey, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Tidak ada jadwal wawancara.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
                    : Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedWawancaraList.length,
                      itemBuilder: (context, index) {
                        final pendaftar = paginatedWawancaraList[index];
                        bool isOverdue = pendaftar['is_overdue'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOverdue ? Colors.red.shade200 : Colors.grey.shade200,
                              width: isOverdue ? 1.2 : 0.8,
                            ),
                          ),
                          child: Material(
                            color: isOverdue ? Colors.red.shade50.withOpacity(0.3) : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                debugPrint("Detail wawancara pendaftar: ${pendaftar['nama']}");
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isOverdue
                                          ? Colors.red.shade50
                                          : _activeColor.withOpacity(0.08),
                                      child: Icon(
                                        Icons.assignment_ind_outlined,
                                        color: isOverdue ? Colors.red.shade700 : _activeColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pendaftar['nama'] ?? '-',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isOverdue ? Colors.red.shade900 : _activeColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${pendaftar['tgl_wawancara'] ?? ''} • ${pendaftar['jam'] ?? ''}',
                                            style: TextStyle(
                                              color: isOverdue ? Colors.red.shade700 : Colors.blueGrey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Tujuan: ${pendaftar['lokasi_tujuan'] ?? '-'}',
                                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // 🎯 Memunculkan Widget Kontrol Pagination di bawah daftar
                    _buildPaginationControls(totalWawancara),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    /// 🎯 WIDGET HELPER: Navigasi Pagination Elegan
    Widget _buildPaginationControls(int totalItems) {
      final int totalPages = (totalItems / _perPage).ceil();

      // Jika data tidak melebihi 1 halaman, tombol kontrol disembunyikan secara rapi
      if (totalPages <= 1) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tombol Back
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              color: _currentPage > 1 ? _activeColor : Colors.grey.shade400,
              onPressed: _currentPage > 1
                  ? () {
                setState(() {
                  _currentPage--;
                });
              }
                  : null,
            ),
            // Indikator teks halaman aktif
            Text(
              'Halaman $_currentPage dari $totalPages',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _activeColor
              ),
            ),
            // Tombol Next
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              color: _currentPage < totalPages ? _activeColor : Colors.grey.shade400,
              onPressed: _currentPage < totalPages
                  ? () {
                setState(() {
                  _currentPage++;
                });
              }
                  : null,
            ),
          ],
        ),
      );
    }

    Widget _buildLocalItemStat(String label, String value, Color valueColor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      );
    }

    Widget _buildAgeProgressRow(String label, int value, int total, Color color) {
      double pct = total > 0 ? (value / total) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
              Text('$value Jiwa (${(pct * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      );
    }

    Widget _buildSummaryCard({
      required IconData icon,
      required String title,
      required String value,
      required Color iconColor,
    }) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _activeColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          ],
        ),
      );
    }
  }