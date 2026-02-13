import 'dart:typed_data';

/// Low-level ESC/POS command generator for thermal printers.
///
/// Supports 80mm (48 columns) and 58mm (32 columns) paper widths.
/// Generates raw byte sequences conforming to the ESC/POS standard.
class EscPosGenerator {
  final int paperWidth; // 80 or 58 mm
  final List<int> _buffer = [];

  EscPosGenerator({this.paperWidth = 80});

  /// Character columns based on paper width.
  /// 80mm paper = 48 chars, 58mm paper = 32 chars.
  int get columns => paperWidth == 80 ? 48 : 32;

  // ─── Core ESC/POS Commands ────────────────────────────────────────

  /// ESC @ — Initialize/reset printer.
  void initialize() => _buffer.addAll([0x1B, 0x40]);

  /// LF — Line feed (newline). Repeats [lines] times.
  void lineFeed([int lines = 1]) {
    for (var i = 0; i < lines; i++) {
      _buffer.add(0x0A);
    }
  }

  /// GS V 0 — Full paper cut.
  void cut() => _buffer.addAll([0x1D, 0x56, 0x00]);

  /// GS V 1 — Partial paper cut.
  void partialCut() => _buffer.addAll([0x1D, 0x56, 0x01]);

  // ─── Text Alignment ───────────────────────────────────────────────

  /// ESC a 0 — Align text to the left.
  void alignLeft() => _buffer.addAll([0x1B, 0x61, 0x00]);

  /// ESC a 1 — Center-align text.
  void alignCenter() => _buffer.addAll([0x1B, 0x61, 0x01]);

  /// ESC a 2 — Align text to the right.
  void alignRight() => _buffer.addAll([0x1B, 0x61, 0x02]);

  // ─── Text Formatting ─────────────────────────────────────────────

  /// ESC E n — Bold on/off.
  void bold(bool on) => _buffer.addAll([0x1B, 0x45, on ? 0x01 : 0x00]);

  /// ESC ! n — Double height (bit 4).
  void doubleHeight(bool on) =>
      _buffer.addAll([0x1B, 0x21, on ? 0x10 : 0x00]);

  /// ESC ! n — Double width (bit 5).
  void doubleWidth(bool on) =>
      _buffer.addAll([0x1B, 0x21, on ? 0x20 : 0x00]);

  /// ESC ! n — Double height + width (bits 4+5).
  void doubleSize(bool on) =>
      _buffer.addAll([0x1B, 0x21, on ? 0x30 : 0x00]);

  /// ESC - n — Underline on/off.
  void underline(bool on) =>
      _buffer.addAll([0x1B, 0x2D, on ? 0x01 : 0x00]);

  // ─── Text Output ──────────────────────────────────────────────────

  /// Write raw text (no newline).
  void text(String content) => _buffer.addAll(content.codeUnits);

  /// Write text followed by a newline.
  void textLine(String content) {
    text(content);
    lineFeed();
  }

  /// Print a two-column row: left-aligned + right-aligned, padded with spaces.
  void row(String left, String right) {
    final spaces = columns - left.length - right.length;
    if (spaces > 0) {
      textLine('$left${' ' * spaces}$right');
    } else {
      textLine('$left $right');
    }
  }

  /// Print a three-column row (qty, name, price).
  void row3(String col1, String col2, String col3,
      {int col1Width = 4, int col3Width = 12}) {
    final col2Width = columns - col1Width - col3Width;
    final c1 = col1.padRight(col1Width);
    final c2 = col2.length > col2Width
        ? col2.substring(0, col2Width)
        : col2.padRight(col2Width);
    final c3 = col3.padLeft(col3Width);
    textLine('$c1$c2$c3');
  }

  // ─── Separators ───────────────────────────────────────────────────

  /// Print a separator line using [char] repeated to fill the row width.
  void separator([String char = '-']) => textLine(char * columns);

  /// Print a double-line separator using '=' characters.
  void doubleSeparator() => separator('=');

  // ─── Hardware Commands ────────────────────────────────────────────

