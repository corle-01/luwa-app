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
import 'purchase_page.dart';

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

  static const _allNavItems = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.psychology_rounded, label: 'Utter AI'),
    (icon: Icons.restaurant_menu_rounded, label: 'Produk'),
    (icon: Icons.inventory_2_rounded, label: 'Inventori'),
    (icon: Icons.bar_chart_rounded, label: 'Laporan'),
    (icon: Icons.shopping_bag_rounded, label: 'Pembelian'),
    (icon: Icons.delivery_dining_rounded, label: 'Online'),
    (icon: Icons.settings_rounded, label: 'Pengaturan'),
  ];

  // Bottom nav shows first 4 + "Lainnya" on mobile
  static const _mobileNavCount = 4;

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const DashboardPage();
      case 1: return const AiDashboardPage();
      case 2: return const ProductManagementPage();
      case 3: return const InventoryPage();
      case 4: return const ReportHubPage();
      case 5: return const PurchasePage();
      case 6: return const OnlineOrderPage();
      case 7: return const SettingsHubPage();
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

  void _showMoreMenu(BuildContext context) {
    final moreItems = _allNavItems.sublist(_mobileNavCount);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(moreItems.length, (i) {
              final realIndex = _mobileNavCount + i;
              final item = moreItems[i];
              final isSelected = _selectedIndex == realIndex;
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                title: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                selected: isSelected,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedIndex = realIndex);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1200;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // For mobile bottom nav: show first N items + "Lainnya"
    final mobileBottomIndex = _selectedIndex < _mobileNavCount
        ? _selectedIndex
        : _mobileNavCount; // select "Lainnya" tab

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
              destinations: _allNavItems
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
              selectedIndex: mobileBottomIndex,
              onDestinationSelected: (i) {
                if (i == _mobileNavCount) {
                  // "Lainnya" tapped — show bottom sheet
                  _showMoreMenu(context);
                } else {
                  setState(() => _selectedIndex = i);
                }
              },
              destinations: [
                ..._allNavItems.take(_mobileNavCount).map(
                  (item) => NavigationDestination(icon: Icon(item.icon), label: item.label),
                ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  label: 'Lainnya',
                ),
              ],
            ),
    );
  }
}
