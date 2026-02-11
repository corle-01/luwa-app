import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/order.dart';
import 'pos_checkout_provider.dart';

// Use dart:js for Web Audio API instead of dart:html
import 'dart:js' as js if (dart.library.io) '';

// Sound notification service using Web Audio API
class OrderSoundService {
  static Future<void> playNewOrderSound() async {
    if (!kIsWeb) return;

    try {
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

// Real-time notification provider using ref.listen
// This provider auto-initializes and triggers sound on order count changes
final orderNotificationInitializerProvider = Provider<void>((ref) {
  debugPrint('🔧 OrderNotification: Initializer provider created');

  // Listen to pending count changes - THIS WORKS in Provider (not StateNotifier)!
  ref.listen<int>(
    posPendingOrderCountProvider,
    (previous, current) {
      debugPrint('📊 OrderNotification: Count changed - previous: $previous, current: $current');

      // Skip initial load (when previous is null)
      if (previous == null) {
        debugPrint('ℹ️ OrderNotification: Initial load, current count: $current');
        return;
      }

      // If count increased, play sound
      if (current > previous) {
        // Only skip sound if this is the very first count (0 -> n)
        if (previous == 0) {
          debugPrint('⚠️ OrderNotification: First load after 0, skipping sound (0 → $current)');
        } else {
          debugPrint('🔔 OrderNotification: NEW ORDER DETECTED! Playing sound ($previous → $current)');
          OrderSoundService.playNewOrderSound();
        }
      } else if (current < previous) {
        debugPrint('✅ OrderNotification: Order accepted/completed (count decreased: $previous → $current)');
      } else {
        debugPrint('➡️ OrderNotification: No change in count');
      }
    },
    fireImmediately: false,
  );

  debugPrint('✅ OrderNotification: Listener setup complete');
  // Return void - this provider's job is just to set up the listener
  return;
});

// Simple state provider to expose pending count to UI
final orderQueueCountProvider = Provider<int>((ref) {
  // Initialize the notification listener
  ref.watch(orderNotificationInitializerProvider);

  // Return current pending count
  return ref.watch(posPendingOrderCountProvider);
});