  /// ESC p — Open cash drawer (kick pulse on pin 2).
  void openDrawer() => _buffer.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);

  /// ESC B — Beep [times] times with duration 0x03.
  void beep([int times = 1]) =>
      _buffer.addAll([0x1B, 0x42, times, 0x03]);

  // ─── Buffer Management ────────────────────────────────────────────

  /// Return the accumulated byte buffer as a [Uint8List].
  Uint8List getBytes() => Uint8List.fromList(_buffer);

  /// Clear the internal buffer for reuse.
  void clear() => _buffer.clear();
}

// ═════════════════════════════════════════════════════════════════════════
// Receipt-specific printer that uses EscPosGenerator to build a full receipt.
// ═════════════════════════════════════════════════════════════════════════

/// High-level receipt builder on top of [EscPosGenerator].
///
/// Accepts structured order data and produces a complete ESC/POS byte
/// sequence ready to send to a thermal printer.
class EscPosReceiptPrinter {
  final EscPosGenerator _gen;

  EscPosReceiptPrinter({int paperWidth = 80})
      : _gen = EscPosGenerator(paperWidth: paperWidth);

  /// Generate a full receipt as raw ESC/POS bytes.
  Uint8List generateReceipt({
    required String outletName,
    required String outletAddress,
    required String outletPhone,
    required String orderNumber,
    required String cashierName,
    required String orderType,
    required DateTime dateTime,
    required List<ReceiptItem> items,
    required double subtotal,
    required double taxAmount,
    required double serviceCharge,
    required double discountAmount,
    required double total,
    required String paymentMethod,
    required double amountPaid,
    required double change,
    String? tableName,
    String? customerName,
    String? notes,
  }) {
    _gen.clear();
    _gen.initialize();

    // ── Header ────────────────────────────────────────────────────
    _gen.alignCenter();
    _gen.doubleSize(true);
    _gen.textLine(outletName);
    _gen.doubleSize(false);
    if (outletAddress.isNotEmpty) _gen.textLine(outletAddress);
    if (outletPhone.isNotEmpty) _gen.textLine(outletPhone);
    _gen.separator();

    // ── Order Info ────────────────────────────────────────────────
    _gen.alignLeft();
    _gen.row('No:', orderNumber);
    _gen.row('Kasir:', cashierName);
    _gen.row('Tipe:', orderType);
    if (tableName != null && tableName.isNotEmpty) {
      _gen.row('Meja:', tableName);
    }
    if (customerName != null && customerName.isNotEmpty) {
      _gen.row('Customer:', customerName);
    }
    _gen.row('Tanggal:', _formatDate(dateTime));
    _gen.row('Jam:', _formatTime(dateTime));
    _gen.separator();

    // ── Items ─────────────────────────────────────────────────────
    for (final item in items) {
      _gen.bold(true);
      _gen.textLine(item.name);
      _gen.bold(false);

      // Modifiers
      if (item.modifiers != null && item.modifiers!.isNotEmpty) {
        for (final mod in item.modifiers!) {
          _gen.textLine('  + $mod');
        }
      }

      // Qty x price → subtotal
      _gen.row(
        '  ${item.qty} x ${_formatCurrency(item.price)}',
        _formatCurrency(item.subtotal),
      );

      // Item notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        _gen.textLine('  *${item.notes}');
      }
    }
    _gen.separator();

    // ── Totals ────────────────────────────────────────────────────
    _gen.row('Subtotal', _formatCurrency(subtotal));
    if (discountAmount > 0) {
      _gen.row('Diskon', '-${_formatCurrency(discountAmount)}');
    }
    if (taxAmount > 0) {
      _gen.row('Pajak', _formatCurrency(taxAmount));
    }
    if (serviceCharge > 0) {
      _gen.row('Service', _formatCurrency(serviceCharge));
    }
    _gen.doubleSeparator();

    // Grand total (bold + double height)
    _gen.bold(true);
    _gen.doubleHeight(true);
    _gen.row('TOTAL', _formatCurrency(total));
    _gen.doubleHeight(false);
    _gen.bold(false);
    _gen.separator();

