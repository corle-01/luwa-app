import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import 'pos_checkout_provider.dart';

// Conditional import for Web Audio API
import 'dart:html' as html show AudioContext, OscillatorNode, GainNode
    if (dart.library.io) '';

// Sound notification service using Web Audio API
class OrderSoundService {
  static Future<void> playNewOrderSound() async {
    if (!kIsWeb) return;

    try {
      // Web Audio API beep sound
      final audioContext = html.AudioContext();
      final oscillator = audioContext.createOscillator();
      final gainNode = audioContext.createGain();

      oscillator.connectNode(gainNode);
      gainNode.connectNode(audioContext.destination);

      oscillator.frequency!.value = 800; // Hz
      oscillator.type = 'sine';
      gainNode.gain!.value = 0.3;

      oscillator.start(0);

      // Two beeps
      Future.delayed(const Duration(milliseconds: 200), () {
        gainNode.gain!.value = 0;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        gainNode.gain!.value = 0.3;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        oscillator.stop(0);
      });
    } catch (e) {
      // Silent fail if Web Audio API not available
    }
  }
}

// Provider for pending orders count (for badge)
final posPendingOrderCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(
    data: (orders) => orders.where((o) => o.status == 'pending').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Provider for pending orders list
final posPendingOrdersProvider = Provider<List<Order>>((ref) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(
    data: (orders) {
      final pending = orders.where((o) => o.status == 'pending').toList();
      // Sort by created_at descending (newest first)
      pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pending;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for completed orders list (for queue history)
final posCompletedOrdersProvider = Provider<List<Order>>((ref) {
  final ordersAsync = ref.watch(posTodayOrdersProvider);
  return ordersAsync.when(
    data: (orders) {
      final completed = orders.where((o) => o.status == 'completed').toList();
      // Sort by created_at descending (newest first)
      completed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return completed;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Notifier to track previous order count and trigger sound
class OrderQueueNotifier extends StateNotifier<int> {
  final Ref ref;
  Timer? _checkTimer;

  OrderQueueNotifier(this.ref) : super(0) {
    _startWatching();
  }

  void _startWatching() {
    // Check every 3 seconds for new pending orders
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final currentCount = ref.read(posPendingOrderCountProvider);

      // If count increased, play sound
      if (currentCount > state && state > 0) {
        OrderSoundService.playNewOrderSound();
      }

      state = currentCount;
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

final orderQueueNotifierProvider = StateNotifierProvider<OrderQueueNotifier, int>((ref) {
  return OrderQueueNotifier(ref);
});
