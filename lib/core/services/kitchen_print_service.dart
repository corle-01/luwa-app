import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/order.dart';
import '../../pos/widgets/receipt_print_web.dart' if (dart.library.io) '';
import 'escpos_generator.dart';
import 'printer_service.dart';

// ═════════════════════════════════════════════════════════════════════════
// Kitchen Printer Configuration
// ═════════════════════════════════════════════════════════════════════════

/// Stores kitchen printing preferences in SharedPreferences.
class KitchenPrintConfig {
  /// Whether auto-print is enabled for new orders.
  final bool autoprint;

  /// The printer ID to use for kitchen tickets (null = default printer).
  final String? kitchenPrinterId;

  const KitchenPrintConfig({
    this.autoprint = false,
    this.kitchenPrinterId,
  });

  KitchenPrintConfig copyWith({
    bool? autoprint,
    String? kitchenPrinterId,
  }) {
    return KitchenPrintConfig(
      autoprint: autoprint ?? this.autoprint,
      kitchenPrinterId: kitchenPrinterId ?? this.kitchenPrinterId,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoprint': autoprint,
        'kitchenPrinterId': kitchenPrinterId,
      };

  factory KitchenPrintConfig.fromJson(Map<String, dynamic> json) {
    return KitchenPrintConfig(
      autoprint: json['autoprint'] as bool? ?? false,
      kitchenPrinterId: json['kitchenPrinterId'] as String?,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Kitchen Print Service
// ═════════════════════════════════════════════════════════════════════════

/// Manages kitchen ticket printing: auto-print on order creation,
/// manual reprint from KDS, and kitchen printer configuration.
class KitchenPrintService {
  static const _prefsKey = 'kitchen_print_config';

  KitchenPrintConfig _config = const KitchenPrintConfig();
  final PrinterService _printerService;

  KitchenPrintService(this._printerService);

  /// Current configuration.
  KitchenPrintConfig get config => _config;

  /// Whether auto-print is currently enabled.
  bool get isAutoPrintEnabled => _config.autoprint;

  /// Load config from SharedPreferences.
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        _config = KitchenPrintConfig.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  /// Save config to SharedPreferences.
  Future<void> saveConfig(KitchenPrintConfig config) async {
    _config = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  /// Toggle auto-print on/off. Returns the new state.
  Future<bool> toggleAutoprint() async {
    final newConfig = _config.copyWith(autoprint: !_config.autoprint);
    await saveConfig(newConfig);
    return newConfig.autoprint;
  }

  /// Set the kitchen printer by ID.
  Future<void> setKitchenPrinter(String? printerId) async {
    await saveConfig(_config.copyWith(kitchenPrinterId: printerId));
  }

  /// Get the kitchen printer config. Falls back to default printer.
  PrinterConfig? get kitchenPrinter {
    if (_config.kitchenPrinterId != null) {
      try {
        return _printerService.printers
            .firstWhere((p) => p.id == _config.kitchenPrinterId);
      } catch (_) {}
    }
    return _printerService.defaultPrinter;
  }

  /// All available printers for kitchen selection.
  List<PrinterConfig> get availablePrinters => _printerService.printers;

  /// Look up station ('kitchen' or 'bar') for each product by joining
  /// products → categories. Returns a map of productId → station.
  Future<Map<String, String>> _getProductStations(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, categories(station)')
          .inFilter('id', productIds);
      final map = <String, String>{};
      for (final row in response as List) {
        final id = row['id'] as String;
        final cat = row['categories'] as Map<String, dynamic>?;
        map[id] = cat?['station'] as String? ?? 'kitchen';
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Print a kitchen ticket for an order.
  Future<bool> printKitchenTicket({
    required String orderNumber,
    required String orderType,
    required DateTime dateTime,
    required List<OrderItem> items,
    String? tableName,
    String? cashierName,
    String? notes,
  }) async {
    final printer = kitchenPrinter;
    if (printer == null) return false;

    // Look up station for each product
    final productIds = items
        .map((i) => i.productId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final stationMap = await _getProductStations(productIds);

    // Build kitchen ticket items
    final ticketItems = items.map((item) {
      List<String>? mods;
      if (item.modifiers != null && item.modifiers!.isNotEmpty) {
        mods = item.modifiers!
            .map((m) => '${m['group_name']}: ${m['option_name']}')
            .toList();
      }
      return KitchenTicketItem(
        name: item.productName,
        qty: item.quantity,
        modifiers: mods,
        notes: item.notes,
        station: stationMap[item.productId] ?? 'kitchen',
      );
    }).toList();

    try {
      if (printer.type == PrinterType.browser) {
        final ticket = EscPosKitchenTicket(paperWidth: printer.paperWidth);
        final html = ticket.generateHtmlTicket(
          orderNumber: orderNumber,
          orderType: orderType,
          dateTime: dateTime,
          items: ticketItems,
          paperWidth: printer.paperWidth,
          tableName: tableName,
          cashierName: cashierName,
          notes: notes,
        );
        if (kIsWeb) {
          openPrintWindow(html);
          return true;
        }
        return false;
      } else {
        final ticket = EscPosKitchenTicket(paperWidth: printer.paperWidth);
        final bytes = ticket.generateTicket(
          orderNumber: orderNumber,
          orderType: orderType,
          dateTime: dateTime,
          items: ticketItems,
          tableName: tableName,
          cashierName: cashierName,
          notes: notes,
        );
        final result = await _printerService.printReceipt(
          printer: printer,
          escPosData: bytes,
        );
        return result.success;
      }
    } catch (_) {
      return false;
    }
  }

  /// Auto-print if enabled. Called after successful order creation.
  Future<void> autoPrintIfEnabled({
    required String orderNumber,
    required String orderType,
    required DateTime dateTime,
    required List<OrderItem> items,
    String? tableName,
    String? cashierName,
    String? notes,
  }) async {
    if (!_config.autoprint) return;
    await printKitchenTicket(
      orderNumber: orderNumber,
      orderType: orderType,
      dateTime: dateTime,
      items: items,
      tableName: tableName,
      cashierName: cashierName,
      notes: notes,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Riverpod Providers
// ═════════════════════════════════════════════════════════════════════════

final kitchenPrintServiceProvider = Provider<KitchenPrintService>((ref) {
  final printerService = PrinterService();
  // Ensure browser-default printer is always available
  printerService.addPrinter(PrinterConfig.browserDefault());
  final service = KitchenPrintService(printerService);
  // Load kitchen config (async but fire-and-forget — config
  // will be ready by the time the user submits an order)
  service.loadConfig();
  return service;
});