    // ── Payment ───────────────────────────────────────────────────
    _gen.row('Bayar ($paymentMethod)', _formatCurrency(amountPaid));
    if (change > 0) {
      _gen.row('Kembali', _formatCurrency(change));
    }
    if (amountPaid < total && amountPaid > 0) {
      _gen.row('Komisi Platform', _formatCurrency(total - amountPaid));
    }
    _gen.lineFeed();

    // ── Footer ────────────────────────────────────────────────────
    _gen.alignCenter();
    _gen.textLine('Terima Kasih!');
    _gen.textLine('Powered by Luwa App');
    _gen.lineFeed(3);
    _gen.partialCut();

    return _gen.getBytes();
  }

  /// Generate a short test receipt for verifying printer connection.
  Uint8List generateTestReceipt({
    String outletName = 'LUWA APP',
    int paperWidth = 80,
  }) {
    _gen.clear();
    _gen.initialize();

    _gen.alignCenter();
    _gen.doubleSize(true);
    _gen.textLine(outletName);
    _gen.doubleSize(false);
    _gen.lineFeed();
    _gen.textLine('=== TEST PRINT ===');
    _gen.lineFeed();

    _gen.alignLeft();
    _gen.textLine('Paper: ${paperWidth}mm');
    _gen.textLine('Columns: ${_gen.columns}');
    _gen.separator();
    _gen.textLine('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    _gen.textLine('0123456789');
    _gen.separator();

    _gen.bold(true);
    _gen.textLine('Bold text');
    _gen.bold(false);

    _gen.doubleHeight(true);
    _gen.textLine('Double height');
    _gen.doubleHeight(false);

    _gen.doubleWidth(true);
    _gen.textLine('Double width');
    _gen.doubleWidth(false);

    _gen.separator();
    _gen.row('Left', 'Right');
    _gen.row('Item Test', 'Rp 10.000');
    _gen.doubleSeparator();
    _gen.row('TOTAL', 'Rp 10.000');
    _gen.separator();

    _gen.alignCenter();
    _gen.textLine('Printer OK!');
    _gen.lineFeed(3);
    _gen.partialCut();

    return _gen.getBytes();
  }

  // ─── Formatting Helpers ─────────────────────────────────────────

  /// Format a double as Indonesian Rupiah (e.g. "Rp 25.000").
  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]}.',
        )}';
  }

  /// Format a DateTime to dd/MM/yyyy.
  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  /// Format a DateTime to HH:mm.
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Kitchen ticket printer — larger text, no prices, focus on items & mods.
// ═════════════════════════════════════════════════════════════════════════

/// Generates a kitchen order ticket (KOT) in ESC/POS format.
///
/// Kitchen tickets differ from customer receipts:
/// - No prices displayed
/// - Larger font for item names
/// - Prominent order number and type
/// - Modifier/notes emphasis
/// - Table number highly visible
class EscPosKitchenTicket {
  final EscPosGenerator _gen;

  EscPosKitchenTicket({int paperWidth = 80})
      : _gen = EscPosGenerator(paperWidth: paperWidth);

