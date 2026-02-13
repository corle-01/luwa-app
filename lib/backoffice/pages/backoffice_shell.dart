import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

import '../../shared/themes/app_theme.dart';
import '../../core/services/realtime_sync_service.dart';
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
class BackOfficeShell extends ConsumerStatefulWidget {
  final void Function(BuildContext context)? onLogoTap;

  const BackOfficeShell({super.key, this.onLogoTap});

  @override
  ConsumerState<BackOfficeShell> createState() => _BackOfficeShellState();
}

class _BackOfficeShellState extends ConsumerState<BackOfficeShell> {
  static const _navStorageKey = 'luwa_bo_tab';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _restoreTabIndex();
  }

  void _restoreTabIndex() {
    try {
      final saved = web.window.localStorage.getItem(_navStorageKey);
      if (saved != null) {
        final idx = int.tryParse(saved) ?? 0;
        if (idx >= 0 && idx < _allNavItems.length) {
          setState(() => _selectedIndex = idx);
        }
      }
    } catch (_) {
      // Non-web platform or storage unavailable
    }
  }

  void _setSelectedIndex(int index) {
    setState(() => _selectedIndex = index);
    try {
      web.window.localStorage.setItem(_navStorageKey, index.toString());
    } catch (_) {}
  }

  static const _allNavItems = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.psychology_rounded, label: 'Luwa AI'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Fixed logo logic: swap for correct contrast
          Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/logo_luwa_dark_sm.png' // Light gray for dark mode
                : 'assets/images/logo_luwa_light_sm.png', // Dark charcoal for light mode
            height: 36, // Increased from 28 to 36
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          Text('Luwa', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
        ],
      ),
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
                  _setSelectedIndex(realIndex);
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
    // Keep Supabase Realtime subscriptions alive
    ref.watch(realtimeSyncProvider);

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
              onDestinationSelected: _setSelectedIndex,
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
                  _showMoreMenu(context);
                } else {
                  _setSelectedIndex(i);
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
