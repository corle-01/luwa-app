import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/themes/app_theme.dart';
import '../ai/pages/ai_dashboard_page.dart';
import 'settings_hub_page.dart';
import 'dashboard_page.dart';
import 'product_management_page.dart';
import 'inventory_page.dart';
import 'report_hub_page.dart';
import 'online_order_page.dart';

/// Back Office Shell — Sidebar Navigation
///
/// [onLogoTap] — optional callback when the logo is tapped. If null, the logo
/// is not clickable (standalone mode).
class BackOfficeShell extends StatefulWidget {
  final void Function(BuildContext context)? onLogoTap;

  const BackOfficeShell({super.key, this.onLogoTap});

  @override
  State<BackOfficeShell> createState() => _BackOfficeShellState();
}

class _BackOfficeShellState extends State<BackOfficeShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.psychology_rounded, label: 'Utter AI'),
    (icon: Icons.restaurant_menu_rounded, label: 'Produk'),
    (icon: Icons.inventory_2_rounded, label: 'Inventori'),
    (icon: Icons.bar_chart_rounded, label: 'Laporan'),
    (icon: Icons.delivery_dining_rounded, label: 'Online'),
    (icon: Icons.settings_rounded, label: 'Pengaturan'),
  ];

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const DashboardPage();
      case 1: return const AiDashboardPage();
      case 2: return const ProductManagementPage();
      case 3: return const InventoryPage();
      case 4: return const ReportHubPage();
      case 5: return const OnlineOrderPage();
      case 6: return const SettingsHubPage();
      default: return const DashboardPage();
    }
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo_utter_dark.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Utter', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
      ],
    );
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
                child: widget.onLogoTap != null
                    ? GestureDetector(
                        onTap: () => widget.onLogoTap!(context),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _buildLogo(),
                        ),
                      )
                    : _buildLogo(),
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
