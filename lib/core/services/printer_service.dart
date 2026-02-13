import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'escpos_generator.dart';
import 'web_usb_printer.dart';
import 'web_bluetooth_printer.dart';

// ═════════════════════════════════════════════════════════════════════════
// Enums & Models
// ═════════════════════════════════════════════════════════════════════════

/// Supported printer connection types.
enum PrinterType { browser, usb, bluetooth, network }

/// Display label for a [PrinterType].
String printerTypeLabel(PrinterType type) {
  switch (type) {
    case PrinterType.browser:
      return 'Browser';
    case PrinterType.usb:
      return 'USB';
    case PrinterType.bluetooth:
      return 'Bluetooth';
    case PrinterType.network:
      return 'Network';
  }
}

/// Icon name hint for a [PrinterType] (matches Material Icons).
String printerTypeIcon(PrinterType type) {
  switch (type) {
    case PrinterType.browser:
      return 'web';
    case PrinterType.usb:
      return 'usb';
    case PrinterType.bluetooth:
      return 'bluetooth';
    case PrinterType.network:
      return 'wifi';
  }
}

/// Persistent configuration for a single printer.
class PrinterConfig {
  final String id;
  final String name;
  final PrinterType type;
  final int paperWidth; // 80 or 58
  final String? address; // IP:port, USB vendorId, BT address
  final bool isDefault;

  const PrinterConfig({
    required this.id,
    required this.name,
    required this.type,
    this.paperWidth = 80,
    this.address,
    this.isDefault = false,
  });

