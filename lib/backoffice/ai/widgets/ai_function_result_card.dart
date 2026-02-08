import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:utter_app/shared/themes/app_theme.dart';
import 'package:utter_app/shared/utils/format_utils.dart';

/// A compact card showing what an AI function call did.
///
/// Displays function name (human-readable), icon, brief result summary,
/// and optionally expands to show full argument/result details.
class AiFunctionResultCard extends StatefulWidget {
  /// The raw function name (e.g., "get_stock_levels").
  final String functionName;

  /// Arguments passed to the function.
  final Map<String, dynamic> arguments;

  /// The result returned by the function (null if still executing).
  final Map<String, dynamic>? result;

  /// Whether to use a compact layout (for inline display in chat).
  final bool compact;

  const AiFunctionResultCard({
    super.key,
    required this.functionName,
    this.arguments = const {},
    this.result,
    this.compact = false,
  });

  @override
  State<AiFunctionResultCard> createState() => _AiFunctionResultCardState();
}

class _AiFunctionResultCardState extends State<AiFunctionResultCard> {
  bool _isExpanded = false;

  /// Returns a human-readable name for the function.
  String get _humanReadableName {
    switch (widget.functionName) {
      case 'get_stock_levels':
        return 'Mengecek Stok';
      case 'get_product_list':
        return 'Melihat Daftar Produk';
      case 'create_purchase_order':
        return 'Membuat Purchase Order';
      case 'update_product_price':
        return 'Mengubah Harga Produk';
      case 'disable_product':
        return 'Menonaktifkan Produk';
      case 'enable_product':
        return 'Mengaktifkan Produk';
      case 'get_sales_report':
        return 'Melihat Laporan Penjualan';
      case 'get_daily_summary':
        return 'Ringkasan Harian';
      case 'create_discount':
        return 'Membuat Diskon';
      case 'get_order_history':
        return 'Riwayat Pesanan';
      case 'get_ingredient_usage':
        return 'Penggunaan Bahan Baku';
      case 'forecast_demand':
        return 'Forecast Permintaan';
      case 'get_customer_analytics':
        return 'Analisa Pelanggan';
      case 'adjust_staffing':
        return 'Mengatur Jadwal Staff';
      default:
        return FormatUtils.titleCase(
          widget.functionName.replaceAll('_', ' '),
        );
    }
  }

  /// Returns an icon for the function type.
  IconData get _functionIcon {
    final name = widget.functionName;
    if (name.startsWith('get_') || name.contains('report') || name.contains('summary')) {
      return Icons.search;
    }
    if (name.contains('stock') || name.contains('ingredient')) {
      return Icons.inventory_2_outlined;
    }
    if (name.contains('create') || name.contains('draft')) {
      return Icons.add_circle_outline;
    }
    if (name.contains('update') || name.contains('adjust') || name.contains('enable') || name.contains('disable')) {
      return Icons.edit_outlined;
    }
    if (name.contains('forecast') || name.contains('analytics')) {
      return Icons.analytics_outlined;
    }
    return Icons.terminal;
  }

  /// Returns a brief summary of the result.
  String get _resultSummary {
    if (widget.result == null) return 'Sedang memproses...';

    final result = widget.result!;
    if (result.containsKey('error')) {
      return 'Error: ${result['error']}';
    }
    if (result.containsKey('message')) {
      return result['message'] as String;
    }
    if (result.containsKey('count')) {
      return '${result['count']} item ditemukan';
    }
    if (result.containsKey('success') && result['success'] == true) {
      return 'Berhasil';
    }
    // Try to make a summary from the data
    if (result.containsKey('data')) {
      final data = result['data'];
      if (data is List) {
        return '${data.length} item ditemukan';
      }
    }
    return 'Selesai';
  }

  bool get _isSuccess {
    if (widget.result == null) return true;
    return widget.result!['error'] == null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.aiBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: AppTheme.aiPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _functionIcon,
                  size: 12,
                  color: AppTheme.aiPrimary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _humanReadableName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.aiPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                if (widget.result == null)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.aiPrimary,
                    ),
                  )
                else
                  Icon(
                    _isSuccess
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 12,
                    color: _isSuccess
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 4),
              _buildDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull() {
    return Card(
      elevation: 0,
      color: AppTheme.aiBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(
          color: AppTheme.aiPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.aiPrimary.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Icon(
                      _functionIcon,
                      size: 16,
                      color: AppTheme.aiPrimary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _humanReadableName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resultSummary,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _isSuccess
                                ? AppTheme.textSecondary
                                : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.result == null)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.aiPrimary,
                      ),
                    )
                  else
                    Icon(
                      _isSuccess
                          ? Icons.check_circle
                          : Icons.error_outline,
                      size: 18,
                      color: _isSuccess
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),

              // Expanded details
              if (_isExpanded) ...[
                const SizedBox(height: AppTheme.spacingS),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingS),
                _buildDetails(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arguments
        if (widget.arguments.isNotEmpty) ...[
          Text(
            'Parameter:',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ...widget.arguments.entries.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        // Result
        if (widget.result != null) ...[
          const SizedBox(height: 6),
          Text(
            'Hasil:',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ...widget.result!.entries.take(5).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
