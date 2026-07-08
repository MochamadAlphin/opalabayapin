import 'package:flutter/material.dart';
import 'package:siraja/screens/dashboard_screen.dart';
import 'package:siraja/screens/profile_screen.dart';
import 'package:siraja/screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      initialRoute: '/main',
      routes: {
        // Default token cadangan jika diakses langsung tanpa lewat alur login (Bypass development)
        '/main': (context) => const MainNavigationScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String? token; // Menyediakan field penampung token opsional

  const MainNavigationScreen({super.key, this.token});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final Color _activeColor = const Color(0xFF102E5A);
  final Color _inactiveColor = const Color(0xFF9E9E9E);

  // Hanya 2 halaman utama: Index 0 (Dashboard) dan Index 1 (Profile)
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Tampung token aktif ke dalam variabel lokal (gunakan fallback jika kosong)
    final String tokenAktif = widget.token ?? "bypass_token_development";

    _screens = [
      // Hapus keyword const, lalu oper tokenAktif ke sini!
      DashboardScreen(token: tokenAktif),

      // Oper juga ke ProfileScreen
      ProfileScreen(userToken: tokenAktif),
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Desain Bottom Navigation Premium dengan Efek Animasi Meluncur (Sliding Effect)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF102E5A).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Menu 1: Dashboard
                _buildAnimatedNavItem(
                  index: 0,
                  activeIcon: Icons.dashboard_rounded,
                  inactiveIcon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                ),

                // Menu 2: Profile
                _buildAnimatedNavItem(
                  index: 1,
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget Helper untuk membangun Item Navigasi Beranimasi Modern
  Widget _buildAnimatedNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            // Efek background pil meluncur halus saat aktif
            color: isActive ? _activeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasi perubahan skala & rotasi halus pada ikon
              AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: isActive ? _activeColor : _inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              // Animasi memunculkan teks secara halus (Fade-in Expansion)
              AnimatedCrossFade(
                firstChild: Text(
                  label,
                  style: TextStyle(
                    color: _activeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: isActive ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}