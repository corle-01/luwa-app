import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/app_init.dart';
import 'core/config/app_constants.dart';
import 'core/providers/theme_provider.dart';
import 'shared/themes/app_theme.dart';
import 'pos/pages/pos_main_page.dart';
import 'kds/pages/kds_page.dart';
import 'self_order/pages/self_order_shell.dart';
import 'backoffice/pages/backoffice_shell.dart';

void main() async {
  await initializeApp();
  runApp(const ProviderScope(child: LuwaApp()));
}

class LuwaApp extends ConsumerWidget {
  const LuwaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        // POS route: /pos
        if (uri.path == '/pos') {
          return MaterialPageRoute(
            builder: (_) => const PosMainPage(),
          );
        }

        // Back Office route: /backoffice
        if (uri.path == '/backoffice') {
          return MaterialPageRoute(
            builder: (_) => BackOfficeShell(
              onLogoTap: (ctx) => Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
              ),
            ),
          );
        }

        // Kitchen Display route: /kds
        if (uri.path == '/kds') {
          return MaterialPageRoute(
            builder: (_) => const KdsPage(),
          );
        }

        // Self-order route: /self-order?table=TABLE_ID
        if (uri.path == '/self-order') {
          final tableId = uri.queryParameters['table'];
          return MaterialPageRoute(
            builder: (_) => SelfOrderShell(tableId: tableId),
          );
        }

        // Default route — splash screen → role selection
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Splash Screen
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const RoleSelectionPage(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = screenWidth < 400 ? screenWidth * 0.65 : screenWidth * 0.3;
    final clampedLogoWidth = logoWidth.clamp(200.0, 420.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Splash has dark background, use light/white logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Image.asset(
                      'assets/images/logo_luwa_dark.png', // Light gray/white for dark blue gradient
                      width: clampedLogoWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appSlogan,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Role Selection Page — 2 Entry Points
// ─────────────────────────────────────────────
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = (screenWidth < 400 ? screenWidth * 0.6 : screenWidth * 0.25).clamp(180.0, 360.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with extra padding to prevent speech bubble tail clipping
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/images/logo_luwa_dark.png' // Light gray for dark mode
                          : 'assets/images/logo_luwa_light.png', // Dark charcoal for light mode
                      width: logoWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Pilih mode untuk masuk', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: 40),

                  // Three entry cards
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _EntryCard(
                        icon: Icons.point_of_sale_rounded,
                        title: 'POS Kasir',
                        subtitle: 'Mode kasir full screen\nuntuk melayani pelanggan',
                        gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        onTap: () => _goTo(context, const PosMainPage()),
                      ),
                      _EntryCard(
                        icon: Icons.dashboard_rounded,
                        title: 'Back Office',
                        subtitle: 'Dashboard, laporan,\ndan pengaturan bisnis',
                        gradient: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        onTap: () => _goTo(context, BackOfficeShell(
                          onLogoTap: (ctx) => Navigator.of(ctx).pushReplacement(
                            MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                          ),
                        )),
                      ),
                      _EntryCard(
                        icon: Icons.restaurant_rounded,
                        title: 'Kitchen Display',
                        subtitle: 'Layar dapur untuk\nkelola pesanan masak',
                        gradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
                        onTap: () => _goTo(context, const KdsPage()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/logo_collab_light_sm.png'
                        : 'assets/images/logo_collab_dark_sm.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v1.0.0',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 220,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? widget.gradient[0] : AppTheme.borderColor,
              width: _hovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? widget.gradient[0].withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _hovering ? 20 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.gradient[0].withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Masuk',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: widget.gradient[0]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


