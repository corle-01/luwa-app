import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'offline_queue_service.dart';

// ---------------------------------------------------------------------------
// Sync Service
// ---------------------------------------------------------------------------

/// Orchestrates offline queue synchronization with the Supabase backend.
///
/// Listens to [ConnectivityService] status changes and automatically processes
/// the offline queue when the connection transitions from offline to online.
/// Also exposes methods for manual sync and provides snackbar-style
/// notifications via a [GlobalKey<ScaffoldMessengerState>].
class SyncService {
  final Ref _ref;
  StreamSubscription<ConnectivityStatus>? _subscription;
  bool _isSyncing = false;

  /// Optional scaffold messenger key for showing sync result snackbars.
  /// Set this from the root widget if you want automatic notifications.
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  SyncService(this._ref) {
    _startListening();
  }

  // -- Lifecycle -------------------------------------------------------------

  /// Subscribe to connectivity changes and auto-sync when going online.
  void _startListening() {
    final connectivityService = _ref.read(connectivityServiceProvider);
    _subscription = connectivityService.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && !_isSyncing) {
        _autoSync();
      }
    });
  }

  /// Automatically sync the queue when connectivity is restored.
  Future<void> _autoSync() async {
    final queue = _ref.read(offlineQueueProvider.notifier);
    if (queue.isEmpty) return;

    await syncNow();
  }

  // -- Public API ------------------------------------------------------------

  /// Manually trigger a full sync of the offline queue.
  ///
  /// Returns the [SyncResult]. If a sync is already in progress, returns
  /// a result with zero counts.
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return SyncResult(synced: 0, failed: 0);
    }

    final connectivityService = _ref.read(connectivityServiceProvider);
    final queue = _ref.read(offlineQueueProvider.notifier);

    if (queue.isEmpty) {
      return SyncResult(synced: 0, failed: 0);
    }

    _isSyncing = true;
    connectivityService.setSyncing();

    try {
      final result = await queue.syncAll();

      // Restore connectivity status based on outcome
      if (result.hasFailures) {
        // Check if we are still online
        final stillOnline = await connectivityService.checkConnectivity();
        if (!stillOnline) {
          connectivityService.setOffline();
        } else {
          connectivityService.setOnline();
        }
      } else {
        connectivityService.setOnline();
      }

      _showSyncNotification(result);
      _isSyncing = false;
      return result;
    } catch (e) {
      connectivityService.setOffline();
      _isSyncing = false;
      return SyncResult(synced: 0, failed: 1, errors: [e.toString()]);
    }
  }

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  // -- Notification ----------------------------------------------------------

  /// Show a snackbar with the sync result (if a scaffold messenger is available).
  void _showSyncNotification(SyncResult result) {
    final messenger = scaffoldMessengerKey?.currentState;
    if (messenger == null) return;

    if (result.synced == 0 && result.failed == 0) return;

    final String message;
    final Color backgroundColor;
    final IconData icon;

    if (result.allSucceeded) {
      message = '${result.synced} pesanan berhasil disinkronkan';
      backgroundColor = const Color(0xFF10B981); // successColor
      icon = Icons.cloud_done_rounded;
    } else if (result.synced > 0 && result.hasFailures) {
      message =
          '${result.synced} berhasil, ${result.failed} gagal disinkronkan';
      backgroundColor = const Color(0xFFF59E0B); // warningColor
      icon = Icons.cloud_sync_rounded;
    } else {
      message =
          'Gagal menyinkronkan ${result.failed} pesanan. Akan dicoba lagi.';
      backgroundColor = const Color(0xFFEF4444); // errorColor
      icon = Icons.cloud_off_rounded;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // -- Dispose ---------------------------------------------------------------

  void dispose() {
    _subscription?.cancel();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

/// Provides the singleton [SyncService].
///
/// Watches [connectivityServiceProvider] and [offlineQueueProvider] so it stays
/// alive as long as the app does. Disposes cleanly when the provider is torn
/// down.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
