import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/app_config.dart';
import 'core/config/app_constants.dart';
import 'shared/themes/app_theme.dart';
import 'backoffice/ai/pages/ai_dashboard_page.dart';
import 'backoffice/ai/pages/ai_settings_page.dart';
import 'backoffice/ai/pages/ai_action_log_page.dart';
import 'backoffice/ai/pages/ai_conversation_history.dart';
import 'pos/pages/pos_main_page.dart';
import 'backoffice/pages/staff_management_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);
  await AppConfig.initialize();

  final supabaseKey = AppConfig.isDevelopment &&
          AppConfig.supabaseServiceRoleKey.isNotEmpty &&
          !AppConfig.supabaseServiceRoleKey.startsWith('your-')
      ? AppConfig.supabaseServiceRoleKey
      : AppConfig.supabaseAnonKey;

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const ProviderScope(child: UtterApp()));
}

class UtterApp extends StatelessWidget {
  const UtterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
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
    await Future.delayed(const Duration(seconds: 2));
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.restaurant_menu, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appSlogan,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w400),
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant_menu, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text('Utter App', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Pilih mode untuk masuk', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 40),

              // Two cards
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EntryCard(
                    icon: Icons.point_of_sale_rounded,
                    title: 'POS Kasir',
                    subtitle: 'Mode kasir full screen\nuntuk melayani pelanggan',
                    gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    onTap: () => _goTo(context, const PosMainPage()),
                  ),
                  const SizedBox(width: 20),
                  _EntryCard(
                    icon: Icons.dashboard_rounded,
                    title: 'Back Office',
                    subtitle: 'Dashboard, laporan,\ndan pengaturan bisnis',
                    gradient: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                    onTap: () => _goTo(context, const BackOfficeShell()),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              Text(
                'v1.0.0',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
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

// ─────────────────────────────────────────────
// Back Office Shell — Sidebar Navigation
// ─────────────────────────────────────────────
class BackOfficeShell extends StatefulWidget {
  const BackOfficeShell({super.key});

  @override
  State<BackOfficeShell> createState() => _BackOfficeShellState();
}

class _BackOfficeShellState extends State<BackOfficeShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.psychology_rounded, label: 'Utter AI'),
    (icon: Icons.inventory_2_rounded, label: 'Inventori'),
    (icon: Icons.bar_chart_rounded, label: 'Laporan'),
    (icon: Icons.settings_rounded, label: 'Pengaturan'),
  ];

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const _DashboardPage();
      case 1: return const AiDashboardPage();
      case 2: return const _PlaceholderPage(title: 'Inventori', icon: Icons.inventory_2);
      case 3: return const _PlaceholderPage(title: 'Laporan', icon: Icons.bar_chart);
      case 4: return const StaffManagementPage();
      default: return const _DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1200;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              extended: isWide,
              backgroundColor: AppTheme.surfaceColor,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Text('Utter', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.icon, color: AppTheme.primaryColor),
                        label: Text(item.label),
                      ))
                  .toList(),
            ),

          if (isDesktop) const VerticalDivider(thickness: 1, width: 1),

          Expanded(child: _getPage(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _navItems
                  .map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
                  .toList(),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Dashboard Page
// ─────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat datang di Utter App!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'AI-Integrated F&B Management System',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const [
                _StatCard(title: 'Penjualan Hari Ini', value: 'Rp 0', icon: Icons.trending_up, color: AppTheme.successColor),
                _StatCard(title: 'Total Order', value: '0', icon: Icons.receipt_long, color: AppTheme.primaryColor),
                _StatCard(title: 'Produk Aktif', value: '16', icon: Icons.inventory_2, color: AppTheme.accentColor),
                _StatCard(title: 'Stok Rendah', value: '0', icon: Icons.warning_amber, color: AppTheme.errorColor),
              ],
            ),
            const SizedBox(height: 32),
            Text('Menu Cepat', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickMenuCard(title: 'Utter AI', subtitle: 'Chat & Insights', icon: Icons.psychology, color: AppTheme.aiPrimary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiDashboardPage()))),
                _QuickMenuCard(title: 'AI Settings', subtitle: 'Trust Level Config', icon: Icons.tune, color: AppTheme.aiSecondary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsPage()))),
                _QuickMenuCard(title: 'Action Log', subtitle: 'Riwayat Aksi AI', icon: Icons.history, color: AppTheme.secondaryColor,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiActionLogPage()))),
                _QuickMenuCard(title: 'Riwayat Chat', subtitle: 'Percakapan AI', icon: Icons.chat_bubble_outline, color: AppTheme.infoColor,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiConversationHistory()))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickMenuCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Halaman ini akan segera tersedia',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