  /// Generate a kitchen order ticket as raw ESC/POS bytes.
  Uint8List generateTicket({
    required String orderNumber,
    required String orderType,
    required DateTime dateTime,
    required List<KitchenTicketItem> items,
    String? tableName,
    String? cashierName,
    String? notes,
  }) {
    _gen.clear();
    _gen.initialize();

    // ── Header — big & bold ────────────────────────────────────
    _gen.alignCenter();
    _gen.doubleSize(true);
    _gen.bold(true);
    _gen.textLine('ORDER DAPUR');
    _gen.doubleSize(false);
    _gen.bold(false);
    _gen.separator('=');

    // ── Order number — very prominent ──────────────────────────
    _gen.alignCenter();
    _gen.doubleSize(true);
    _gen.bold(true);
    _gen.textLine('#$orderNumber');
    _gen.doubleSize(false);
    _gen.bold(false);

    // ── Order type + table ─────────────────────────────────────
    _gen.alignLeft();
    _gen.bold(true);
    _gen.row('Tipe:', _orderTypeLabel(orderType));
    _gen.bold(false);
    if (tableName != null && tableName.isNotEmpty) {
      _gen.doubleHeight(true);
      _gen.bold(true);
      _gen.row('Meja:', tableName);
      _gen.bold(false);
      _gen.doubleHeight(false);
    }
    _gen.row('Jam:', _formatTime(dateTime));
    if (cashierName != null && cashierName.isNotEmpty) {
      _gen.row('Kasir:', cashierName);
    }
    _gen.separator('=');

    // ── Items grouped by station (Kitchen / Bar) ──────────────
    final kitchenItems = items.where((i) => i.station != 'bar').toList();
    final barItems = items.where((i) => i.station == 'bar').toList();
    final hasMultipleStations = kitchenItems.isNotEmpty && barItems.isNotEmpty;

    void _printItemGroup(List<KitchenTicketItem> group) {
      for (var i = 0; i < group.length; i++) {
        final item = group[i];
        _gen.doubleHeight(true);
        _gen.bold(true);
        _gen.textLine('${item.qty}x ${item.name}');
        _gen.bold(false);
        _gen.doubleHeight(false);

        if (item.modifiers != null && item.modifiers!.isNotEmpty) {
          for (final mod in item.modifiers!) {
            _gen.textLine('  + $mod');
          }
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          _gen.bold(true);
          _gen.textLine('  *** ${item.notes} ***');
          _gen.bold(false);
        }
        if (i < group.length - 1) {
          _gen.separator('-');
        }
      }
    }

    if (hasMultipleStations) {
      // KITCHEN section
      _gen.alignCenter();
      _gen.doubleHeight(true);
      _gen.bold(true);
      _gen.textLine('[ KITCHEN ]');
      _gen.bold(false);
      _gen.doubleHeight(false);
      _gen.alignLeft();
      _printItemGroup(kitchenItems);
      _gen.separator('=');

      // BAR section
      _gen.alignCenter();
      _gen.doubleHeight(true);
      _gen.bold(true);
      _gen.textLine('[ BAR ]');
      _gen.bold(false);
      _gen.doubleHeight(false);
      _gen.alignLeft();
      _printItemGroup(barItems);
    } else {
      // Single station — no section headers needed
      _printItemGroup(items);
    }
    _gen.separator('=');

    // ── Order notes ────────────────────────────────────────────
    if (notes != null && notes.isNotEmpty) {
      _gen.bold(true);
      _gen.textLine('CATATAN:');
      _gen.bold(false);
      _gen.textLine(notes);
      _gen.separator();
    }

    // ── Footer ─────────────────────────────────────────────────
    _gen.alignCenter();
    _gen.textLine('Total: ${items.fold(0, (s, i) => s + i.qty)} item');
    _gen.lineFeed(3);
    _gen.partialCut();

    return _gen.getBytes();
  }

