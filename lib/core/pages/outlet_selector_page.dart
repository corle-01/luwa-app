import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/outlet_provider.dart';

class OutletSelectorPage extends ConsumerWidget {
  final void Function(BuildContext context, Map<String, dynamic> outlet)
      onOutletSelected;

  const OutletSelectorPage({super.key, required this.onOutletSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(outletsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: outletsAsync.when(
        data: (outlets) {
          // Auto-select if only one outlet
          if (outlets.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentOutletProvider.notifier).state = outlets.first;
              onOutletSelected(context, outlets.first);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return _buildContent(context, ref, outlets);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> outlets,
  ) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Header
                _buildHeader(),
                const SizedBox(height: 40),
                // Outlet grid
                Expanded(
                  child: outlets.isEmpty
                      ? _buildEmpty()
                      : _buildGrid(context, ref, outlets),
                ),
                // Footer with manage link
                _buildFooter(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.store_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Pilih Outlet',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih lokasi outlet untuk melanjutkan',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 56, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Belum ada outlet aktif',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hubungi admin untuk menambahkan outlet',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> outlets,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemCount: outlets.length,
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            return _OutletSelectorCard(
              outlet: outlet,
              onTap: () {
                ref.read(currentOutletProvider.notifier).state = outlet;
                onOutletSelected(context, outlet);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_outlined,
              size: 16, color: AppTheme.textTertiary),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              // Navigate to outlet management - only for admins
              // This is handled by parent who provides this page
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _OutletManagementRedirect(),
                ),
              );
            },
            child: Text(
              'Kelola Outlet',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat daftar outlet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(outletsListProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outlet Selector Card
// ---------------------------------------------------------------------------

class _OutletSelectorCard extends StatefulWidget {
  final Map<String, dynamic> outlet;
  final VoidCallback onTap;

  const _OutletSelectorCard({
    required this.outlet,
    required this.onTap,
  });

  @override
  State<_OutletSelectorCard> createState() => _OutletSelectorCardState();
}

class _OutletSelectorCardState extends State<_OutletSelectorCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.outlet['name'] as String? ?? '-';
    final address = widget.outlet['address'] as String?;
    final phone = widget.outlet['phone'] as String?;

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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFF0D9488)
                  : AppTheme.borderColor,
              width: _hovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _hovering ? 20 : 8,
                offset: Offset(0, _hovering ? 6 : 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Store icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _hovering
                        ? const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _hovering
                        ? null
                        : const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: _hovering
                        ? Colors.white
                        : const Color(0xFF0D9488),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                // Name
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _hovering
                        ? const Color(0xFF0D9488)
                        : AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Address
                if (address != null && address.isNotEmpty)
                  Text(
                    address,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder redirect for "Kelola Outlet" link
// In production this would import the actual OutletManagementPage
// ---------------------------------------------------------------------------

class _OutletManagementRedirect extends StatelessWidget {
  const _OutletManagementRedirect();

  @override
  Widget build(BuildContext context) {
    // Lazy import approach - import at the usage site to avoid circular deps
    // The actual navigation should be handled by the parent app router
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Outlet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_rounded, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Buka menu Kelola Outlet dari Back Office > Pengaturan',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
