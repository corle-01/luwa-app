import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:luwa_app/pos/ai/widgets/ai_quick_actions.dart';

/// State for the POS-specific AI panel and suggestions.
class PosAiState {
  /// Whether the AI floating panel is currently open.
  final bool isPanelOpen;

  /// Current height of the panel (useful for resizable panels).
  final double panelHeight;

  /// Contextual quick action suggestions based on POS state.
  final List<QuickActionItem> quickActionSuggestions;

  /// Whether a shift is currently open for this POS session.
  final bool isShiftOpen;

  /// Whether we are near closing time (e.g. within 1 hour of scheduled close).
  final bool isNearClosingTime;

  const PosAiState({
    this.isPanelOpen = false,
    this.panelHeight = 500.0,
    this.quickActionSuggestions = const [],
    this.isShiftOpen = false,
    this.isNearClosingTime = false,
  });

  PosAiState copyWith({
    bool? isPanelOpen,
    double? panelHeight,
    List<QuickActionItem>? quickActionSuggestions,
    bool? isShiftOpen,
    bool? isNearClosingTime,
  }) {
    return PosAiState(
      isPanelOpen: isPanelOpen ?? this.isPanelOpen,
      panelHeight: panelHeight ?? this.panelHeight,
      quickActionSuggestions:
          quickActionSuggestions ?? this.quickActionSuggestions,
      isShiftOpen: isShiftOpen ?? this.isShiftOpen,
      isNearClosingTime: isNearClosingTime ?? this.isNearClosingTime,
    );
  }
}

/// StateNotifier that manages POS-specific AI state.
///
/// Handles panel open/close state, contextual suggestions based on
/// the current POS state (shift open, closing time, etc.), and
/// panel height adjustments.
class PosAiNotifier extends StateNotifier<PosAiState> {
  PosAiNotifier() : super(const PosAiState()) {
    // Initialize with default contextual suggestions.
    _updateSuggestions();
  }

  /// Toggle the panel open/close.
  void togglePanel() {
    state = state.copyWith(isPanelOpen: !state.isPanelOpen);
  }

  /// Open the panel.
  void openPanel() {
    if (!state.isPanelOpen) {
      state = state.copyWith(isPanelOpen: true);
    }
  }

  /// Close the panel.
  void closePanel() {
    if (state.isPanelOpen) {
      state = state.copyWith(isPanelOpen: false);
    }
  }

  /// Update the panel height.
  void setPanelHeight(double height) {
    state = state.copyWith(panelHeight: height.clamp(300.0, 800.0));
  }

  /// Update the shift open status and refresh suggestions.
  void setShiftOpen(bool isOpen) {
    state = state.copyWith(isShiftOpen: isOpen);
    _updateSuggestions();
  }

  /// Update the closing time status and refresh suggestions.
  void setNearClosingTime(bool isNear) {
    state = state.copyWith(isNearClosingTime: isNear);
    _updateSuggestions();
  }

  /// Get contextual suggestions based on current POS state.
  ///
  /// - If no shift is open: suggest opening a shift
  /// - If shift is open: suggest sales-related queries
  /// - If nearing closing time: suggest shift summary
  List<QuickActionItem> getContextualSuggestions() {
    final suggestions = <QuickActionItem>[];

    if (!state.isShiftOpen) {
      // No shift open -- suggest opening a shift.
      suggestions.addAll(const [
        QuickActionItem(
          icon: Icons.play_circle_outline,
          label: 'Buka shift',
          message: 'Bagaimana cara buka shift baru?',
        ),
        QuickActionItem(
          icon: Icons.history,
          label: 'Shift terakhir',
          message: 'Tampilkan ringkasan shift terakhir',
        ),
        QuickActionItem(
          icon: Icons.checklist_outlined,
          label: 'Persiapan buka',
          message: 'Apa saja yang perlu disiapkan sebelum buka?',
        ),
      ]);
    } else {
      // Shift is open -- suggest sales-related queries.
      suggestions.addAll(const [
        QuickActionItem(
          icon: Icons.show_chart,
          label: 'Sales hari ini',
          message: 'Berapa total sales hari ini?',
        ),
        QuickActionItem(
          icon: Icons.emoji_events_outlined,
          label: 'Produk terlaris',
          message: 'Apa produk terlaris hari ini?',
        ),
        QuickActionItem(
          icon: Icons.inventory_2_outlined,
          label: 'Cek stok',
          message: 'Cek stok rendah',
        ),
        QuickActionItem(
          icon: Icons.people_outline,
          label: 'Pelanggan hari ini',
          message: 'Berapa jumlah pelanggan hari ini?',
        ),
      ]);

      // If near closing time, add shift summary suggestion.
      if (state.isNearClosingTime) {
        suggestions.insert(
          0,
          const QuickActionItem(
            icon: Icons.summarize_outlined,
            label: 'Ringkasan shift',
            message: 'Buatkan ringkasan shift untuk tutup kasir',
          ),
        );
        suggestions.add(const QuickActionItem(
          icon: Icons.lock_clock,
          label: 'Tutup shift',
          message: 'Langkah-langkah untuk menutup shift',
        ));
      }
    }

    return suggestions;
  }

  /// Re-compute contextual suggestions and update state.
  void _updateSuggestions() {
    state = state.copyWith(
      quickActionSuggestions: getContextualSuggestions(),
    );
  }

  /// Refresh suggestions manually (e.g. after POS state change).
  void refreshSuggestions() {
    _updateSuggestions();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provider for the POS AI state.
final posAiProvider =
    StateNotifierProvider<PosAiNotifier, PosAiState>((ref) {
  return PosAiNotifier();
});

/// Provider that exposes whether the panel is open.
final posAiPanelOpenProvider = Provider<bool>((ref) {
  return ref.watch(posAiProvider).isPanelOpen;
});

/// Provider that exposes contextual quick action suggestions.
final posAiSuggestionsProvider = Provider<List<QuickActionItem>>((ref) {
  return ref.watch(posAiProvider).quickActionSuggestions;
});

/// Provider that exposes the panel height.
final posAiPanelHeightProvider = Provider<double>((ref) {
  return ref.watch(posAiProvider).panelHeight;
});
