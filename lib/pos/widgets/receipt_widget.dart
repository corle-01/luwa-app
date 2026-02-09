import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/models/order.dart';
import '../../shared/utils/format_utils.dart';
import 'receipt_print_web.dart' if (dart.library.io) 'receipt_print_stub.dart';

/// Formats an Order + OrderItems into receipt HTML and triggers browser print.
class ReceiptPrinter {
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
    buf.writeln('<div class="store-name">UTTER COFFEE</div>');
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
    buf.writeln('<div class="totals-section">');
    if (order.paymentMethod == 'split' && order.paymentDetails != null && order.paymentDetails!.isNotEmpty) {
      buf.writeln(_totalRow('Pembayaran', 'Split'));
      for (final detail in order.paymentDetails!) {
        final method = detail['method'] as String? ?? '';
        final amount = (detail['amount'] as num?)?.toDouble() ?? 0;
        final label = detail['label'] as String? ?? _paymentLabel(method);
        buf.writeln(_totalRow('  $label', FormatUtils.currency(amount)));
      }
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
    buf.writeln('<div class="powered-by">Powered by Utter App</div>');
    buf.writeln('</div>');

    buf.writeln('</div>'); // .receipt
    buf.writeln('<script>window.onload = function() { window.print(); }</script>');
    buf.writeln('</body></html>');

    return buf.toString();
  }

  /// Opens a new browser window with the receipt HTML and triggers print.
  /// Only works on Flutter web. On other platforms, this is a no-op.
  static void printReceipt(Order order, List<OrderItem> items) {
    if (!kIsWeb) return;
    final receiptHtml = buildReceiptHtml(order, items);
    openPrintWindow(receiptHtml);
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
}
