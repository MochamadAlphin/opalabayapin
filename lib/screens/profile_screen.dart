import 'package:flutter/material.dart';
import 'package:siraja/screens/login_screen.dart';
import 'package:siraja/logic/logic_profile.dart'; // Import logika profil di sini

class ProfileScreen extends StatefulWidget {
  final String userToken; // Terima token dari halaman login / session storage

  const ProfileScreen({super.key, required this.userToken});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryColor = const Color(0xFF102E5A);
  final Color backgroundColor = const Color(0xFFF8FAFC); // Slate background yang lebih soft

  bool _isLoading = false;
  bool _isLoggingOut = false;

  String adminName = "";
  String adminEmail = "";
  String adminRole = "";

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  /// Mengambil data profil asli dari Backend API Laravel Sanctum
  Future<void> fetchProfileData() async {
    setState(() {
      _isLoading = true;
    });

    // Memanggil logic API dengan token session saat ini
    final result = await LogicProfile.getProfile(widget.userToken);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        final userData = result['data'];
        final List lokasiUser = userData['lokasi_user'] ?? [];

        setState(() {
          // FIX: Memasukkan data realtime murni hasil query database MySQL backend
          adminName = userData['name'] ?? '-';
          adminEmail = userData['email'] ?? '-';

          // Mengambil nama_lokasi aktif sesuai relasi tabel hirarki di backend
          adminRole = lokasiUser.isNotEmpty
              ? lokasiUser.first['lokasi']['nama_lokasi']
              : "Super Admin";
        });
      } else {
        // FIX: Hapus data tiruan "Mochamad Alphin" statis agar ketahuan jika token bermasalah
        setState(() {
          adminName = "Gagal Memuat";
          adminEmail = "Token tidak valid";
          adminRole = "Unauthenticated";
        });

        // Tampilkan pesan error transparan ke user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sesi telah habis. Silakan login kembali.'),
            backgroundColor: Colors.red.shade800,
            action: SnackBarAction(
              label: 'LOGIN',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ),
        );
      }
    }
  }

  // Fungsi Proses Logout
  Future<void> _processLogout() async {
    Navigator.pop(context);

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (e) {
      debugPrint("Error logout: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil keluar dari akun'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade700),
              const SizedBox(width: 10),
              const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text('Apakah Anda yakin ingin keluar? Anda perlu login kembali untuk mengakses data SIRAJA.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: _processLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Ubah Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: ListBody(
                    children: [
                      const Text(
                        'Masukkan password lama Anda beserta password baru yang ingin digunakan.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password Lama',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Password lama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password Baru',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password baru wajib diisi';
                          if (v.length < 6) return 'Minimal password panjangnya 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Konfirmasi Password Baru',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v != newPasswordController.text) return 'Konfirmasi password tidak cocok';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() {
                        isDialogLoading = true;
                      });

                      final res = await LogicProfile.changePassword(
                        widget.userToken,
                        currentPasswordController.text,
                        newPasswordController.text,
                      );

                      setDialogState(() {
                        isDialogLoading = false;
                      });

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message']),
                            backgroundColor: res['success'] ? Colors.green : Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isDialogLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profil Akun',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryColor, size: 22),
            onPressed: fetchProfileData,
          ),
        ],
      ),
      body: _isLoggingOut || _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              _isLoggingOut ? 'Menghapus sesi...' : 'Memuat data profil...',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. Header Profil Premium Terpusat
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: primaryColor.withOpacity(0.08),
                        child: Icon(Icons.person_rounded, size: 52, color: primaryColor),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A651),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    adminName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminEmail,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      adminRole,
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Blok Menu Pilihan Konten Rapi
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Keamanan & Sandi',
                    subtitle: 'Ubah password akses akun Anda',
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFE2E8F0)),
                  _buildMenuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Tentang Aplikasi',
                    subtitle: 'Versi 1.0.0 (SIRAJA Balarea)',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Tombol Keluar Akun Premium
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _showLogoutDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Keluar dari Akun',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}