  /// Build HTML kitchen ticket for browser printing.
  String generateHtmlTicket({
    required String orderNumber,
    required String orderType,
    required DateTime dateTime,
    required List<KitchenTicketItem> items,
    int paperWidth = 80,
    String? tableName,
    String? cashierName,
    String? notes,
  }) {
    final sep = '-' * (paperWidth == 80 ? 48 : 32);
    final dblSep = '=' * (paperWidth == 80 ? 48 : 32);
    final totalItems = items.fold(0, (s, i) => s + i.qty);

    // Group items by station
    final kitchenItems = items.where((i) => i.station != 'bar').toList();
    final barItems = items.where((i) => i.station == 'bar').toList();
    final hasMultipleStations = kitchenItems.isNotEmpty && barItems.isNotEmpty;

    String _buildItemGroupHtml(List<KitchenTicketItem> group) {
      final buf = StringBuffer();
      for (var i = 0; i < group.length; i++) {
        final item = group[i];
        buf.write('<div class="item-name">${item.qty}x ${_esc(item.name)}</div>');
        if (item.modifiers != null) {
          for (final mod in item.modifiers!) {
            buf.write('<div class="mod">+ ${_esc(mod)}</div>');
          }
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          buf.write('<div class="item-note">*** ${_esc(item.notes!)} ***</div>');
        }
        if (i < group.length - 1) {
          buf.write('<div class="sep">$sep</div>');
        }
      }
      return buf.toString();
    }

    final itemsHtml = StringBuffer();
    if (hasMultipleStations) {
      itemsHtml.write('<div class="station-header">[ KITCHEN ]</div>');
      itemsHtml.write(_buildItemGroupHtml(kitchenItems));
      itemsHtml.write('<div class="sep">$dblSep</div>');
      itemsHtml.write('<div class="station-header">[ BAR ]</div>');
      itemsHtml.write(_buildItemGroupHtml(barItems));
    } else {
      itemsHtml.write(_buildItemGroupHtml(items));
    }

    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Kitchen Ticket #$orderNumber</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Courier New', monospace; font-size: 14px; display: flex; justify-content: center; }
  .ticket { width: ${paperWidth}mm; max-width: ${paperWidth}mm; padding: 8px 12px; }
  .center { text-align: center; }
  .bold { font-weight: bold; }
  .big { font-size: 22px; font-weight: bold; }
  .order-num { font-size: 28px; font-weight: bold; text-align: center; margin: 4px 0; }
  .sep { color: #666; font-size: 12px; overflow: hidden; white-space: nowrap; margin: 4px 0; }
  .row { display: flex; justify-content: space-between; font-size: 14px; }
  .row.bold { font-weight: bold; }
  .table-row { font-size: 20px; font-weight: bold; display: flex; justify-content: space-between; }
  .item-name { font-size: 18px; font-weight: bold; margin-top: 6px; }
  .mod { font-size: 13px; padding-left: 12px; }
  .item-note { font-size: 14px; font-weight: bold; padding-left: 12px; color: #333; }
  .station-header { font-size: 20px; font-weight: bold; text-align: center; margin: 8px 0 4px 0; letter-spacing: 2px; }
  .notes-section { margin-top: 4px; }
  @media print { body { padding: 0; margin: 0; } .ticket { padding: 0 4px; } }
</style>
</head><body>
<div class="ticket">
  <div class="center big">ORDER DAPUR</div>
  <div class="sep">$dblSep</div>
  <div class="order-num">#$orderNumber</div>
  <div class="row bold"><span>Tipe:</span><span>${_esc(_orderTypeLabel(orderType))}</span></div>
  ${tableName != null && tableName.isNotEmpty ? '<div class="table-row"><span>Meja:</span><span>${_esc(tableName)}</span></div>' : ''}
  <div class="row"><span>Jam:</span><span>${_formatTime(dateTime)}</span></div>
  ${cashierName != null ? '<div class="row"><span>Kasir:</span><span>${_esc(cashierName)}</span></div>' : ''}
  <div class="sep">$dblSep</div>
  $itemsHtml
  <div class="sep">$dblSep</div>
  ${notes != null && notes.isNotEmpty ? '<div class="notes-section"><div class="bold">CATATAN:</div><div>${_esc(notes)}</div></div><div class="sep">$sep</div>' : ''}
  <div class="center">Total: $totalItems item</div>
</div>
<script>window.onload = function() { window.print(); }</script>
</body></html>
''';
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in': return 'Dine In';
      case 'takeaway': return 'Take Away';
      case 'delivery': return 'Delivery';
      default: return type;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _esc(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Data class for a single kitchen ticket item.
class KitchenTicketItem {
  final String name;
  final int qty;
  final List<String>? modifiers;
  final String? notes;
  final String station; // 'kitchen' or 'bar'

  const KitchenTicketItem({
    required this.name,
    required this.qty,
    this.modifiers,
    this.notes,
    this.station = 'kitchen',
  });
}

/// Data class for a single receipt line item.
class ReceiptItem {
  final String name;
  final int qty;
  final double price;
  final double subtotal;
  final List<String>? modifiers;
  final String? notes;

  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.modifiers,
    this.notes,
  });
}
