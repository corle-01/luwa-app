import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/themes/app_theme.dart';
import '../../core/providers/outlet_provider.dart';
import 'self_order_menu_page.dart';

// ---------------------------------------------------------------------------
// Provider to fetch available tables for manual selection
// ---------------------------------------------------------------------------
final _availableTablesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final outletId = ref.watch(currentOutletIdProvider);
  final response = await Supabase.instance.client
      .from('tables')
      .select('id, table_number, section, capacity, status')
      .eq('outlet_id', outletId)
      .eq('is_active', true)
      .order('table_number', ascending: true);

  return List<Map<String, dynamic>>.from(response as List);
});

// ---------------------------------------------------------------------------
// SelfOrderShell — entry point for customer self-ordering
// ---------------------------------------------------------------------------

/// The entry point for the customer self-order flow.
///
/// If [tableId] is provided and valid, it renders [SelfOrderMenuPage] directly.
/// If [tableId] is null or empty, it shows a branded landing page with
/// instructions and an optional manual table selection grid.
class SelfOrderShell extends ConsumerWidget {
  final String? tableId;

  const SelfOrderShell({super.key, this.tableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tableId != null && tableId!.isNotEmpty) {
      return SelfOrderMenuPage(tableId: tableId!);
    }
    return const _NoTableLandingPage();
  }
}

// ---------------------------------------------------------------------------
// Landing page when no table ID is provided
// ---------------------------------------------------------------------------
class _NoTableLandingPage extends ConsumerStatefulWidget {
  const _NoTableLandingPage();

  @override
  ConsumerState<_NoTableLandingPage> createState() =>
      _NoTableLandingPageState();
}

class _NoTableLandingPageState extends ConsumerState<_NoTableLandingPage> {
  bool _showManualSelect = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9FAFB),
              Color(0xFFEEF2FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 24,
              vertical: 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // ── Utter branding ──
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Utter App',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Self-Order',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── QR scan prompt ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: AppTheme.shadowMD,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 44,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Scan QR Code di Meja',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Untuk mulai memesan, scan QR code\nyang tersedia di meja Anda',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Steps ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cara Pesan',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _StepItem(
                            number: '1',
                            title: 'Duduk di meja',
                            subtitle: 'Pilih meja yang tersedia',
                            icon: Icons.chair_outlined,
                          ),
                          const SizedBox(height: 12),
                          _StepItem(
                            number: '2',
                            title: 'Scan QR code',
                            subtitle: 'Gunakan kamera HP untuk scan',
                            icon: Icons.qr_code_rounded,
                          ),
                          const SizedBox(height: 12),
                          _StepItem(
                            number: '3',
                            title: 'Pilih menu & pesan',
                            subtitle: 'Pilih makanan dan kirim pesanan',
                            icon: Icons.restaurant_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Manual table selection toggle ──
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showManualSelect = !_showManualSelect);
                      },
                      icon: Icon(
                        _showManualSelect
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _showManualSelect
                            ? 'Sembunyikan Pilihan Meja'
                            : 'Pilih Meja Manual',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // ── Manual table selection grid ──
                    if (_showManualSelect) ...[
                      const SizedBox(height: 16),
                      _ManualTableGrid(),
                    ],

                    const SizedBox(height: 40),

                    // ── Footer ──
                    Text(
                      'Powered by Utter App',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step item widget
// ---------------------------------------------------------------------------
class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, size: 20, color: AppTheme.textTertiary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Manual table selection grid
// ---------------------------------------------------------------------------
class _ManualTableGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(_availableTablesProvider);

    return tablesAsync.when(
      data: (tables) {
        if (tables.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Center(
              child: Text(
                'Tidak ada meja tersedia',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Meja',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap meja untuk mulai memesan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tables.map((table) {
                  final tableId = table['id'] as String;
                  final tableNumber = table['table_number']?.toString() ?? '?';
                  final status = table['status'] as String? ?? 'available';
                  final section = table['section'] as String?;
                  final isAvailable = status == 'available';

                  return _ManualTableTile(
                    tableId: tableId,
                    tableNumber: tableNumber,
                    section: section,
                    isAvailable: isAvailable,
                    statusLabel: _statusLabel(status),
                    statusColor: _statusColor(status),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
              const SizedBox(height: 8),
              Text(
                'Gagal memuat daftar meja',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(_availableTablesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Tersedia';
      case 'occupied':
        return 'Terisi';
      case 'reserved':
        return 'Dipesan';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF10B981);
      case 'occupied':
        return const Color(0xFFEF4444);
      case 'reserved':
        return const Color(0xFFF59E0B);
      case 'maintenance':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

// ---------------------------------------------------------------------------
// Individual table tile for manual selection
// ---------------------------------------------------------------------------
class _ManualTableTile extends StatelessWidget {
  final String tableId;
  final String tableNumber;
  final String? section;
  final bool isAvailable;
  final String statusLabel;
  final Color statusColor;

  const _ManualTableTile({
    required this.tableId,
    required this.tableNumber,
    required this.section,
    required this.isAvailable,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable
            ? () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SelfOrderMenuPage(tableId: tableId),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isAvailable
                ? statusColor.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAvailable
                  ? statusColor.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                '$tableNumber',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isAvailable ? AppTheme.textPrimary : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Meja',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (section != null && section!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  section!,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppTheme.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
