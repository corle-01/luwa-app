import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/online_order_provider.dart';
import '../repositories/online_order_repository.dart';

// ============================================================
// Platform branding data
// ============================================================

class _PlatformBranding {
  final Color color;
  final IconData icon;
  final String setupGuide;

  const _PlatformBranding({
    required this.color,
    required this.icon,
    required this.setupGuide,
  });
}

const _platformBrandings = <String, _PlatformBranding>{
  'gofood': _PlatformBranding(
    color: Color(0xFF00AA13),
    icon: Icons.delivery_dining,
    setupGuide:
        '1. Login ke GoBiz Dashboard (gobiz.co.id)\n'
        '2. Buka menu Pengaturan > Integrasi API\n'
        '3. Salin Store ID dan API Key dari halaman tersebut\n'
        '4. Tempel di kolom di bawah ini\n'
        '5. Salin Webhook URL dan daftarkan di GoBiz Dashboard\n'
        '6. Klik "Tes Koneksi" untuk memastikan integrasi berhasil',
  ),
  'grabfood': _PlatformBranding(
    color: Color(0xFF00B14F),
    icon: Icons.moped_rounded,
    setupGuide:
        '1. Login ke GrabMerchant Portal (merchant.grab.com)\n'
        '2. Navigasi ke Settings > API Integration\n'
        '3. Generate atau salin Merchant ID dan API Key\n'
        '4. Masukkan kredensial di kolom yang tersedia\n'
        '5. Daftarkan Webhook URL di GrabMerchant Portal\n'
        '6. Verifikasi koneksi dengan tombol "Tes Koneksi"',
  ),
  'shopeefood': _PlatformBranding(
    color: Color(0xFFEE4D2D),
    icon: Icons.fastfood_rounded,
    setupGuide:
        '1. Login ke ShopeeFood Merchant Center\n'
        '2. Buka halaman Pengaturan > Integrasi\n'
        '3. Aktifkan akses API dan salin kredensial\n'
        '4. Masukkan Store ID dan API Key di bawah\n'
        '5. Salin Webhook URL dan tambahkan di Merchant Center\n'
        '6. Lakukan tes koneksi untuk verifikasi',
  ),
};

// ============================================================
// Platform Settings Page
// ============================================================

class PlatformSettingsPage extends ConsumerWidget {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(platformConfigsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrasi Platform'),
      ),
      body: configsAsync.when(
        data: (configs) => _PlatformSettingsBody(configs: configs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(platformConfigsProvider),
        ),
      ),
    );
  }
}

// ============================================================
// Error View
// ============================================================

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat konfigurasi platform',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Body — info banner + list of platform cards
// ============================================================

class _PlatformSettingsBody extends StatelessWidget {
  final List<PlatformConfig> configs;

  const _PlatformSettingsBody({required this.configs});

