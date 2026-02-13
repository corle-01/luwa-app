import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../../shared/themes/app_theme.dart';
import '../providers/backup_provider.dart';
import '../repositories/backup_repository.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupState = ref.watch(backupNotifierProvider);
    final summaryAsync = ref.watch(backupSummaryProvider);

    // Show snackbar on state message changes
    ref.listen<BackupState>(backupNotifierProvider, (prev, next) {
      if (next.message != null && prev?.message != next.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            backgroundColor: next.isError ? AppTheme.errorColor : AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Recovery'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _buildInfoBanner(context),
            const SizedBox(height: 24),

            // Action buttons row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildExportCard(context, ref, backupState),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildImportCard(context, ref, backupState),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildExportCard(context, ref, backupState),
                    const SizedBox(height: 16),
                    _buildImportCard(context, ref, backupState),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Import result
            if (backupState.importResult != null) ...[
              _buildImportResult(context, backupState.importResult!),
              const SizedBox(height: 24),
            ],

            // Table summary
            Text(
              'Ringkasan Data',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Jumlah data saat ini di database',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            summaryAsync.when(
              data: (summary) => _buildSummaryGrid(context, summary),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 8),
                    Text('Error: $e', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(backupSummaryProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.infoColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & Recovery',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.infoColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ekspor semua data outlet ke file JSON untuk backup. '
                  'File backup bisa diimpor kembali untuk memulihkan data.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, WidgetRef ref, BackupState state) {
    final isLoading = state.isExporting;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_download_rounded,
              color: AppTheme.successColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ekspor Backup',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download semua data outlet dalam format JSON',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : () => _handleExport(context, ref),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(isLoading ? 'Mengekspor...' : 'Ekspor Data'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(BuildContext context, WidgetRef ref, BackupState state) {
    final isLoading = state.isImporting;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              color: AppTheme.warningColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Impor Backup',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload file backup JSON untuk memulihkan data',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => _handleImport(context, ref),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(isLoading ? 'Mengimpor...' : 'Pilih File'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.warningColor),
                foregroundColor: AppTheme.warningColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportResult(BuildContext context, Map<String, int> result) {
    final total = result.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Import Berhasil - $total baris diimpor',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: result.entries
                .where((e) => e.value > 0)
                .map((e) => Text(
                      '${BackupRepository.tableLabels[e.key] ?? e.key}: ${e.value}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, BackupSummary summary) {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(summary.fetchedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Data',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                '${summary.totalRows} baris',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),

        // Table rows
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              for (var i = 0; i < summary.tableCounts.entries.length; i++)
                _buildSummaryRow(
                  summary.tableCounts.entries.elementAt(i),
                  isLast: i == summary.tableCounts.entries.length - 1,
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Diperbarui: $dateStr',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(MapEntry<String, int> entry, {bool isLast = false}) {
    final label = BackupRepository.tableLabels[entry.key] ?? entry.key;
    final icon = _tableIcon(entry.key);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: entry.value > 0
                  ? AppTheme.successColor.withValues(alpha: 0.08)
                  : AppTheme.textTertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.value}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: entry.value > 0
                    ? AppTheme.successColor
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _tableIcon(String table) {
    switch (table) {
      case 'categories':
        return Icons.category_rounded;
      case 'products':
        return Icons.inventory_2_rounded;
      case 'customers':
        return Icons.person_rounded;
      case 'ingredients':
        return Icons.science_rounded;
      case 'recipes':
        return Icons.menu_book_rounded;
      case 'taxes':
        return Icons.receipt_long_rounded;
      case 'discounts':
        return Icons.discount_rounded;
      case 'tables':
        return Icons.table_restaurant_rounded;
      case 'staff_profiles':
        return Icons.badge_rounded;
      case 'orders':
        return Icons.shopping_bag_rounded;
      case 'order_items':
        return Icons.list_alt_rounded;
      default:
        return Icons.table_chart_rounded;
    }
  }

  // ── Export handler ──────────────────────────────────────────────────────

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(backupNotifierProvider.notifier);
    final data = await notifier.exportData();

    if (data != null) {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'luwa_backup_$timestamp.json';

      _downloadJsonFile(jsonStr, fileName);

      // Refresh summary after export
      ref.invalidate(backupSummaryProvider);
    }
  }

  /// Download a JSON string as a file in the browser.
  void _downloadJsonFile(String jsonContent, String fileName) {
    final contentBytes = utf8.encode(jsonContent);
    final bytes = Uint8List.fromList(contentBytes);

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
    );

    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }

  // ── Import handler ─────────────────────────────────────────────────────

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    // Use browser file picker via HTML input element
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.json';
    input.style.display = 'none';

    web.document.body!.appendChild(input);

    input.onClick.listen((_) {});
    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.length == 0) {
        web.document.body!.removeChild(input);
        return;
      }

      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.onLoadEnd.listen((_) async {
        web.document.body!.removeChild(input);

        final result = reader.result;
        if (result == null) return;

        try {
          final content = (result as JSString).toDart;
          final jsonData = jsonDecode(content) as Map<String, dynamic>;

          if (!context.mounted) return;

          // Show confirmation dialog
          final confirmed = await _showImportConfirmDialog(context, jsonData);
          if (confirmed != true) return;

          final notifier = ref.read(backupNotifierProvider.notifier);
          final success = await notifier.importData(jsonData);

          if (success) {
            ref.invalidate(backupSummaryProvider);
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tidak valid: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

      reader.readAsText(file);
    });

    input.click();
  }

  Future<bool?> _showImportConfirmDialog(
    BuildContext context,
    Map<String, dynamic> jsonData,
  ) {
    final meta = jsonData['_meta'] as Map<String, dynamic>?;
    final exportedAt = meta?['exported_at'] != null
        ? DateFormat('dd MMM yyyy, HH:mm')
            .format(DateTime.parse(meta!['exported_at'] as String))
        : 'Tidak diketahui';
    final outletId = meta?['outlet_id'] ?? 'Tidak diketahui';
    final tableCounts = meta?['table_counts'] as Map<String, dynamic>?;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            const Text('Konfirmasi Import'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data yang sudah ada akan ditimpa (upsert). '
                        'Pastikan file backup benar sebelum melanjutkan.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Diekspor pada', exportedAt),
              _infoRow('Outlet ID', outletId.toString()),
              if (tableCounts != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Data dalam file:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...tableCounts.entries
                    .where((e) => (e.value as num) > 0)
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                BackupRepository.tableLabels[e.key] ?? e.key,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${e.value} baris',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Ya, Import Data'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
