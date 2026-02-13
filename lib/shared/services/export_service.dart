/// Service for generating CSV content from report data.
///
/// All methods return a CSV string that can be passed to [downloadCsv]
/// from the platform-specific export_download implementation.
class ExportService {
  /// Generate CSV string from sales report data.
  ///
  /// Includes summary section, payment breakdown, and top products table.
  static String generateSalesReportCsv({
    required String dateRange,
    required double totalSales,
    required int orderCount,
    required double avgOrderValue,
    required Map<String, double> paymentBreakdown,
    required List<Map<String, dynamic>> topProducts,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Laporan Penjualan - Luwa App');
    buffer.writeln('Periode: $dateRange');
    buffer.writeln('');

    // Summary
    buffer.writeln('Ringkasan');
    buffer.writeln('Total Penjualan,$totalSales');
    buffer.writeln('Jumlah Order,$orderCount');
    buffer.writeln('Rata-rata Order,$avgOrderValue');
    buffer.writeln('');

    // Payment breakdown
    buffer.writeln('Metode Pembayaran,Jumlah');
    for (final entry in paymentBreakdown.entries) {
      buffer.writeln('${entry.key},${entry.value}');
    }
    buffer.writeln('');

    // Top products
    buffer.writeln('Produk Terlaris');
    buffer.writeln('No,Produk,Qty,Pendapatan');
    for (var i = 0; i < topProducts.length; i++) {
      final p = topProducts[i];
      buffer.writeln('${i + 1},${_escapeCsv(p['name'] as String? ?? '')},${p['qty']},${p['revenue']}');
    }

    return buffer.toString();
  }

  /// Generate CSV for HPP (Cost of Goods Sold) report.
  ///
  /// Includes revenue/cost summary and per-product detail with margin %.
  static String generateHppReportCsv({
    required String dateRange,
    required double totalRevenue,
    required double totalCost,
    required double grossProfit,
    required double avgMargin,
    required List<Map<String, dynamic>> items,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Laporan HPP - Luwa App');
    buffer.writeln('Periode: $dateRange');
    buffer.writeln('');

    buffer.writeln('Ringkasan');
    buffer.writeln('Total Pendapatan,$totalRevenue');
    buffer.writeln('Total HPP,$totalCost');
    buffer.writeln('Laba Kotor,$grossProfit');
    buffer.writeln('Rata-rata Margin,$avgMargin%');
    buffer.writeln('');

    buffer.writeln('Detail Per Produk');
    buffer.writeln('No,Produk,HPP/Unit,Harga Jual,Qty Terjual,Total Pendapatan,Total HPP,Laba Kotor,Margin %');
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln(
        '${i + 1},'
        '${_escapeCsv(item['name'] as String? ?? '')},'
        '${item['costPrice']},'
        '${item['sellingPrice']},'
        '${item['qty']},'
        '${item['revenue']},'
        '${item['cost']},'
        '${item['profit']},'
        '${item['margin']}%',
      );
    }

    return buffer.toString();
  }

  /// Generate CSV for order history.
  ///
  /// Lists individual orders with date, time, payment method, amounts, and status.
  static String generateOrderHistoryCsv({
    required String dateRange,
    required List<Map<String, dynamic>> orders,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Riwayat Pesanan - Luwa App');
    buffer.writeln('Periode: $dateRange');
    buffer.writeln('');

    buffer.writeln('No,Order Number,Tanggal,Waktu,Tipe,Metode Bayar,Subtotal,Diskon,Pajak,Service Charge,Total,Status');
    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      buffer.writeln(
        '${i + 1},'
        '${_escapeCsv(o['orderNumber'] as String? ?? '')},'
        '${o['date']},'
        '${o['time']},'
        '${_escapeCsv(o['type'] as String? ?? '')},'
        '${_escapeCsv(o['paymentMethod'] as String? ?? '')},'
        '${o['subtotal']},'
        '${o['discount']},'
        '${o['tax']},'
        '${o['serviceCharge']},'
        '${o['total']},'
        '${_escapeCsv(o['status'] as String? ?? '')}',
      );
    }

    return buffer.toString();
  }

  /// Escape a CSV field value.
  /// Wraps in double quotes if it contains commas, quotes, or newlines.
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