  @override
  Widget build(BuildContext context) {
    if (configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Belum ada platform terdaftar',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Konfigurasi platform akan muncul setelah diaktifkan oleh admin.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Info banner
        _InfoBanner(),
        const SizedBox(height: 20),
        // Platform cards
        ...configs.map((config) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PlatformCard(config: config),
            )),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ============================================================
// Info Banner
// ============================================================

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.infoColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.infoColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hubungkan toko Anda dengan platform pengiriman makanan online '
              'untuk menerima pesanan langsung di Utter App.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppTheme.infoColor.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Platform Card (stateful — manages local form state)
// ============================================================

class _PlatformCard extends ConsumerStatefulWidget {
  final PlatformConfig config;

  const _PlatformCard({required this.config});

  @override
  ConsumerState<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends ConsumerState<_PlatformCard> {
  late bool _isEnabled;
  late bool _autoAccept;
  late TextEditingController _storeIdController;
  late TextEditingController _apiKeyController;
  late TextEditingController _webhookUrlController;
  late TextEditingController _commissionController;

  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _setupExpanded = false;

  _PlatformBranding get _branding =>
      _platformBrandings[widget.config.platform] ??
      const _PlatformBranding(
        color: AppTheme.primaryColor,
        icon: Icons.store,
        setupGuide: '',
      );

  @override
  void initState() {
    super.initState();
    _initFromConfig();
  }

  void _initFromConfig() {
    _isEnabled = widget.config.isEnabled;
    _autoAccept = widget.config.autoAccept;
    _storeIdController =
        TextEditingController(text: widget.config.storeId ?? '');
    _apiKeyController =
        TextEditingController(text: widget.config.apiKey ?? '');
    _webhookUrlController = TextEditingController(
      text: widget.config.webhookUrl ??
          'https://api.utterapp.com/webhooks/${widget.config.platform}/${widget.config.outletId}',
    );
    _commissionController = TextEditingController(
      text: widget.config.commissionRate > 0
          ? widget.config.commissionRate.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _apiKeyController.dispose();
    _webhookUrlController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // Save
  // ----------------------------------------------------------

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    try {
      final commissionRate =
          double.tryParse(_commissionController.text.trim()) ?? 0;

      final data = <String, dynamic>{
        'is_enabled': _isEnabled,
        'auto_accept': _autoAccept,
        'store_id': _storeIdController.text.trim().isEmpty
            ? null
            : _storeIdController.text.trim(),
        'api_key': _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
        'webhook_url': _webhookUrlController.text.trim().isEmpty
            ? null
            : _webhookUrlController.text.trim(),
        'settings': {
          ...widget.config.settings,
          'commission_rate': commissionRate,
        },
      };

      final repo = ref.read(onlineOrderRepositoryProvider);
      await repo.updatePlatformConfig(widget.config.id, data);

      // Refresh the configs list
      ref.invalidate(platformConfigsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Konfigurasi ${widget.config.displayName} berhasil disimpan',
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ----------------------------------------------------------
  // Test connection (placeholder)
  // ----------------------------------------------------------

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);

    // Simulate a connection test with a short delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isTesting = false);

    final hasCredentials = _storeIdController.text.trim().isNotEmpty &&
        _apiKeyController.text.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              hasCredentials
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: hasCredentials
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              hasCredentials ? 'Koneksi Berhasil' : 'Koneksi Gagal',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          hasCredentials
              ? 'Berhasil terhubung ke ${widget.config.displayName}. '
                  'Platform siap menerima pesanan.'
              : 'Gagal terhubung ke ${widget.config.displayName}. '
                  'Pastikan Store ID dan API Key sudah diisi dengan benar.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Copy webhook URL
  // ----------------------------------------------------------

  void _copyWebhookUrl() {
    Clipboard.setData(ClipboardData(text: _webhookUrlController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Webhook URL disalin ke clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final branding = _branding;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEnabled
              ? branding.color.withValues(alpha: 0.4)
              : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: _isEnabled
                ? branding.color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Header with color accent bar --
          _buildHeader(branding),
          // -- Config body (shown only when enabled) --
          if (_isEnabled) ...[
            const Divider(height: 1),
            _buildConfigBody(branding),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Header
  // ----------------------------------------------------------

  Widget _buildHeader(_PlatformBranding branding) {
    return Container(
      decoration: BoxDecoration(
        color: _isEnabled
            ? branding.color.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(_isEnabled ? 0 : 12),
          bottomRight: Radius.circular(_isEnabled ? 0 : 12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: branding.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(branding.icon, color: branding.color, size: 24),
          ),
          const SizedBox(width: 14),
          // Platform name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.config.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusBadge(
                  isActive: _isEnabled,
                  color: branding.color,
                ),
              ],
            ),
          ),
          // Enable/disable toggle
          Switch.adaptive(
            value: _isEnabled,
            onChanged: (value) {
              setState(() => _isEnabled = value);
            },
            activeColor: branding.color,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Config Body
  // ----------------------------------------------------------

  Widget _buildConfigBody(_PlatformBranding branding) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Setup guide (expandable) --
          _buildSetupGuide(branding),
          const SizedBox(height: 20),

          // -- Store / Merchant ID --
          _buildLabel('Store / Merchant ID'),
          const SizedBox(height: 6),
          TextField(
            controller: _storeIdController,
            decoration: InputDecoration(
              hintText: 'Masukkan Store ID dari ${widget.config.displayName}',
              prefixIcon: const Icon(Icons.store_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // -- API Key --
          _buildLabel('API Key'),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: 'Masukkan API Key',
              prefixIcon: const Icon(Icons.key_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscureApiKey = !_obscureApiKey);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -- Webhook URL (read-only) --
          _buildLabel('Webhook URL'),
          const SizedBox(height: 6),
          TextField(
            controller: _webhookUrlController,
            readOnly: true,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.link_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Salin URL',
                onPressed: _copyWebhookUrl,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Salin URL ini dan daftarkan di dashboard ${widget.config.displayName} Anda.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          // -- Auto-accept & Commission row --
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auto-accept toggle
              Expanded(
                child: _buildAutoAcceptTile(branding),
              ),
              const SizedBox(width: 16),
              // Commission rate
              Expanded(
                child: _buildCommissionField(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // -- Action buttons --
          _buildActionButtons(branding),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Setup Guide (expandable)
  // ----------------------------------------------------------

  Widget _buildSetupGuide(_PlatformBranding branding) {
    return Container(
      decoration: BoxDecoration(
        color: branding.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: branding.color.withValues(alpha: 0.15),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          childrenPadding:
              const EdgeInsets.only(left: 14, right: 14, bottom: 14),
          initiallyExpanded: _setupExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _setupExpanded = expanded);
          },
          leading: Icon(
            Icons.menu_book_rounded,
            color: branding.color,
            size: 20,
          ),
          title: Text(
            'Petunjuk Setup',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: branding.color,
            ),
          ),
          iconColor: branding.color,
          collapsedIconColor: branding.color,
          children: [
            Text(
              branding.setupGuide,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Auto-accept tile
  // ----------------------------------------------------------

  Widget _buildAutoAcceptTile(_PlatformBranding branding) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terima pesanan otomatis',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-accept',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoAccept,
            onChanged: (value) {
              setState(() => _autoAccept = value);
            },
            activeColor: branding.color,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Commission field
  // ----------------------------------------------------------

  Widget _buildCommissionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Komisi Platform'),
        const SizedBox(height: 6),
        TextField(
          controller: _commissionController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: '0',
            suffixText: '%',
            suffixStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
            prefixIcon: const Icon(Icons.percent_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Action buttons
  // ----------------------------------------------------------

  Widget _buildActionButtons(_PlatformBranding branding) {
    return Row(
      children: [
        // Test Connection
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testConnection,
          style: OutlinedButton.styleFrom(
            foregroundColor: branding.color,
            side: BorderSide(color: branding.color.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: _isTesting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: branding.color,
                  ),
                )
              : Icon(Icons.wifi_tethering_rounded, size: 18, color: branding.color),
          label: Text(
            _isTesting ? 'Menguji...' : 'Tes Koneksi',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        // Save
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveConfig,
          style: FilledButton.styleFrom(
            backgroundColor: branding.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _isSaving ? 'Menyimpan...' : 'Simpan',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

// ============================================================
// Status Badge
// ============================================================

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final Color color;

  const _StatusBadge({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : AppTheme.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? color : AppTheme.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Aktif' : 'Tidak Aktif',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? color : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