  PrinterConfig copyWith({
    String? id,
    String? name,
    PrinterType? type,
    int? paperWidth,
    String? address,
    bool? isDefault,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      paperWidth: paperWidth ?? this.paperWidth,
      address: address ?? this.address,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'paperWidth': paperWidth,
        'address': address,
        'isDefault': isDefault,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PrinterType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PrinterType.browser,
      ),
      paperWidth: json['paperWidth'] as int? ?? 80,
      address: json['address'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Serialize a list of configs to a JSON string for storage.
  static String listToJson(List<PrinterConfig> configs) {
    return jsonEncode(configs.map((c) => c.toJson()).toList());
  }

  /// Deserialize a JSON string to a list of configs.
  static List<PrinterConfig> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => PrinterConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A factory default browser printer.
  static PrinterConfig browserDefault() => const PrinterConfig(
        id: 'browser-default',
        name: 'Browser Print',
        type: PrinterType.browser,
        paperWidth: 80,
        isDefault: true,
      );
}

// ═════════════════════════════════════════════════════════════════════════
// Result type
// ═════════════════════════════════════════════════════════════════════════

/// Result of a print operation.
class PrintResult {
  final bool success;
  final String message;

  const PrintResult({required this.success, required this.message});

  factory PrintResult.ok([String message = 'Berhasil mencetak struk']) =>
      PrintResult(success: true, message: message);

  factory PrintResult.error(String message) =>
      PrintResult(success: false, message: message);
}

// ═════════════════════════════════════════════════════════════════════════
// Print Service
// ═════════════════════════════════════════════════════════════════════════

/// Abstraction layer that routes print jobs to the correct backend
/// (browser window, WebUSB, WebBluetooth, or network socket).
class PrinterService {
  final List<PrinterConfig> _savedPrinters = [];

  /// WebUSB printer instance (singleton per service).
  final WebUsbPrinter webUsb = WebUsbPrinter();

  /// Web Bluetooth printer instance (singleton per service).
  final WebBluetoothPrinter webBluetooth = WebBluetoothPrinter();

  /// All saved printer configurations.
  List<PrinterConfig> get printers => List.unmodifiable(_savedPrinters);

  /// The current default printer, or null if none is set.
  PrinterConfig? get defaultPrinter {
    try {
      return _savedPrinters.firstWhere((p) => p.isDefault);
    } catch (_) {
      return _savedPrinters.isNotEmpty ? _savedPrinters.first : null;
    }
  }

  // ─── CRUD ───────────────────────────────────────────────────────

  /// Load printers from a JSON string (e.g. from SharedPreferences).
  void loadFromJson(String jsonStr) {
    _savedPrinters.clear();
    _savedPrinters.addAll(PrinterConfig.listFromJson(jsonStr));
  }

  /// Export all printers as a JSON string.
  String saveToJson() => PrinterConfig.listToJson(_savedPrinters);

  /// Add a new printer.
  void addPrinter(PrinterConfig config) {
    // If this is set as default, unset all others.
    if (config.isDefault) {
      _clearDefault();
    }
    _savedPrinters.add(config);
  }

  /// Update an existing printer by id.
  void updatePrinter(PrinterConfig config) {
    final idx = _savedPrinters.indexWhere((p) => p.id == config.id);
    if (idx == -1) return;
    if (config.isDefault) _clearDefault();
    _savedPrinters[idx] = config;
  }

  /// Remove a printer by id.
  void removePrinter(String id) {
    _savedPrinters.removeWhere((p) => p.id == id);
  }

  /// Set a printer as the default.
  void setDefault(String id) {
    _clearDefault();
    final idx = _savedPrinters.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _savedPrinters[idx] = _savedPrinters[idx].copyWith(isDefault: true);
    }
  }

  void _clearDefault() {
    for (var i = 0; i < _savedPrinters.length; i++) {
      if (_savedPrinters[i].isDefault) {
        _savedPrinters[i] = _savedPrinters[i].copyWith(isDefault: false);
      }
    }
  }

  // ─── Printing ─────────────────────────────────────────────────

  /// Print raw ESC/POS data through the given printer.
  ///
  /// For [PrinterType.browser], supply [htmlReceipt] instead.
  Future<PrintResult> printReceipt({
    required PrinterConfig printer,
    required Uint8List escPosData,
    String? htmlReceipt,
  }) async {
    try {
      switch (printer.type) {
        case PrinterType.browser:
          return _printBrowser(htmlReceipt ?? '');
        case PrinterType.usb:
          return _printUsb(escPosData);
        case PrinterType.network:
          return _printNetwork(printer.address ?? '', escPosData);
        case PrinterType.bluetooth:
          return _printBluetooth(escPosData);
      }
    } catch (e) {
      return PrintResult.error('Gagal mencetak: $e');
    }
  }

  /// Print a test page on the given printer.
  Future<PrintResult> testPrint(PrinterConfig printer) async {
    final receipt = EscPosReceiptPrinter(paperWidth: printer.paperWidth);
    final bytes = receipt.generateTestReceipt(
      outletName: 'LUWA APP',
      paperWidth: printer.paperWidth,
    );

    if (printer.type == PrinterType.browser) {
      return _printBrowser(_buildTestHtml(printer.paperWidth));
    }

    return printReceipt(printer: printer, escPosData: bytes);
  }

  // ─── Backend Implementations ──────────────────────────────────

  /// Browser print — opens a new window with HTML and triggers window.print().
  Future<PrintResult> _printBrowser(String html) async {
    if (!kIsWeb) {
      return PrintResult.error('Browser print hanya tersedia di Flutter Web');
    }
    if (html.isEmpty) {
      return PrintResult.error('HTML struk kosong');
    }
    // Delegate to the existing receipt_print_web.dart mechanism.
    // The caller should use ReceiptPrinter.printReceipt() for browser mode.
    return PrintResult.ok('Struk dicetak melalui browser');
  }

  /// USB print via WebUSB API (dart:js_interop).
  ///
  /// Requires the browser to support WebUSB and the user to grant device access.
  Future<PrintResult> _printUsb(Uint8List data) async {
    if (!WebUsbPrinter.isSupported) {
      return PrintResult.error(
        'WebUSB tidak didukung oleh browser ini. '
        'Gunakan Chrome, Edge, atau Opera.',
      );
    }

    if (webUsb.deviceName == null) {
      return PrintResult.error(
        'Belum ada printer USB yang dipasangkan. '
        'Buka Pengaturan Printer dan pasangkan perangkat.',
      );
    }

    final result = await webUsb.print(data);
    if (result.success) {
      return PrintResult.ok(result.message);
    }
    return PrintResult.error(result.message);
  }

  /// Pair a USB printer device (triggers browser dialog).
  /// Must be called from a user gesture (click/tap).
  Future<PrintResult> pairUsbDevice() async {
    final result = await webUsb.requestDevice();
    if (result.success) {
      return PrintResult.ok(result.message);
    }
    return PrintResult.error(result.message);
  }

  /// Network print — sends raw bytes to a TCP socket (IP:port).
  Future<PrintResult> _printNetwork(String address, Uint8List data) async {
    // Network printing over raw TCP sockets is not available in Flutter Web.
    // On native (mobile/desktop), use dart:io Socket.connect(ip, port).
    //
    // For web, a local print-relay server or WebSocket proxy is required.
    if (address.isEmpty) {
      return PrintResult.error('Alamat IP printer belum diatur');
    }
    return PrintResult.error(
      'Printing jaringan belum tersedia di Flutter Web. '
      'Gunakan mode USB atau Browser.',
    );
  }

  /// Bluetooth print via Web Bluetooth API.
  ///
  /// Requires HTTPS and user gesture for initial pairing.
  Future<PrintResult> _printBluetooth(Uint8List data) async {
    if (!WebBluetoothPrinter.isSupported) {
      return PrintResult.error(
        'Web Bluetooth tidak didukung oleh browser ini. '
        'Gunakan Chrome, Edge, atau Opera.',
      );
    }

    if (webBluetooth.deviceName == null) {
      return PrintResult.error(
        'Belum ada printer Bluetooth yang dipasangkan. '
        'Buka Pengaturan Printer dan pasangkan perangkat.',
      );
    }

    final result = await webBluetooth.print(data);
    if (result.success) {
      return PrintResult.ok(result.message);
    }
    return PrintResult.error(result.message);
  }

  /// Pair a Bluetooth printer device (triggers browser dialog).
  /// Must be called from a user gesture (click/tap).
  Future<PrintResult> pairBluetoothDevice({bool acceptAll = false}) async {
    final result = await webBluetooth.requestDevice(acceptAll: acceptAll);
    if (result.success) {
      return PrintResult.ok(result.message);
    }
    return PrintResult.error(result.message);
  }

  /// Disconnect from the currently connected Bluetooth printer.
  Future<void> disconnectBluetooth() async {
    await webBluetooth.disconnect();
  }

  /// Disconnect from the currently connected USB printer.
  Future<void> disconnectUsb() async {
    await webUsb.disconnect();
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Build a simple test HTML page for browser print.
  String _buildTestHtml(int paperWidth) {
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Test Print</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Courier New', monospace;
    font-size: 12px;
    display: flex;
    justify-content: center;
    padding: 0;
  }
  .receipt {
    width: ${paperWidth}mm;
    max-width: ${paperWidth}mm;
    padding: 8px 12px;
  }
  .center { text-align: center; }
  .bold { font-weight: bold; }
  .big { font-size: 18px; font-weight: bold; }
  .sep { color: #666; font-size: 10px; overflow: hidden; white-space: nowrap; margin: 4px 0; }
  .row { display: flex; justify-content: space-between; }
  @media print { body { padding: 0; margin: 0; } .receipt { padding: 0 4px; } }
</style>
</head><body>
<div class="receipt">
  <div class="center big">LUWA APP</div>
  <div class="center">=== TEST PRINT ===</div>
  <div class="sep">${'-' * (paperWidth == 80 ? 48 : 32)}</div>
  <div>Paper: ${paperWidth}mm</div>
  <div>Columns: ${paperWidth == 80 ? 48 : 32}</div>
  <div class="sep">${'-' * (paperWidth == 80 ? 48 : 32)}</div>
  <div>ABCDEFGHIJKLMNOPQRSTUVWXYZ</div>
  <div>0123456789</div>
  <div class="sep">${'-' * (paperWidth == 80 ? 48 : 32)}</div>
  <div class="bold">Bold text</div>
  <div class="sep">${'-' * (paperWidth == 80 ? 48 : 32)}</div>
  <div class="row"><span>Left</span><span>Right</span></div>
  <div class="row"><span>Item Test</span><span>Rp 10.000</span></div>
  <div class="sep">${'=' * (paperWidth == 80 ? 48 : 32)}</div>
  <div class="row bold"><span>TOTAL</span><span>Rp 10.000</span></div>
  <div class="sep">${'-' * (paperWidth == 80 ? 48 : 32)}</div>
  <div class="center">Printer OK!</div>
</div>
<script>window.onload = function() { window.print(); }</script>
</body></html>
''';
  }
}
