import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/models/order.dart';
import '../../shared/utils/format_utils.dart';
import 'receipt_print_web.dart' if (dart.library.io) 'receipt_print_stub.dart';

/// Formats an Order + OrderItems into receipt HTML and triggers browser print.
class ReceiptPrinter {
  /// Build order checker HTML - simplified checklist for kitchen/staff verification.
  static String buildOrderCheckerHtml(Order order, List<OrderItem> items) {
    final buf = StringBuffer();

    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html><head><meta charset="utf-8">');
    buf.writeln('<title>Order Checker ${_escapeHtml(order.orderNumber ?? order.id.substring(0, 8))}</title>');
    buf.writeln('<style>');
    buf.writeln(_checkerCss);
    buf.writeln('</style>');
    buf.writeln('</head><body>');
    buf.writeln('<div class="checker">');

    // Header
    buf.writeln('<div class="checker-header">');
    buf.writeln('<div class="checker-title">ORDER CHECKER</div>');
    buf.writeln('<div class="checker-subtitle">✓ Checklist Pesanan</div>');
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Order info
    buf.writeln('<div class="checker-info">');
    buf.writeln('<div class="info-large">Order: <strong>${_escapeHtml(order.orderNumber ?? '#${order.id.substring(0, 8)}')}</strong></div>');
    buf.writeln('<div class="info-medium">${FormatUtils.dateTime(order.createdAt)}</div>');
    buf.writeln('<div class="info-medium">${order.orderType == 'dine_in' ? '🍽️ Dine In' : '🥡 Takeaway'}');
    if (order.tableNumber != null) {
      buf.writeln(' - Meja ${order.tableNumber}');
    }
    buf.writeln('</div>');
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buf.writeln('<div class="info-medium">👤 ${_escapeHtml(order.customerName!)}</div>');
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep-bold">$_dashes</div>');

    // Items checklist
    buf.writeln('<div class="checker-items">');
    for (final item in items) {
      buf.writeln('<div class="checker-item">');
      buf.writeln('<div class="checkbox-row">');
      buf.writeln('<span class="checkbox">☐</span>');
      buf.writeln('<span class="item-qty">${item.quantity}x</span>');
      buf.writeln('<span class="item-name">${_escapeHtml(item.productName)}</span>');
      buf.writeln('</div>');

      // Modifiers
      if (item.modifiers != null && item.modifiers!.isNotEmpty) {
        for (final mod in item.modifiers!) {
          final modName = mod['option_name'] ?? mod['name'] ?? '';
          buf.writeln('<div class="modifier-check">');
          buf.writeln('<span class="checkbox-small">☐</span>');
          buf.writeln('<span>+ ${_escapeHtml(modName.toString())}</span>');
          buf.writeln('</div>');
        }
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        buf.writeln('<div class="item-notes-check">📝 ${_escapeHtml(item.notes!)}</div>');
      }

      buf.writeln('</div>');
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep-bold">$_dashes</div>');

    // Total items summary
    final totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);
    buf.writeln('<div class="checker-summary">');
    buf.writeln('<div class="summary-row"><strong>Total Items:</strong> <strong>$totalItems</strong></div>');
    buf.writeln('<div class="summary-row"><strong>Total Pesanan:</strong> <strong>${FormatUtils.currency(order.totalAmount)}</strong></div>');
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Order notes
    if (order.notes != null && order.notes!.isNotEmpty) {
      buf.writeln('<div class="order-notes-check">');
      buf.writeln('<div class="note-label">⚠️ CATATAN ORDER:</div>');
      buf.writeln('<div class="note-text">${_escapeHtml(order.notes!)}</div>');
      buf.writeln('</div>');
      buf.writeln('<div class="sep">$_dashes</div>');
    }

    // Footer
    buf.writeln('<div class="checker-footer">');
    buf.writeln('<div class="signature-box">');
    buf.writeln('<div class="signature-label">Disiapkan oleh:</div>');
    buf.writeln('<div class="signature-line">_________________</div>');
    buf.writeln('</div>');
    buf.writeln('<div class="signature-box">');
    buf.writeln('<div class="signature-label">Diperiksa oleh:</div>');
    buf.writeln('<div class="signature-line">_________________</div>');
    buf.writeln('</div>');
    buf.writeln('</div>');

    buf.writeln('</div>'); // .checker
    buf.writeln('<script>window.onload = function() { window.print(); }</script>');
    buf.writeln('</body></html>');

    return buf.toString();
  }

  /// Build the full receipt HTML document string.
  static String buildReceiptHtml(Order order, List<OrderItem> items) {
    final buf = StringBuffer();

    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html><head><meta charset="utf-8">');
    buf.writeln('<title>Struk ${_escapeHtml(order.orderNumber ?? order.id.substring(0, 8))}</title>');
    buf.writeln('<style>');
    buf.writeln(_receiptCss);
    buf.writeln('</style>');
    buf.writeln('</head><body>');
    buf.writeln('<div class="receipt">');

    // Header
    buf.writeln('<div class="header">');
    buf.writeln('<div class="store-name">LUWA COFFEE</div>');
    buf.writeln('<div class="store-sub">MALANG</div>');
    buf.writeln('<div class="store-info">Jl. Soekarno Hatta No. 9, Malang</div>');
    buf.writeln('<div class="store-info">Telp: 0341-123456</div>');
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Order info
    buf.writeln('<div class="info-section">');
    buf.writeln(_infoRow('No', _escapeHtml(order.orderNumber ?? '#${order.id.substring(0, 8)}')));
    buf.writeln(_infoRow('Tanggal', FormatUtils.dateTime(order.createdAt)));
    buf.writeln(_infoRow('Kasir', order.cashierName ?? '-'));
    buf.writeln(_infoRow('Tipe', order.orderType == 'dine_in' ? 'Dine In' : 'Takeaway'));
    if (order.tableNumber != null) {
      buf.writeln(_infoRow('Meja', '${order.tableNumber}'));
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buf.writeln(_infoRow('Pelanggan', _escapeHtml(order.customerName!)));
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Items
    buf.writeln('<div class="items-section">');
    for (final item in items) {
      buf.writeln('<div class="item-row">');
      buf.writeln('<div class="item-name">${_escapeHtml(item.productName)}</div>');
      buf.writeln('<div class="item-detail">');
      buf.writeln('<span>${item.quantity} x ${FormatUtils.currency(item.unitPrice)}</span>');
      buf.writeln('<span class="item-price">${FormatUtils.currency(item.totalPrice)}</span>');
      buf.writeln('</div>');

      // Modifiers
      if (item.modifiers != null && item.modifiers!.isNotEmpty) {
        for (final mod in item.modifiers!) {
          final modName = mod['option_name'] ?? mod['name'] ?? '';
          final modPrice = (mod['price_adjustment'] as num?)?.toDouble() ?? 0;
          if (modPrice > 0) {
            buf.writeln('<div class="modifier">+ ${_escapeHtml(modName.toString())} (+${FormatUtils.currency(modPrice)})</div>');
          } else {
            buf.writeln('<div class="modifier">+ ${_escapeHtml(modName.toString())}</div>');
          }
        }
      }

      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        buf.writeln('<div class="item-notes">Note: ${_escapeHtml(item.notes!)}</div>');
      }

      buf.writeln('</div>');
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Totals
    buf.writeln('<div class="totals-section">');
    buf.writeln(_totalRow('Subtotal', FormatUtils.currency(order.subtotal)));
    if (order.discountAmount > 0) {
      buf.writeln(_totalRow('Diskon', '- ${FormatUtils.currency(order.discountAmount)}'));
    }
    if (order.taxAmount > 0) {
      buf.writeln(_totalRow('Pajak', FormatUtils.currency(order.taxAmount)));
    }
    if (order.serviceCharge > 0) {
      buf.writeln(_totalRow('Service Charge', FormatUtils.currency(order.serviceCharge)));
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep-bold">$_dashes</div>');

    // Grand total
    buf.writeln('<div class="grand-total">');
    buf.writeln('<span>TOTAL</span>');
    buf.writeln('<span>${FormatUtils.currency(order.totalAmount)}</span>');
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Order notes
    if (order.notes != null && order.notes!.isNotEmpty) {
      buf.writeln('<div class="order-notes">');
      buf.writeln('<div class="order-notes-label">Catatan:</div>');
      buf.writeln('<div class="order-notes-text">${_escapeHtml(order.notes!)}</div>');
      buf.writeln('</div>');
      buf.writeln('<div class="sep">$_dashes</div>');
    }

    // Payment info
    final isPlatformOrder = order.orderSource != null &&
        order.orderSource != 'pos' &&
        order.amountPaid > 0 &&
        order.totalAmount > order.amountPaid;

    buf.writeln('<div class="totals-section">');
    if (order.paymentMethod == 'split' && order.paymentDetails != null && order.paymentDetails!.isNotEmpty) {
      buf.writeln(_totalRow('Pembayaran', 'Split'));
      for (final detail in order.paymentDetails!) {
        final method = detail['method'] as String? ?? '';
        final amount = (detail['amount'] as num?)?.toDouble() ?? 0;
        final label = detail['label'] as String? ?? _paymentLabel(method);
        buf.writeln(_totalRow('  $label', FormatUtils.currency(amount)));
      }
    } else if (isPlatformOrder) {
      buf.writeln(_totalRow('Dari ${order.orderSource!.toUpperCase()}', FormatUtils.currency(order.amountPaid)));
      buf.writeln(_totalRow('Komisi Platform', FormatUtils.currency(order.totalAmount - order.amountPaid)));
    } else {
      buf.writeln(_totalRow('Bayar (${_paymentLabel(order.paymentMethod)})', FormatUtils.currency(order.amountPaid)));
    }
    if (order.changeAmount > 0) {
      buf.writeln(_totalRow('Kembali', FormatUtils.currency(order.changeAmount)));
    }
    buf.writeln('</div>');

    buf.writeln('<div class="sep">$_dashes</div>');

    // Footer
    buf.writeln('<div class="footer">');
    buf.writeln('<div class="thank-you">Terima kasih telah berkunjung!</div>');
    buf.writeln('<div class="powered-by">Powered by Luwa App</div>');
    buf.writeln('</div>');

    buf.writeln('</div>'); // .receipt
    buf.writeln('<script>window.onload = function() { window.print(); }</script>');
    buf.writeln('</body></html>');

    return buf.toString();
  }

  /// Opens a new browser window with the receipt HTML and triggers print.
  /// After printing the receipt, also prints an order checker list.
  /// Only works on Flutter web. On other platforms, this is a no-op.
  static void printReceipt(Order order, List<OrderItem> items) {
    if (!kIsWeb) return;

    // Print customer receipt first
    final receiptHtml = buildReceiptHtml(order, items);
    openPrintWindow(receiptHtml);

    // Then print order checker list (delayed to allow first print to process)
    Future.delayed(const Duration(milliseconds: 800), () {
      final checkerHtml = buildOrderCheckerHtml(order, items);
      openPrintWindow(checkerHtml);
    });
  }

  /// Payment method label in Bahasa
  static String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'card':
        return 'Debit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'bank_transfer':
        return 'Transfer';
      case 'split':
        return 'Split Payment';
      case 'platform':
        return 'Online Food';
      default:
        return method.toUpperCase();
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _infoRow(String label, String value) {
    return '<div class="info-row"><span class="info-label">$label</span><span class="info-value">$value</span></div>';
  }

  static String _totalRow(String label, String value) {
    return '<div class="total-row"><span>$label</span><span>$value</span></div>';
  }

  static const _dashes = '------------------------------------------------';

  static const _receiptCss = '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Courier New', Courier, monospace;
      font-size: 12px;
      color: #000;
      background: #fff;
      display: flex;
      justify-content: center;
      padding: 0;
    }
    .receipt {
      width: 80mm;
      max-width: 80mm;
      padding: 8px 12px;
      background: #fff;
    }
    .header {
      text-align: center;
      margin-bottom: 4px;
    }
    .store-name {
      font-size: 18px;
      font-weight: bold;
      letter-spacing: 2px;
    }
    .store-sub {
      font-size: 14px;
      font-weight: bold;
      margin-bottom: 2px;
    }
    .store-info {
      font-size: 11px;
      color: #333;
    }
    .sep {
      text-align: center;
      color: #666;
      font-size: 10px;
      overflow: hidden;
      white-space: nowrap;
      margin: 4px 0;
    }
    .sep-bold {
      text-align: center;
      font-weight: bold;
      font-size: 10px;
      overflow: hidden;
      white-space: nowrap;
      margin: 4px 0;
    }
    .info-section {
      margin: 4px 0;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      line-height: 1.6;
    }
    .info-label {
      color: #555;
    }
    .info-value {
      font-weight: 600;
    }
    .items-section {
      margin: 4px 0;
    }
    .item-row {
      margin-bottom: 6px;
    }
    .item-name {
      font-weight: bold;
      font-size: 12px;
    }
    .item-detail {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      padding-left: 8px;
    }
    .item-price {
      font-weight: 600;
    }
    .modifier {
      font-size: 10px;
      color: #555;
      padding-left: 16px;
    }
    .item-notes {
      font-size: 10px;
      color: #777;
      font-style: italic;
      padding-left: 16px;
    }
    .order-notes {
      margin: 4px 0;
      padding: 4px 0;
    }
    .order-notes-label {
      font-size: 11px;
      font-weight: bold;
      color: #333;
    }
    .order-notes-text {
      font-size: 11px;
      color: #555;
      font-style: italic;
      padding-left: 8px;
    }
    .totals-section {
      margin: 4px 0;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      line-height: 1.6;
    }
    .grand-total {
      display: flex;
      justify-content: space-between;
      font-size: 16px;
      font-weight: bold;
      padding: 4px 0;
    }
    .footer {
      text-align: center;
      margin-top: 8px;
    }
    .thank-you {
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 4px;
    }
    .powered-by {
      font-size: 9px;
      color: #999;
    }
    @media print {
      body {
        padding: 0;
        margin: 0;
      }
      .receipt {
        width: 80mm;
        padding: 0 4px;
      }
    }
  ''';

  static const _checkerCss = '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Courier New', Courier, monospace;
      font-size: 12px;
      color: #000;
      background: #fff;
      display: flex;
      justify-content: center;
      padding: 0;
    }
    .checker {
      width: 80mm;
      max-width: 80mm;
      padding: 8px 12px;
      background: #fff;
    }
    .checker-header {
      text-align: center;
      margin-bottom: 6px;
      padding: 4px 0;
      border: 2px solid #000;
      background: #f5f5f5;
    }
    .checker-title {
      font-size: 18px;
      font-weight: bold;
      letter-spacing: 1px;
    }
    .checker-subtitle {
      font-size: 12px;
      margin-top: 2px;
    }
    .sep {
      text-align: center;
      color: #666;
      font-size: 10px;
      overflow: hidden;
      white-space: nowrap;
      margin: 4px 0;
    }
    .sep-bold {
      text-align: center;
      font-weight: bold;
      font-size: 10px;
      overflow: hidden;
      white-space: nowrap;
      margin: 6px 0;
    }
    .checker-info {
      margin: 6px 0;
      padding: 4px;
      background: #f9f9f9;
      border-left: 3px solid #333;
    }
    .info-large {
      font-size: 14px;
      margin-bottom: 3px;
    }
    .info-medium {
      font-size: 11px;
      color: #333;
      line-height: 1.4;
    }
    .checker-items {
      margin: 6px 0;
    }
    .checker-item {
      margin-bottom: 8px;
      padding: 4px;
      border: 1px solid #ddd;
      background: #fafafa;
    }
    .checkbox-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .checkbox {
      font-size: 16px;
      font-weight: bold;
      flex-shrink: 0;
    }
    .checkbox-small {
      font-size: 12px;
      margin-right: 4px;
    }
    .item-qty {
      font-size: 13px;
      font-weight: bold;
      color: #000;
      min-width: 30px;
      flex-shrink: 0;
    }
    .item-name {
      font-size: 13px;
      font-weight: 600;
      flex-grow: 1;
    }
    .modifier-check {
      font-size: 10px;
      color: #555;
      padding-left: 32px;
      margin-top: 2px;
    }
    .item-notes-check {
      font-size: 10px;
      color: #666;
      font-style: italic;
      padding-left: 32px;
      margin-top: 3px;
      background: #fff3cd;
      padding: 3px 3px 3px 32px;
    }
    .order-notes-check {
      margin: 6px 0;
      padding: 6px;
      background: #fff3cd;
      border: 1px dashed #000;
    }
    .note-label {
      font-size: 11px;
      font-weight: bold;
      margin-bottom: 3px;
    }
    .note-text {
      font-size: 11px;
      color: #333;
    }
    .checker-summary {
      margin: 6px 0;
      padding: 6px;
      background: #f0f0f0;
      border: 2px solid #333;
    }
    .summary-row {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      line-height: 1.6;
    }
    .checker-footer {
      margin-top: 8px;
      display: flex;
      justify-content: space-around;
      gap: 12px;
    }
    .signature-box {
      text-align: center;
      flex: 1;
    }
    .signature-label {
      font-size: 10px;
      color: #666;
      margin-bottom: 16px;
    }
    .signature-line {
      font-size: 12px;
      margin-top: 4px;
    }
    @media print {
      body {
        padding: 0;
        margin: 0;
      }
      .checker {
        width: 80mm;
        padding: 0 4px;
      }
    }
  ''';
}
