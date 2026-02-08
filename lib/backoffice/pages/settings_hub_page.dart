import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/theme_provider.dart';
import '../../shared/themes/app_theme.dart';
import 'staff_management_page.dart';
import 'tax_management_page.dart';
import 'recipe_management_page.dart';
import 'discount_management_page.dart';
import 'table_management_page.dart';
import 'customer_management_page.dart';
import 'loyalty_management_page.dart';
import 'supplier_management_page.dart';
import 'purchase_order_page.dart';
import 'platform_settings_page.dart';
import 'outlet_management_page.dart';
import 'printer_settings_page.dart';
import '../ai/pages/ai_settings_page.dart';

class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  static const _items = [
    _SettingsItem(
      icon: Icons.people_rounded,
      title: 'Staff & Kasir',
      subtitle: 'Kelola data karyawan dan PIN kasir',
      color: Color(0xFF4F46E5),
    ),
    _SettingsItem(
      icon: Icons.receipt_long_rounded,
      title: 'Pajak',
      subtitle: 'Atur PPN, service charge, dan pajak lainnya',
      color: Color(0xFF059669),
    ),
    _SettingsItem(
      icon: Icons.menu_book_rounded,
      title: 'Resep',
      subtitle: 'Kelola resep produk dan bahan baku',
      color: Color(0xFFD97706),
    ),
    _SettingsItem(
      icon: Icons.discount_rounded,
      title: 'Diskon',
      subtitle: 'Buat dan kelola promo diskon',
      color: Color(0xFFDC2626),
    ),
    _SettingsItem(
      icon: Icons.table_restaurant_rounded,
      title: 'Meja',
      subtitle: 'Atur nomor meja dan area restoran',
      color: Color(0xFF7C3AED),
    ),
    _SettingsItem(
      icon: Icons.person_rounded,
      title: 'Pelanggan',
      subtitle: 'Data pelanggan dan loyalitas',
      color: Color(0xFF2563EB),
    ),
    _SettingsItem(
      icon: Icons.card_giftcard_rounded,
      title: 'Loyalitas',
      subtitle: 'Program poin dan reward pelanggan',
      color: Color(0xFFE11D48),
    ),
    _SettingsItem(
      icon: Icons.local_shipping_rounded,
      title: 'Supplier',
      subtitle: 'Kelola data pemasok bahan baku',
      color: Color(0xFF0891B2),
    ),
    _SettingsItem(
      icon: Icons.shopping_cart_checkout_rounded,
      title: 'Purchase Order',
      subtitle: 'Buat dan kelola pesanan pembelian',
      color: Color(0xFF9333EA),
    ),
    _SettingsItem(
      icon: Icons.cloud_sync_rounded,
      title: 'Integrasi Platform',
      subtitle: 'Kelola GoFood, GrabFood, ShopeeFood',
      color: Color(0xFF16A34A),
    ),
    _SettingsItem(
      icon: Icons.store_rounded,
      title: 'Kelola Outlet',
      subtitle: 'Tambah dan kelola lokasi outlet',
      color: Color(0xFF0D9488),
    ),
    _SettingsItem(
      icon: Icons.print_rounded,
      title: 'Printer',
      subtitle: 'Pengaturan printer struk',
      color: Color(0xFF6366F1),
    ),
    _SettingsItem(
      icon: Icons.smart_toy_rounded,
      title: 'Utter AI',
      subtitle: 'Pengaturan trust level dan fitur AI',
      color: Color(0xFF8B5CF6),
    ),
  ];

  void _navigateTo(BuildContext context, int index) {
    Widget page;
    switch (index) {
      case 0:
        page = const StaffManagementPage();
      case 1:
        page = const TaxManagementPage();
      case 2:
        page = const RecipeManagementPage();
      case 3:
        page = const DiscountManagementPage();
      case 4:
        page = const TableManagementPage();
      case 5:
        page = const CustomerManagementPage();
      case 6:
        page = const LoyaltyManagementPage();
      case 7:
        page = const SupplierManagementPage();
      case 8:
        page = const PurchaseOrderPage();
      case 9:
        page = const PlatformSettingsPage();
      case 10:
        page = const OutletManagementPage();
      case 11:
        page = const PrinterSettingsPage();
      case 12:
        page = const AiSettingsPage();
      default:
        return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: Column(
        children: [
          // Dark mode toggle
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Card(
                  child: SwitchListTile(
                    title: const Text('Mode Gelap'),
                    subtitle: Text(isDark ? 'Dark mode aktif' : 'Light mode aktif'),
                    secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                    value: isDark,
                    onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                        v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              );
            },
          ),
          // Settings grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                        ? 2
                        : 1;

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _SettingsCard(
                      item: item,
                      onTap: () => _navigateTo(context, index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _SettingsCard extends StatefulWidget {
  final _SettingsItem item;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? widget.item.color : AppTheme.borderColor,
              width: _hovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? widget.item.color.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovering ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.item.icon,
                    color: widget.item.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _hovering ? widget.item.color : AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
