import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connectivity status for the POS system.
enum ConnectivityStatus { online, offline, syncing }

/// Monitors connectivity to Supabase backend.
///
/// Periodically pings the server and exposes a stream of connectivity changes.
/// Used by the sync service to trigger automatic queue processing when the
/// connection is restored after an offline period.
class ConnectivityService {
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  ConnectivityStatus get currentStatus => _currentStatus;

  Timer? _checkTimer;
  bool _isChecking = false;

  /// Start periodic connectivity monitoring.
  ///
  /// Performs an initial check immediately, then rechecks every 30 seconds.
  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectivity(),
    );
    // Initial check
    checkConnectivity();
  }

  /// Manually trigger a connectivity check.
  ///
  /// Returns `true` if online, `false` if offline.
  /// Guards against concurrent checks.
  Future<bool> checkConnectivity() async {
    if (_isChecking) return _currentStatus == ConnectivityStatus.online;
    _isChecking = true;

    try {
      // Simple health check - query a small table with a short timeout
      await Supabase.instance.client
          .from('outlets')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      _updateStatus(ConnectivityStatus.online);
      _isChecking = false;
      return true;
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
      _isChecking = false;
      return false;
    }
  }

  /// Update status only when it actually changes, to avoid duplicate events.
  void _updateStatus(ConnectivityStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Set status to syncing (called by SyncService during queue processing).
  void setSyncing() => _updateStatus(ConnectivityStatus.syncing);

  /// Set status to online (called by SyncService after sync completes).
  void setOnline() => _updateStatus(ConnectivityStatus.online);

  /// Set status to offline (e.g. when a Supabase call fails unexpectedly).
  void setOffline() => _updateStatus(ConnectivityStatus.offline);

  /// Whether the service currently considers the backend reachable.
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  /// Whether the service is currently in the syncing state.
  bool get isSyncing => _currentStatus == ConnectivityStatus.syncing;

  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Singleton connectivity service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.startMonitoring();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of connectivity status changes.
///
/// Widgets can watch this to reactively show/hide offline indicators.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});
