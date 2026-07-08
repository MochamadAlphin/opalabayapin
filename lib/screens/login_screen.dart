import 'package:flutter/material.dart';
import 'package:siraja/screens/register_screen.dart';
import 'package:siraja/widgets/bottom_nav.dart';
import 'package:siraja/logic/login_logic.dart'; // Import file logika API di sini

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool rememberMe = false;
  bool obscurePassword = true;
  bool _isLoading = false; // State tambahan untuk animasi loading tombol

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Master Palette Warna SIRAJA Balarea Premium (Fokus Deep Blue & Slate Gray)
  final Color primaryColor = const Color(0xFF102E5A);
  final Color surfaceColor = const Color(0xFFF8FAFC); // Background ultra-soft di dalam form

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Fungsi internal untuk memicu proses autentikasi API
  Future<void> _handleLogin() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email dan Password tidak boleh kosong"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Memanggil logic API yang terpisah
    final result = await ApiLogin.login(email, password);

    setState(() {
      _isLoading = false;
    });

    if (context.mounted) {
      if (result['success'] == true) {
        // LOGIN BERHASIL
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFF00A651), // Success color
          ),
        );

        // FIX: Meneruskan token autentikasi asli hasil API ke MainNavigationScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(token: result['token']),
          ),
        );
      } else {
        // LOGIN GAGAL (Pesan dari backend Laravel)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: Stack(
        children: [
          // ==========================================
          // 1. BACKGROUND UTAMA (bg_disperkim)
          // ==========================================
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Layer gelap tipis agar background tidak terlalu terang dan kontras melayang
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.25), // Menaikkan kontras agar logo siraja di atas lebih pop-out
          ),

          // ==========================================
          // 2. KONTEN UTAMA (SCROLLABLE)
          // ==========================================
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 70),

                  // LOGO ATAS: logo_siraja (SIRAJA BALAREA)
                  Center(
                    child: Image.asset(
                      'assets/images/logo_aptt.png',
                      width: 250,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. WADAH FORM PUTIH FLOATING PREMIUM
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20), // Disamakan gap-nya dengan Register (20)
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28), // Menggunakan lengkungan premium bulat penuh
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FIX: Mengunci tinggi area logo disperkim agar presisi dan proporsional
                          Center(
                            child: SizedBox(
                              height: 42,
                              width: 300,
                              child: Image.asset(
                                'assets/images/logo_disperkim.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- Field Email ---
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Masukkan Email Anda',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              filled: true,
                              fillColor: surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor, width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --- Field Password ---
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Masukkan Password Anda',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              filled: true,
                              fillColor: surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor, width: 1.5),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // --- Remember Me Only (Forgot Password Berhasil Dihapus) ---
                          Row(
                            children: [
                              Theme(
                                data: ThemeData(
                                  unselectedWidgetColor: const Color(0xFFCBD5E1),
                                ),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: rememberMe,
                                    activeColor: primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (value) {
                                      setState(() {
                                        rememberMe = value!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember me',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // --- Tombol Login Utama ---
                          SizedBox(
                            width: double.infinity,
                            height: 48, // Tinggi tombol yang ideal & kompak ala iOS modern
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin, // Mencegah double tap saat sedang loading
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Selaras dengan radius input field
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Masuk ke Akun',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // --- Switch ke Register ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Belum punya akun? ",
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Daftar Disini',
                                  style: TextStyle(
                                    color: primaryColor, // Diubah ke Deep Blue utama agar oranye hilang sepenuhnya
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}