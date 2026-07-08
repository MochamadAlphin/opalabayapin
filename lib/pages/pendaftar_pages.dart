import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../logic/logic_pendaftar.dart';

class PendaftaranPages extends StatefulWidget {
  const PendaftaranPages({super.key});

  @override
  State<PendaftaranPages> createState() => _PendaftaranPagesState();
}

class _PendaftaranPagesState extends State<PendaftaranPages> {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController telpController = TextEditingController();
  String fileName = "No file chosen";
  String? realFilePath; // Menyimpan path asli berkas PDF yang dipilih user
  bool _isLoading = false; // State untuk mencegah double-submit data

  // SIRAJA Balarea Dashboard Premium Palette
  static const Color primaryColor = Color(0xFF102E5A);
  static const Color accentColor = Color(0xFF4F46E5);
  static const Color scaffoldBgColor = Color(0xFFF1F5F9);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color successColor = Color(0xFF102E5A);

  @override
  void dispose() {
    namaController.dispose();
    telpController.dispose();
    super.dispose();
  }

  // =========================================================================
  // FUNGSI MEMILIH FILE PDF ASLI DARI STORAGE HP USER
  // =========================================================================
  Future<void> _pilihFileFormulir() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Membatasi hanya file PDF
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          realFilePath = result.files.single.path;
          fileName = result.files.single.name;
        });
        debugPrint("🎯 File PDF Berhasil Dipilih: $realFilePath");
      } else {
        debugPrint("User membatalkan pemilihan file.");
      }
    } catch (e) {
      debugPrint("❌ Gagal mengambil file dari storage: $e");
    }
  }

  // =========================================================================
  // FUNGSI SIMPAN FILE & LANGSUNG AUTO-OPEN DI LAYAR HP USER
  // =========================================================================
  Future<void> _downloadAndSavePdf(BuildContext context, String namaRusunawa) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator(color: primaryColor));
      },
    );

    try {
      final byteData = await rootBundle.load('assets/docs/form_pendaftar2.pdf');
      final directory = await getTemporaryDirectory();
      String formattedRusunName = namaRusunawa.replaceAll(' ', '_');
      String targetPath = '${directory.path}/Formulir_Pendaftaran_$formattedRusunName.pdf';
      File targetFile = File(targetPath);

      await targetFile.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      final result = await OpenFilex.open(targetPath);

      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal membuka file: ${result.message}. Silakan instal aplikasi pembaca PDF."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ekstrak argumen route yang dioper dari halaman list lokasi sebelumnya
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Ambil nama rusunawa secara fleksibel (memeriksa key 'nama_rusunawa' atau 'nama')
    final String namaRusunawa = arguments?['nama_rusunawa'] ?? arguments?['nama'] ?? 'Rusunawa Limusnunggal';

    // 🛠️ FIX AKURASI ID: Cek kecocokan key id_rusunawa dari RusunawaModel secara berurutan tanpa dipaksa ke String nama
    final dynamic lokasiIdKirim = arguments?['id_rusunawa'] ?? arguments?['id'] ?? arguments?['lokasi_id'] ?? 1;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: const Text(
          'Form Pendaftaran',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 3,
                shadowColor: Colors.black.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: primaryColor, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lokasi Rusunawa Target:',
                                    style: TextStyle(fontSize: 11, color: primaryColor.withOpacity(0.7), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    namaRusunawa,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Nama Lengkap',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: namaController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama lengkap sesuai KTP',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 18),
                          filled: true,
                          fillColor: surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'No Telp / WhatsApp',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: telpController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 081234567xxx',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.phone_android_outlined, color: Color(0xFF64748B), size: 18),
                          filled: true,
                          fillColor: surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_download_outlined, color: accentColor, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Belum mengunduh lembar formulir?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 3),
                                  GestureDetector(
                                    onTap: () => _downloadAndSavePdf(context, namaRusunawa),
                                    child: const Text(
                                      'Buka & Unduh Blanko Formulir',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: accentColor,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          const Text(
                            'Unggah Formulir Pendaftaran ',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          Text(
                            '(Wajib)',
                            style: TextStyle(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: _pilihFileFormulir,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(9),
                                    bottomLeft: Radius.circular(9),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.folder_open_rounded, size: 16, color: primaryColor),
                                    SizedBox(width: 6),
                                    Text(
                                      'Pilih File',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: fileName == "No file chosen" ? const Color(0xFF94A3B8) : Colors.black87,
                                  fontWeight: fileName == "No file chosen" ? FontWeight.normal : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    if (namaController.text.trim().isEmpty || telpController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Harap isi Nama dan Nomor Telepon WhatsApp Anda!"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (realFilePath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Silakan pilih berkas formulir PDF terisi terlebih dahulu!"),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }

                    // Aktifkan loading blocker agar tidak bisa double klik
                    setState(() {
                      _isLoading = true;
                    });

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return const Center(child: CircularProgressIndicator(color: primaryColor));
                      },
                    );

                    // Mengirimkan data identifikasi lokasiIdKirim secara real-time ke logic pendaftar
                    bool success = await LogicPendaftar.kirimPendaftaran(
                      namaLengkap: namaController.text.trim(),
                      noTelp: telpController.text.trim(),
                      lokasiId: lokasiIdKirim,
                      filePath: realFilePath,
                    );

                    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

                    setState(() {
                      _isLoading = false;
                    });

                    if (success) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Pendaftaran di $namaRusunawa Berhasil Dikirim!"),
                            backgroundColor: successColor,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Pendaftaran ditolak oleh server. Periksa kesesuaian data / dokumen Anda."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successColor,
                    disabledBackgroundColor: Colors.grey[400],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _isLoading ? 'Memproses...' : 'Kirim Pendaftaran',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}