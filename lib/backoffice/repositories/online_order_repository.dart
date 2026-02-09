import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/date_utils.dart';

// ============================================================
// Models
// ============================================================

class PlatformConfig {
  final String id;
  final String outletId;
  final String platform;
  final bool isEnabled;
  final String? storeId;
  final String? apiKey;
  final String? webhookUrl;
  final bool autoAccept;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlatformConfig({
    required this.id,
    required this.outletId,
    required this.platform,
    this.isEnabled = false,
    this.storeId,
    this.apiKey,
    this.webhookUrl,
    this.autoAccept = false,
    this.settings = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    return PlatformConfig(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      platform: json['platform'] as String,
      isEnabled: json['is_enabled'] as bool? ?? false,
      storeId: json['store_id'] as String?,
      apiKey: json['api_key'] as String?,
      webhookUrl: json['webhook_url'] as String?,
      autoAccept: json['auto_accept'] as bool? ?? false,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Display name for the platform
  String get displayName {
    switch (platform) {
      case 'gofood':
        return 'GoFood';
      case 'grabfood':
        return 'GrabFood';
      case 'shopeefood':
        return 'ShopeeFood';
      default:
        return platform;
    }
  }

  /// Commission rate from settings (percentage)
  double get commissionRate {
    return (settings['commission_rate'] as num?)?.toDouble() ?? 0;
  }
}

class OnlineOrder {
  final String id;
  final String outletId;
  final String? orderId; // linked internal order
  final String platform;
  final String platformOrderId;
  final String? platformOrderNumber;
  final String status;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final double deliveryFee;
  final double platformFee;
  final double subtotal;
  final double total;
  final List<Map<String, dynamic>> items;
  final String? driverName;
  final String? driverPhone;
  final String? notes;
  final Map<String, dynamic> rawData;
  final DateTime? acceptedAt;
  final DateTime? preparedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OnlineOrder({
    required this.id,
    required this.outletId,
    this.orderId,
    required this.platform,
    required this.platformOrderId,
    this.platformOrderNumber,
    this.status = 'incoming',
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.deliveryFee = 0,
    this.platformFee = 0,
    this.subtotal = 0,
    this.total = 0,
    this.items = const [],
    this.driverName,
    this.driverPhone,
    this.notes,
    this.rawData = const {},
    this.acceptedAt,
    this.preparedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory OnlineOrder.fromJson(Map<String, dynamic> json) {
    return OnlineOrder(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      orderId: json['order_id'] as String?,
      platform: json['platform'] as String,
      platformOrderId: json['platform_order_id'] as String,
      platformOrderNumber: json['platform_order_number'] as String?,
      status: json['status'] as String? ?? 'incoming',
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerAddress: json['customer_address'] as String?,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(
              (json['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : [],
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      notes: json['notes'] as String?,
      rawData: json['raw_data'] != null
          ? Map<String, dynamic>.from(json['raw_data'] as Map)
          : {},
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      preparedAt: json['prepared_at'] != null
          ? DateTime.parse(json['prepared_at'] as String)
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Display name for the platform
  String get platformDisplayName {
    switch (platform) {
      case 'gofood':
        return 'GoFood';
      case 'grabfood':
        return 'GrabFood';
      case 'shopeefood':
        return 'ShopeeFood';
      default:
        return platform;
    }
  }

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case 'incoming':
        return 'Pesanan Masuk';
      case 'accepted':
        return 'Diterima';
      case 'preparing':
        return 'Sedang Disiapkan';
      case 'ready':
        return 'Siap Diambil';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }
}

class OnlineOrderStats {
  final int totalOrders;
  final double totalRevenue;
  final Map<String, int> ordersByPlatform;
  final Map<String, double> revenueByPlatform;
  final Map<String, int> ordersByStatus;
  final double avgOrderValue;

  OnlineOrderStats({
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.ordersByPlatform = const {},
    this.revenueByPlatform = const {},
    this.ordersByStatus = const {},
    this.avgOrderValue = 0,
  });
}

// ============================================================
// Filter model
// ============================================================

class OnlineOrderFilter {
  final String? platform;
  final String? status;

  const OnlineOrderFilter({this.platform, this.status});

  OnlineOrderFilter copyWith({
    String? platform,
    String? status,
    bool clearPlatform = false,
    bool clearStatus = false,
  }) {
    return OnlineOrderFilter(
      platform: clearPlatform ? null : (platform ?? this.platform),
      status: clearStatus ? null : (status ?? this.status),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineOrderFilter &&
          platform == other.platform &&
          status == other.status;

  @override
  int get hashCode => platform.hashCode ^ status.hashCode;
}

// ============================================================
// Repository
// ============================================================

class OnlineOrderRepository {
  final _supabase = Supabase.instance.client;

  // ----------------------------------------------------------
  // Platform Configs
  // ----------------------------------------------------------

  /// Get all platform configurations for an outlet
  Future<List<PlatformConfig>> getPlatformConfigs(String outletId) async {
    final response = await _supabase
        .from('platform_configs')
        .select()
        .eq('outlet_id', outletId)
        .order('platform', ascending: true);

    return (response as List)
        .map((json) => PlatformConfig.fromJson(json))
        .toList();
  }

  /// Update a platform configuration
  Future<void> updatePlatformConfig(
      String configId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTimeUtils.nowUtc();
    await _supabase
        .from('platform_configs')
        .update(data)
        .eq('id', configId);
  }

  // ----------------------------------------------------------
  // Online Orders — CRUD
  // ----------------------------------------------------------

  /// Get online orders with optional filters
  Future<List<OnlineOrder>> getOnlineOrders({
    required String outletId,
    String? platform,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var query = _supabase
        .from('online_orders')
        .select()
        .eq('outlet_id', outletId);

    if (platform != null && platform.isNotEmpty) {
      query = query.eq('platform', platform);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (dateFrom != null) {
      query = query.gte('created_at', DateTimeUtils.toUtcIso(dateFrom));
    }
    if (dateTo != null) {
      query = query.lte('created_at', DateTimeUtils.endOfDayUtc(dateTo));
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => OnlineOrder.fromJson(json))
        .toList();
  }

  /// Get a single online order by ID
  Future<OnlineOrder?> getOnlineOrderDetail(String onlineOrderId) async {
    final response = await _supabase
        .from('online_orders')
        .select()
        .eq('id', onlineOrderId)
        .maybeSingle();

    if (response == null) return null;
    return OnlineOrder.fromJson(response);
  }

  // ----------------------------------------------------------
  // Accept Order
  // ----------------------------------------------------------

  /// Accept an incoming online order:
  /// 1. Fetch the online order data
  /// 2. Create an internal order in `orders` table (status='pending', source=platform)
  /// 3. Create order_items from the online order's items JSONB
  /// 4. Update the online_order: set order_id, status='accepted', accepted_at
  Future<void> acceptOrder(String onlineOrderId) async {
    // Step 1: Get the online order
    final onlineOrderRes = await _supabase
        .from('online_orders')
        .select()
        .eq('id', onlineOrderId)
        .single();

    final onlineOrder = OnlineOrder.fromJson(onlineOrderRes);

    if (onlineOrder.status != 'incoming') {
      throw Exception('Order is not in incoming status — cannot accept');
    }

    // Use same order sequence as POS
    String orderNumber;
    try {
      final result = await _supabase.rpc('generate_order_number',
          params: {'p_outlet_id': onlineOrder.outletId});
      orderNumber = result as String? ??
          'ORD-${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Step 2: Create internal order as 'pending'
    // Note: We insert as 'pending' first. The order stays pending until
    // kitchen prepares it and cashier completes payment flow.
    // DB triggers fire on UPDATE (pending -> completed), not INSERT.
    final orderRes = await _supabase
        .from('orders')
        .insert({
          'outlet_id': onlineOrder.outletId,
          'order_number': orderNumber,
          'order_type': 'delivery',
          'status': 'pending',
          'payment_method': 'online',
          'payment_status': 'paid', // Online orders are pre-paid
          'subtotal': onlineOrder.subtotal,
          'discount_amount': 0,
          'tax_amount': 0,
          'service_charge_amount': 0,
          'total': onlineOrder.total,
          'amount_paid': onlineOrder.total,
          'change_amount': 0,
          'notes':
              '${onlineOrder.platformDisplayName} - ${onlineOrder.platformOrderNumber ?? onlineOrder.platformOrderId}${onlineOrder.notes != null ? '\n${onlineOrder.notes}' : ''}',
          'source': onlineOrder.platform,
        })
        .select('id')
        .single();

    final internalOrderId = orderRes['id'] as String;

    // Step 3: Create order_items from the online order items JSONB
    if (onlineOrder.items.isNotEmpty) {
      final orderItems = onlineOrder.items.map((item) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = (item['price'] as num?)?.toDouble() ?? 0;
        final itemSubtotal = unitPrice * qty;

        return {
          'order_id': internalOrderId,
          'product_id': item['product_id'] as String? ??
              '00000000-0000-0000-0000-000000000000',
          'product_name': item['name'] as String? ?? 'Unknown Item',
          'quantity': qty,
          'unit_price': unitPrice,
          'subtotal': itemSubtotal,
          'discount_amount': 0,
          'total': itemSubtotal,
          'notes': item['notes'] as String?,
          'modifiers': item['modifiers'] ?? [],
          'kitchen_status': 'pending',
        };
      }).toList();

      await _supabase.from('order_items').insert(orderItems);
    }

    // Step 4: Update online_order — link to internal order and mark accepted
    await _supabase
        .from('online_orders')
        .update({
          'order_id': internalOrderId,
          'status': 'accepted',
          'accepted_at': DateTimeUtils.nowUtc(),
          'updated_at': DateTimeUtils.nowUtc(),
        })
        .eq('id', onlineOrderId);
  }

  // ----------------------------------------------------------
  // Reject Order
  // ----------------------------------------------------------

  /// Reject an incoming online order with an optional reason
  Future<void> rejectOrder(String onlineOrderId, String? reason) async {
    await _supabase
        .from('online_orders')
        .update({
          'status': 'rejected',
          'notes': reason,
          'cancelled_at': DateTimeUtils.nowUtc(),
          'updated_at': DateTimeUtils.nowUtc(),
        })
        .eq('id', onlineOrderId);
  }

  // ----------------------------------------------------------
  // Update Status
  // ----------------------------------------------------------

  /// Update the status of an online order (preparing, ready, picked_up, etc.)
  Future<void> updateOrderStatus(
      String onlineOrderId, String status) async {
    final data = <String, dynamic>{
      'status': status,
      'updated_at': DateTimeUtils.nowUtc(),
    };

    // Set timestamp fields based on status transition
    switch (status) {
      case 'preparing':
        data['prepared_at'] = DateTimeUtils.nowUtc();
        break;
      case 'ready':
        // prepared_at stays from when preparing started
        break;
      case 'picked_up':
        data['picked_up_at'] = DateTimeUtils.nowUtc();
        break;
      case 'delivered':
        data['delivered_at'] = DateTimeUtils.nowUtc();
        break;
      case 'cancelled':
        data['cancelled_at'] = DateTimeUtils.nowUtc();
        break;
    }

    await _supabase
        .from('online_orders')
        .update(data)
        .eq('id', onlineOrderId);
  }

  // ----------------------------------------------------------
  // Stats
  // ----------------------------------------------------------

  /// Get aggregated online order statistics for a date range
  Future<OnlineOrderStats> getOnlineOrderStats(
    String outletId,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final response = await _supabase
        .from('online_orders')
        .select()
        .eq('outlet_id', outletId)
        .gte('created_at', DateTimeUtils.toUtcIso(dateFrom))
        .lte('created_at', DateTimeUtils.endOfDayUtc(dateTo));

    final orders = (response as List)
        .map((json) => OnlineOrder.fromJson(json))
        .toList();

    if (orders.isEmpty) {
      return OnlineOrderStats();
    }

    // Aggregate by platform
    final ordersByPlatform = <String, int>{};
    final revenueByPlatform = <String, double>{};
    final ordersByStatus = <String, int>{};
    double totalRevenue = 0;

    for (final order in orders) {
      // By platform
      ordersByPlatform[order.platform] =
          (ordersByPlatform[order.platform] ?? 0) + 1;
      revenueByPlatform[order.platform] =
          (revenueByPlatform[order.platform] ?? 0) + order.total;

      // By status
      ordersByStatus[order.status] =
          (ordersByStatus[order.status] ?? 0) + 1;

      totalRevenue += order.total;
    }

    return OnlineOrderStats(
      totalOrders: orders.length,
      totalRevenue: totalRevenue,
      ordersByPlatform: ordersByPlatform,
      revenueByPlatform: revenueByPlatform,
      ordersByStatus: ordersByStatus,
      avgOrderValue: orders.isNotEmpty ? totalRevenue / orders.length : 0,
    );
  }

  // ----------------------------------------------------------
  // Simulate Incoming Order (FOR TESTING)
  // ----------------------------------------------------------

  /// Creates a fake incoming order with random items for testing purposes.
  /// This simulates what would happen when a webhook receives an order
  /// from GoFood/GrabFood/ShopeeFood.
  Future<OnlineOrder> simulateIncomingOrder(
    String outletId,
    String platform,
  ) async {
    final random = Random();

    // Fake menu items per platform
    final fakeMenuItems = {
      'gofood': [
        {'name': 'Nasi Goreng Spesial', 'price': 25000},
        {'name': 'Mie Ayam Bakso', 'price': 20000},
        {'name': 'Ayam Geprek', 'price': 18000},
        {'name': 'Es Teh Manis', 'price': 5000},
        {'name': 'Soto Ayam', 'price': 22000},
      ],
      'grabfood': [
        {'name': 'Chicken Katsu Rice', 'price': 30000},
        {'name': 'Beef Teriyaki', 'price': 35000},
        {'name': 'Ramen Miso', 'price': 28000},
        {'name': 'Ocha', 'price': 8000},
        {'name': 'Gyoza (5 pcs)', 'price': 15000},
      ],
      'shopeefood': [
        {'name': 'Nasi Padang Komplit', 'price': 27000},
        {'name': 'Rendang Sapi', 'price': 32000},
        {'name': 'Sate Ayam (10)', 'price': 25000},
        {'name': 'Es Jeruk', 'price': 6000},
        {'name': 'Bakso Urat', 'price': 20000},
      ],
    };

    final menuItems = fakeMenuItems[platform] ?? fakeMenuItems['gofood']!;

    // Pick 1-4 random items
    final itemCount = random.nextInt(4) + 1;
    final selectedItems = <Map<String, dynamic>>[];
    double subtotal = 0;

    for (int i = 0; i < itemCount; i++) {
      final menuItem = menuItems[random.nextInt(menuItems.length)];
      final qty = random.nextInt(3) + 1;
      final price = (menuItem['price'] as num).toDouble();
      subtotal += price * qty;

      selectedItems.add({
        'name': menuItem['name'],
        'price': price,
        'quantity': qty,
        'notes': random.nextBool() ? 'Extra pedas' : null,
        'modifiers': [],
      });
    }

    final deliveryFee = (random.nextInt(3) + 1) * 5000.0;
    final platformFee = subtotal * 0.05; // 5% platform fee
    final total = subtotal + deliveryFee;

    // Fake customer names
    final customerNames = [
      'Budi Santoso',
      'Siti Rahayu',
      'Ahmad Hidayat',
      'Dewi Lestari',
      'Rizki Pratama',
      'Rina Wati',
      'Agus Setiawan',
      'Fitri Handayani',
    ];

    final fakeAddresses = [
      'Jl. Sudirman No. 45, Jakarta Selatan',
      'Jl. Gatot Subroto Kav. 12, Jakarta Pusat',
      'Jl. Thamrin No. 88, Jakarta Pusat',
      'Jl. Kemang Raya No. 23, Jakarta Selatan',
      'Jl. Menteng Dalam No. 7, Jakarta Selatan',
    ];

    final fakeDriverNames = [
      'Pak Joko',
      'Mas Andi',
      'Bang Deni',
      'Pak Hendra',
      'Mas Fajar',
    ];

    final platformPrefix = platform == 'gofood'
        ? 'GF'
        : platform == 'grabfood'
            ? 'GB'
            : 'SF';
    final platformOrderId =
        '$platformPrefix-${DateTime.now().millisecondsSinceEpoch}';
    final platformOrderNumber =
        '$platformPrefix-${random.nextInt(9000) + 1000}';

    final customerName = customerNames[random.nextInt(customerNames.length)];
    final customerPhone = '08${random.nextInt(900000000) + 100000000}';
    final customerAddress = fakeAddresses[random.nextInt(fakeAddresses.length)];
    final driverName = fakeDriverNames[random.nextInt(fakeDriverNames.length)];
    final driverPhone = '08${random.nextInt(900000000) + 100000000}';

    final response = await _supabase
        .from('online_orders')
        .insert({
          'outlet_id': outletId,
          'platform': platform,
          'platform_order_id': platformOrderId,
          'platform_order_number': platformOrderNumber,
          'status': 'incoming',
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address': customerAddress,
          'delivery_fee': deliveryFee,
          'platform_fee': platformFee,
          'subtotal': subtotal,
          'total': total,
          'items': selectedItems,
          'driver_name': driverName,
          'driver_phone': driverPhone,
          'notes': random.nextBool()
              ? 'Tolong jangan pakai plastik'
              : null,
          'raw_data': {
            'simulated': true,
            'platform': platform,
            'created_by': 'simulator',
          },
        })
        .select()
        .single();

    return OnlineOrder.fromJson(response);
  }
}
