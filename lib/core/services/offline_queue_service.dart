import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

// ---------------------------------------------------------------------------
// Queue operation types
// ---------------------------------------------------------------------------

/// The kinds of operations that can be queued while offline.
enum QueueOperationType {
  createOrder,
  updateOrderStatus,
  other,
}

// ---------------------------------------------------------------------------
// Queued operation model
// ---------------------------------------------------------------------------

/// Represents a single pending operation stored in the offline queue.
///
/// Each operation carries its own [data] payload and a [type] that determines
/// how it will be replayed against Supabase when the connection is restored.
class QueuedOperation {
  final String id;
  final QueueOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  bool isSyncing;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.isSyncing = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) =>
      QueuedOperation(
        id: json['id'] as String,
        type: QueueOperationType.values
            .firstWhere((e) => e.name == json['type']),
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// Sync result
// ---------------------------------------------------------------------------

/// Result returned after processing the queue.
class SyncResult {
  final int synced;
  final int failed;
  final List<String> errors;

  SyncResult({
    required this.synced,
    required this.failed,
    this.errors = const [],
  });

  bool get hasFailures => failed > 0;
  bool get allSucceeded => failed == 0 && synced > 0;

  @override
  String toString() =>
      'SyncResult(synced: $synced, failed: $failed, errors: $errors)';
}

// ---------------------------------------------------------------------------
// Offline queue service (StateNotifier)
// ---------------------------------------------------------------------------

/// Manages an in-memory queue of operations that were created while offline.
///
/// When the device goes offline, order-creation and status-update calls
/// are captured here instead of being sent directly to Supabase. When the
/// connection is restored the [SyncService] calls [syncAll] to replay them.
///
/// The queue follows the critical order-flow rule:
///   INSERT as 'pending'  -->  INSERT items  -->  UPDATE to 'completed'
/// so that database triggers fire correctly.
class OfflineQueueService extends StateNotifier<List<QueuedOperation>> {
  static const _storageKey = 'utter_offline_queue';

  OfflineQueueService() : super([]) {
    _loadFromStorage();
  }

  // -- localStorage persistence --------------------------------------------

  /// Load queued operations from localStorage on startup so data survives
  /// page refreshes.
  void _loadFromStorage() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final ops = decoded
            .map((e) =>
                QueuedOperation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (ops.isNotEmpty) {
          state = ops;
        }
      }
    } catch (_) {
      // Corrupted data — start fresh
    }
  }

  /// Persist the current queue to localStorage.
  void _saveToStorage() {
    try {
      final encoded = jsonEncode(state.map((op) => op.toJson()).toList());
      web.window.localStorage.setItem(_storageKey, encoded);
    } catch (_) {
      // Storage full or unavailable — best effort
    }
  }

  // -- Queue management -----------------------------------------------------

  /// Add an operation to the end of the queue.
  void enqueue(QueuedOperation op) {
    state = [...state, op];
    _saveToStorage();
  }

  /// Remove an operation by its [operationId] after successful sync.
  void dequeue(String operationId) {
    state = state.where((op) => op.id != operationId).toList();
    _saveToStorage();
  }

  /// Number of operations that are not currently being synced.
  int get pendingCount => state.where((op) => !op.isSyncing).length;

  /// Total number of operations in the queue.
  int get totalCount => state.length;

  /// Whether the queue is empty.
  bool get isEmpty => state.isEmpty;

  /// Clear the entire queue.
  void clearAll() {
    state = [];
    _saveToStorage();
  }

  // -- Sync all queued operations --------------------------------------------

  /// Process every queued operation in FIFO order.
  ///
  /// Returns a [SyncResult] with counts of successful and failed operations.
  /// Failed operations remain in the queue for the next sync attempt.
  Future<SyncResult> syncAll() async {
    if (state.isEmpty) {
      return SyncResult(synced: 0, failed: 0);
    }

    final client = Supabase.instance.client;
    int synced = 0;
    int failed = 0;
    final errors = <String>[];

    // Iterate over a copy so we can safely mutate state inside the loop.
    for (final op in List<QueuedOperation>.from(state)) {
      try {
        op.isSyncing = true;
        // Force a state update so the UI can show progress
        state = [...state];
        _saveToStorage();

        switch (op.type) {
          case QueueOperationType.createOrder:
            await _syncCreateOrder(client, op.data);
            synced++;
            break;
          case QueueOperationType.updateOrderStatus:
            await _syncUpdateStatus(client, op.data);
            synced++;
            break;
          case QueueOperationType.other:
            // Generic / no-op; just mark as synced
            synced++;
            break;
        }

        dequeue(op.id);
      } catch (e) {
        op.isSyncing = false;
        failed++;
        errors.add('${op.type.name}: $e');
      }
    }

    return SyncResult(synced: synced, failed: failed, errors: errors);
  }

  // -- Private sync helpers --------------------------------------------------

  /// Replay a createOrder operation.
  ///
  /// Follows the INSERT pending -> INSERT items -> UPDATE completed flow
  /// so that database triggers (deduct_stock, update_shift, update_customer)
  /// fire on the UPDATE transition.
  Future<void> _syncCreateOrder(
    SupabaseClient client,
    Map<String, dynamic> data,
  ) async {
    final orderData = Map<String, dynamic>.from(data['order'] as Map);
    final itemsData = List<Map<String, dynamic>>.from(
      (data['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // Attempt to generate order number from the server RPC
    try {
      final result = await client.rpc(
        'generate_order_number',
        params: {'p_outlet_id': orderData['outlet_id']},
      );
      if (result != null) {
        orderData['order_number'] = result as String;
      }
    } catch (_) {
      // Keep the locally generated order number if RPC fails
    }

    // Step 1: INSERT order as 'pending'
    orderData['status'] = 'pending';
    orderData['payment_status'] = 'unpaid';
    // Remove local ID so Supabase generates a proper server-side UUID
    orderData.remove('id');
    // Remove created_at so server uses its default now()
    orderData.remove('created_at');

    final orderRes = await client
        .from('orders')
        .insert(orderData)
        .select('id')
        .single();
    final orderId = orderRes['id'] as String;

    // Step 2: INSERT order items linked to the new order
    for (final item in itemsData) {
      item['order_id'] = orderId;
    }
    await client.from('order_items').insert(itemsData);

    // Step 3: UPDATE to 'completed' so triggers fire
    await client
        .from('orders')
        .update({
          'status': 'completed',
          'payment_status': 'paid',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  /// Replay an updateOrderStatus operation.
  Future<void> _syncUpdateStatus(
    SupabaseClient client,
    Map<String, dynamic> data,
  ) async {
    await client
        .from('orders')
        .update({
          'status': data['status'] as String,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', data['order_id'] as String);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// The offline queue holding pending operations.
final offlineQueueProvider =
    StateNotifierProvider<OfflineQueueService, List<QueuedOperation>>((ref) {
  return OfflineQueueService();
});

/// Convenience provider: number of pending (not currently syncing) operations.
final pendingQueueCountProvider = Provider<int>((ref) {
  final queue = ref.watch(offlineQueueProvider);
  return queue.where((op) => !op.isSyncing).length;
});

/// Convenience provider: total queue size (including currently syncing).
final totalQueueCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueProvider).length;
});
