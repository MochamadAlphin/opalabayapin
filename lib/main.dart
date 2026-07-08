import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:siraja/screens/splash_screen.dart';
import 'package:siraja/screens/login_screen.dart';
import 'package:siraja/widgets/bottom_nav.dart';

void main() {
  // PENTING: Memastikan engine Flutter terinisialisasi sebelum menjalankan async task
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // Jalankan cek koneksi setelah frame pertama selesai agar tidak mengganggu splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cekKoneksiKeLaravel();
    });
  }

  Future<void> cekKoneksiKeLaravel() async {
    final String urlTest = "http://10.0.2.2:8000/api/lokasi_user";

    try {
      debugPrint("🚀 [SIRAJA] Mencoba koneksi ke backend...");
      
      // Beri timeout agar tidak menggantung selamanya jika IP salah
      final response = await http.get(Uri.parse(urlTest)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint("✅ [SIRAJA] KONEKSI BERHASIL!");
      } else {
        debugPrint("⚠️ [SIRAJA] SERVER ERROR: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ [SIRAJA] KONEKSI GAGAL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIRAJA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF102E5A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
