import 'package:flutter/material.dart';
import 'package:siraja/logic/logic_register.dart';
import 'package:siraja/pages/pendaftar_pages.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final Color primaryColor = const Color(0xFF102E5A);
  final Color surfaceColor = const Color(0xFFF8FAFC);

  List<RusunawaModel> listRusunawa = [];
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Memanggil fungsi logic terpisah untuk mengisi state UI
  Future<void> _loadData() async {
    final data = await LogicRegister.fetchRusunawaWithImages();
    if (mounted) {
      setState(() {
        listRusunawa = data;
        _isDataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // 1. Background Image Full Screen
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg_disperkim.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Soft Tint Overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.3),
          ),

          // 3. Main Interface Layout
          SafeArea(
            child: Column(
              children: [
                // Top Action Navigation Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      SizedBox(
                        height: 100,
                        width: 230,
                        child: Image.asset(
                          'assets/images/logo_aptt.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),

                // Header Teks Langsung Menempel
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pendaftaran Hunian',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Silakan pilih lokasi unit rusunawa aktif yang tersedia.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // FLOATING WHITE PANEL WITH SYMMETRICAL GAPS
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _isDataLoading
                          ? Center(child: CircularProgressIndicator(color: primaryColor))
                          : listRusunawa.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_off_rounded, size: 60, color: Color(0xFF94A3B8)),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "Data tidak ditemukan atau\nServer belum aktif",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() => _isDataLoading = true);
                                          _loadData();
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                        child: const Text("Coba Lagi", style: TextStyle(color: Colors.white)),
                                      )
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: listRusunawa.length,
                                  itemBuilder: (context, index) {
                                    return _buildPremiumCardItem(listRusunawa[index]);
                                  },
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. ULTRA CLEAN PREMIUM INNER CARD COMPONENT
  // =========================================================================
  Widget _buildPremiumCardItem(RusunawaModel rusun) {
    bool isAvailable = rusun.availableUnits > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BANNER FOTO RUSUNAWA (Header Top Card Premium - Dynamic API Image)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: rusun.imageUrl != null && rusun.imageUrl!.isNotEmpty
                  ? Image.network(
                rusun.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF102E5A)),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(Icons.business_rounded, color: Color(0xFF94A3B8), size: 40),
                  );
                },
              )
                  : Image.asset(
                'assets/images/bg_disperkim.png', // Fallback default image asset
                fit: BoxFit.cover,
              ),
            ),
          ),

          // KONTEN CARD UTAMA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row Judul Atas + Badge Kamar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rusun.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFFE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAvailable ? 'Tersedia ${rusun.availableUnits} Unit' : 'Tersedia 0 Unit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isAvailable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Alamat dengan Icon Pin Berwarna Biru Sesuai Tema Aplikasi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fmd_good_rounded, size: 14, color: primaryColor.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rusun.location,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // List Fasilitas Checklist yang ada di Gambar
                ...rusun.facilities.take(4).map((facility) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 12, color: Color(0xFF102E5A)),
                      const SizedBox(width: 6),
                      Text(
                        facility,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 12),

                // Garis Pemisah Internal Tipis Eksklusif
                Container(height: 1, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Sesi Bawah: Harga Sewa & Tombol Aksi Sejajar Presisi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Komponen Nilai Rupiah / Unit
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'mulai dari',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              rusun.price.contains('per') || rusun.price.contains('mulai')
                                  ? '-'
                                  : (rusun.price.contains('rb') ? rusun.price : 'Rp ${rusun.price}'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                            const Text(
                              ' per bulan',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Tombol Aksi "Daftar Sekarang" Sesuai Gambar Visual
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: isAvailable
                            ? () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return FractionallySizedBox(
                                heightFactor: 0.85,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(24),
                                    topRight: Radius.circular(24),
                                  ),
                                  child: const PendaftaranPages(),
                                ),
                              );
                            },
                            routeSettings: RouteSettings(
                              arguments: {
                                'id_rusunawa': rusun.id,
                                'nama_rusunawa': rusun.name,
                              },
                            ),
                          );
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF102E5A), // Warna Hijau sesuai tombol "Daftar Sekarang" di Gambar
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Daftar Sekarang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isAvailable ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}