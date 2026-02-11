import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:utter_app/core/providers/outlet_provider.dart';
import 'package:utter_app/core/services/ai/ai_memory_service.dart';
import 'package:utter_app/core/services/ai/ai_prediction_service.dart';

/// State for the AI persona system (Memory + Business Intelligence).
class AiPersonaState {
  /// All stored AI memories (Memory).
  final List<AiMemory> memories;

  /// Current business mood (Business Intelligence).
  final BusinessMoodData? mood;

  /// Today's predictions (Business Intelligence).
  final BusinessPrediction? prediction;

  /// Whether data is currently loading.
  final bool isLoading;

  /// Error message, if any.
  final String? error;

  const AiPersonaState({
    this.memories = const [],
    this.mood,
    this.prediction,
    this.isLoading = false,
    this.error,
  });

  AiPersonaState copyWith({
    List<AiMemory>? memories,
    BusinessMoodData? mood,
    BusinessPrediction? prediction,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AiPersonaState(
      memories: memories ?? this.memories,
      mood: mood ?? this.mood,
      prediction: prediction ?? this.prediction,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for the AI persona system.
///
/// Manages the Memory and Business Intelligence personas.
/// Action Center is managed by the existing action executor/log system.
class AiPersonaNotifier extends StateNotifier<AiPersonaState> {
  final AiMemoryService _memoryService;
  final AiPredictionService _predictionService;

  AiPersonaNotifier({
    AiMemoryService? memoryService,
    AiPredictionService? predictionService,
    String outletId = 'a0000000-0000-0000-0000-000000000001',
  })  : _memoryService = memoryService ?? AiMemoryService(),
        _predictionService = predictionService ?? AiPredictionService(outletId: outletId),
        super(const AiPersonaState());

  /// Load all persona data: memories, mood, and predictions.
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Initialize memory service
      await _memoryService.initialize();

      // Load all data in parallel
      final results = await Future.wait([
        _predictionService.assessBusinessMood(),
        _predictionService.generatePredictions(),
      ]);

      final memories = _memoryService.getAllMemories();

      state = state.copyWith(
        memories: memories,
        mood: results[0] as BusinessMoodData,
        prediction: results[1] as BusinessPrediction,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data persona: $e',
      );
    }
  }

  /// Refresh just the mood and predictions.
  Future<void> refreshMood() async {
    try {
      final mood = await _predictionService.assessBusinessMood();
      final prediction = await _predictionService.generatePredictions();
      final memories = _memoryService.getAllMemories();

      state = state.copyWith(
        mood: mood,
        prediction: prediction,
        memories: memories,
      );
    } catch (e) {
      state = state.copyWith(error: 'Gagal refresh mood: $e');
    }
  }

  /// Refresh just the memories list.
  void refreshMemories() {
    state = state.copyWith(
      memories: _memoryService.getAllMemories(),
    );
  }

  /// Remove a specific memory.
  void removeMemory(String id) {
    _memoryService.removeMemory(id);
    state = state.copyWith(
      memories: _memoryService.getAllMemories(),
    );
  }

  /// Clear all memories.
  void clearMemories() {
    _memoryService.clearAll();
    state = state.copyWith(memories: []);
  }
}

/// Provider for the AI persona state.
final aiPersonaProvider =
    StateNotifierProvider<AiPersonaNotifier, AiPersonaState>((ref) {
  final outletId = ref.watch(currentOutletIdProvider);
  return AiPersonaNotifier(outletId: outletId);
});

/// Provider that exposes just the AI memories list.
final aiMemoriesProvider = Provider<List<AiMemory>>((ref) {
  return ref.watch(aiPersonaProvider).memories;
});

/// Provider that exposes the business mood.
final aiBusinessMoodProvider = Provider<BusinessMoodData?>((ref) {
  return ref.watch(aiPersonaProvider).mood;
});

/// Provider that exposes the predictions.
final aiPredictionProvider = Provider<BusinessPrediction?>((ref) {
  return ref.watch(aiPersonaProvider).prediction;
});
