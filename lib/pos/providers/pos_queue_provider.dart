import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import 'pos_checkout_provider.dart';

// Use dart:js for Web Audio API instead of dart:html
import 'dart:js' as js if (dart.library.io) '';

// Sound notification service using Web Audio API
class OrderSoundService {
  static Future<void> playNewOrderSound() async {
    if (!kIsWeb) {
      debugPrint('🔇 OrderSound: Not on web, skipping sound');
      return;
    }

    try {
      debugPrint('🔔 OrderSound: Playing notification sound...');

      // Web Audio API beep sound using dart:js
      final audioContext = js.JsObject(js.context['AudioContext'] ?? js.context['webkitAudioContext']);
      final oscillator = audioContext.callMethod('createOscillator', []);
      final gainNode = audioContext.callMethod('createGain', []);

      oscillator.callMethod('connect', [gainNode]);
      gainNode.callMethod('connect', [audioContext['destination']]);

      oscillator['frequency']['value'] = 800; // Hz
      oscillator['type'] = 'sine';
      gainNode['gain']['value'] = 0.3;

      oscillator.callMethod('start', [0]);

      // Two beeps
      Future.delayed(const Duration(milliseconds: 200), () {
        gainNode['gain']['value'] = 0;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        gainNode['gain']['value'] = 0.3;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        oscillator.callMethod('stop', [0]);
        debugPrint('✅ OrderSound: Sound completed');
      });
    } catch (e) {
      debugPrint('❌ OrderSound: Error playing sound - $e');
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
// Uses ref.listen for TRUE REALTIME updates (not polling!)
class OrderQueueNotifier extends StateNotifier<int> {
  final Ref ref;

  OrderQueueNotifier(this.ref) : super(0) {
    // Listen to pending count changes for IMMEDIATE notification
    // This reacts instantly when Supabase realtime updates the provider
    ref.listen<int>(
      posPendingOrderCountProvider,
      (previous, current) {
        debugPrint('📊 OrderQueue: Pending count changed from $previous → $current');

        // If count increased AND we already had a previous state, play sound
        // Skip sound on initial load (previous == 0 means first load)
        if (current > previous && previous > 0) {
          debugPrint('🔔 OrderQueue: NEW ORDER DETECTED! Triggering sound notification');
          OrderSoundService.playNewOrderSound();
        } else if (current > previous && previous == 0) {
          debugPrint('ℹ️ OrderQueue: Initial load, skipping sound');
        } else if (current < previous) {
          debugPrint('✅ OrderQueue: Order accepted/completed (count decreased)');
        }

        // Update state
        state = current;
      },
      fireImmediately: true,
    );
  }
}

final orderQueueNotifierProvider = StateNotifierProvider<OrderQueueNotifier, int>((ref) {
  return OrderQueueNotifier(ref);
});
