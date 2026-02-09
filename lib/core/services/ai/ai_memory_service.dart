import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single memory/insight that the AI has extracted from conversations.
class AiMemory {
  /// Unique identifier for this memory.
  final String id;

  /// The key insight text (e.g., "Kopi Latte paling laris di siang hari").
  final String insight;

  /// Category of the memory: sales, product, stock, customer, operational.
  final String category;

  /// Confidence level 0.0 - 1.0 (how certain AI is about this fact).
  final double confidence;

  /// When this memory was created.
  final DateTime createdAt;

  /// How many times this insight has been reinforced by new data.
  final int reinforceCount;

  /// Source conversation snippet that led to this memory.
  final String? source;

  const AiMemory({
    required this.id,
    required this.insight,
    required this.category,
    this.confidence = 0.8,
    required this.createdAt,
    this.reinforceCount = 1,
    this.source,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'insight': insight,
        'category': category,
        'confidence': confidence,
        'created_at': createdAt.toIso8601String(),
        'reinforce_count': reinforceCount,
        'source': source,
      };

  factory AiMemory.fromJson(Map<String, dynamic> json) => AiMemory(
        id: json['id'] as String,
        insight: json['insight'] as String,
        category: json['category'] as String? ?? 'general',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
        createdAt: DateTime.parse(json['created_at'] as String),
        reinforceCount: json['reinforce_count'] as int? ?? 1,
        source: json['source'] as String?,
      );

  AiMemory copyWith({int? reinforceCount, double? confidence}) => AiMemory(
        id: id,
        insight: insight,
        category: category,
        confidence: confidence ?? this.confidence,
        createdAt: createdAt,
        reinforceCount: reinforceCount ?? this.reinforceCount,
        source: source,
      );
}

/// Business mood indicator based on sales performance.
enum BusinessMood {
  /// Sales well above average
  thriving,

  /// Sales above average
  good,

  /// Sales roughly normal
  steady,

  /// Sales below average
  slow,

  /// Sales significantly below average or problems detected
  concerned,
}

/// Prediction data for business forecasting.
class BusinessPrediction {
  /// Predicted busy hours for today (e.g., [11, 12, 13, 18, 19]).
  final List<int> predictedBusyHours;

  /// Estimated revenue for today.
  final double estimatedRevenue;

  /// Items that may run out today based on usage patterns.
  final List<String> stockWarnings;

  /// General forecast text.
  final String forecastText;

  /// Day type: weekday, weekend, holiday.
  final String dayType;

  const BusinessPrediction({
    this.predictedBusyHours = const [],
    this.estimatedRevenue = 0,
    this.stockWarnings = const [],
    this.forecastText = '',
    this.dayType = 'weekday',
  });
}

/// OTAK - AI Memory Service
///
/// Stores and retrieves AI memories (key business insights extracted
/// from conversations and data patterns). Uses in-memory cache with
/// localStorage persistence via dart:js_interop for web.
///
/// This is the "brain" of the AI persona system - it remembers what
/// matters about the business.
class AiMemoryService {
  /// In-memory cache of all AI memories.
  final Map<String, AiMemory> _memories = {};

  /// Maximum number of memories to retain.
  static const int _maxMemories = 50;

  /// Singleton instance.
  static final AiMemoryService _instance = AiMemoryService._internal();
  factory AiMemoryService() => _instance;
  AiMemoryService._internal();

  /// Initialize: load memories from SharedPreferences.
  Future<void> initialize() async {
    await _WebStorage.init();
    await _loadFromStorage();
  }

  /// Get all memories, sorted by most recent first.
  List<AiMemory> getAllMemories() {
    final list = _memories.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get memories by category.
  List<AiMemory> getMemoriesByCategory(String category) {
    return getAllMemories()
        .where((m) => m.category == category)
        .toList();
  }

  /// Get the top N most reinforced/confident memories.
  List<AiMemory> getTopMemories({int limit = 10}) {
    final list = _memories.values.toList()
      ..sort((a, b) {
        // Sort by reinforce count * confidence (most validated first)
        final aScore = a.reinforceCount * a.confidence;
        final bScore = b.reinforceCount * b.confidence;
        return bScore.compareTo(aScore);
      });
    return list.take(limit).toList();
  }

  /// Add a new memory. If a similar insight already exists, reinforce it.
  void addMemory({
    required String insight,
    required String category,
    double confidence = 0.8,
    String? source,
  }) {
    // Check for duplicate/similar insights
    final existing = _findSimilar(insight);
    if (existing != null) {
      // Reinforce existing memory
      _memories[existing.id] = existing.copyWith(
        reinforceCount: existing.reinforceCount + 1,
        confidence: (existing.confidence + confidence) / 2.0,
      );
    } else {
      // Add new memory
      final id = '${DateTime.now().millisecondsSinceEpoch}_${_memories.length}';
      _memories[id] = AiMemory(
        id: id,
        insight: insight,
        category: category,
        confidence: confidence,
        createdAt: DateTime.now(),
        source: source,
      );

      // Evict old low-confidence memories if over limit
      _evictIfNeeded();
    }

    _saveToStorage();
  }

  /// Remove a specific memory.
  void removeMemory(String id) {
    _memories.remove(id);
    _saveToStorage();
  }

  /// Clear all memories.
  void clearAll() {
    _memories.clear();
    _saveToStorage();
  }

  /// Extract insights from an AI response text.
  ///
  /// Looks for patterns in the AI's response that indicate
  /// business-relevant facts worth remembering.
  void extractAndStoreInsights(String aiResponse, String userMessage) {
    final insights = _extractInsights(aiResponse, userMessage);
    for (final entry in insights) {
      addMemory(
        insight: entry['insight'] as String,
        category: entry['category'] as String,
        confidence: (entry['confidence'] as num?)?.toDouble() ?? 0.7,
        source: userMessage.length > 80
            ? '${userMessage.substring(0, 80)}...'
            : userMessage,
      );
    }
  }

  /// Build a context string of memories for the AI system prompt.
  String buildMemoryContext() {
    final topMemories = getTopMemories(limit: 8);
    if (topMemories.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('MEMORI AI (hal yang sudah kamu pelajari tentang bisnis ini):');
    for (final m in topMemories) {
      final stars = m.reinforceCount > 2 ? ' [tervalidasi ${m.reinforceCount}x]' : '';
      buffer.writeln('- [${m.category}] ${m.insight}$stars');
    }
    return buffer.toString();
  }

  /// Get memory count per category.
  Map<String, int> getCategoryCounts() {
    final counts = <String, int>{};
    for (final m in _memories.values) {
      counts[m.category] = (counts[m.category] ?? 0) + 1;
    }
    return counts;
  }

  // ── Private Methods ──────────────────────────────────────

  /// Find a memory with a similar insight (simple substring/keyword matching).
  AiMemory? _findSimilar(String insight) {
    final keywords = _extractKeywords(insight.toLowerCase());
    if (keywords.isEmpty) return null;

    for (final memory in _memories.values) {
      final memoryKeywords = _extractKeywords(memory.insight.toLowerCase());
      // If 60%+ keywords overlap, consider it similar
      final overlap = keywords.where((k) => memoryKeywords.contains(k)).length;
      if (keywords.isNotEmpty && overlap / keywords.length >= 0.6) {
        return memory;
      }
    }
    return null;
  }

  /// Extract meaningful keywords from text.
  List<String> _extractKeywords(String text) {
    const stopWords = {
      'yang', 'dan', 'di', 'ke', 'dari', 'untuk', 'ini', 'itu',
      'adalah', 'dengan', 'pada', 'akan', 'sudah', 'bisa', 'ada',
      'tidak', 'juga', 'atau', 'saat', 'hari', 'sangat', 'lebih',
      'paling', 'lagi', 'baru', 'sedang', 'telah', 'oleh', 'setiap',
      'the', 'and', 'or', 'is', 'are', 'was', 'a', 'an',
    };

    return text
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
  }

  /// Extract business insights from AI response text.
  List<Map<String, dynamic>> _extractInsights(String response, String userMessage) {
    final insights = <Map<String, dynamic>>[];
    final lowerResponse = response.toLowerCase();

    // Pattern: product popularity mentions
    final popularityPatterns = [
      RegExp(r'([\w\s]+)\s+(?:paling laris|terlaris|best.?seller|favorit)', caseSensitive: false),
      RegExp(r'(?:produk|menu|item)\s+terlaris[:\s]+([\w\s,]+)', caseSensitive: false),
    ];
    for (final pattern in popularityPatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        final product = (match.group(1) ?? '').trim();
        if (product.isNotEmpty && product.length < 60) {
          insights.add({
            'insight': 'Produk terlaris: $product',
            'category': 'product',
            'confidence': 0.85,
          });
        }
      }
    }

    // Pattern: revenue/sales trends
    if (lowerResponse.contains('pendapatan') ||
        lowerResponse.contains('revenue') ||
        lowerResponse.contains('penjualan') ||
        lowerResponse.contains('omzet')) {
      final revenuePattern = RegExp(
        r'(?:total|pendapatan|revenue|omzet|penjualan)[:\s]*(?:rp\.?\s*)?([0-9.,]+)',
        caseSensitive: false,
      );
      final match = revenuePattern.firstMatch(response);
      if (match != null) {
        final now = DateTime.now();
        final dayName = _getDayName(now.weekday);
        insights.add({
          'insight': 'Penjualan $dayName: Rp ${match.group(1)}',
          'category': 'sales',
          'confidence': 0.9,
        });
      }
    }

    // Pattern: stock warnings
    if (lowerResponse.contains('stok menipis') ||
        lowerResponse.contains('stok habis') ||
        lowerResponse.contains('low stock') ||
        lowerResponse.contains('perlu restock')) {
      final stockPattern = RegExp(
        r'([\w\s]+)\s+(?:stok(?:nya)?\s+(?:menipis|habis|rendah|tinggal)|perlu\s+(?:restock|restok))',
        caseSensitive: false,
      );
      final match = stockPattern.firstMatch(response);
      if (match != null) {
        final ingredient = (match.group(1) ?? '').trim();
        if (ingredient.isNotEmpty && ingredient.length < 40) {
          insights.add({
            'insight': '$ingredient sering stok menipis - pertimbangkan tambah safety stock',
            'category': 'stock',
            'confidence': 0.75,
          });
        }
      }
    }

    // Pattern: time-based observations
    final timePatterns = [
      RegExp(r'(?:jam|pukul)\s+(\d{1,2})[:\.]?(\d{0,2})?\s+(?:paling|puncak|ramai|sibuk)', caseSensitive: false),
      RegExp(r'(?:paling|puncak|ramai|sibuk)\s+(?:di|pada|sekitar)\s+(?:jam|pukul)\s+(\d{1,2})', caseSensitive: false),
    ];
    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        final hour = match.group(1) ?? '';
        if (hour.isNotEmpty) {
          insights.add({
            'insight': 'Jam sibuk sekitar pukul $hour:00',
            'category': 'operational',
            'confidence': 0.7,
          });
        }
      }
    }

    // Pattern: customer behavior
    if (lowerResponse.contains('pelanggan') ||
        lowerResponse.contains('customer') ||
        lowerResponse.contains('pembeli')) {
      // If it mentions repeat customers or loyalty
      if (lowerResponse.contains('langganan') ||
          lowerResponse.contains('repeat') ||
          lowerResponse.contains('setia') ||
          lowerResponse.contains('loyal')) {
        insights.add({
          'insight': 'Ada pola pelanggan loyal/repeat buyer yang teridentifikasi',
          'category': 'customer',
          'confidence': 0.65,
        });
      }
    }

    return insights;
  }

  String _getDayName(int weekday) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return days[weekday - 1];
  }

  /// Remove lowest-confidence memories when over limit.
  void _evictIfNeeded() {
    if (_memories.length <= _maxMemories) return;

    // Sort by score (low to high) and remove lowest
    final sorted = _memories.entries.toList()
      ..sort((a, b) {
        final aScore = a.value.reinforceCount * a.value.confidence;
        final bScore = b.value.reinforceCount * b.value.confidence;
        return aScore.compareTo(bScore);
      });

    final toRemove = sorted.take(_memories.length - _maxMemories);
    for (final entry in toRemove) {
      _memories.remove(entry.key);
    }
  }

  /// Load memories from localStorage (web only).
  Future<void> _loadFromStorage() async {
    try {
      if (kIsWeb) {
        final stored = _webStorageGet('utter_ai_memories');
        if (stored != null && stored.isNotEmpty) {
          final list = jsonDecode(stored) as List;
          for (final item in list) {
            final memory = AiMemory.fromJson(Map<String, dynamic>.from(item as Map));
            _memories[memory.id] = memory;
          }
        }
      }
    } catch (e) {
      // Silently fail - memories are not critical
      debugPrint('AiMemoryService: Failed to load memories: $e');
    }
  }

  /// Save memories to localStorage (web only).
  void _saveToStorage() {
    try {
      if (kIsWeb) {
        final json = jsonEncode(
          _memories.values.map((m) => m.toJson()).toList(),
        );
        _webStorageSet('utter_ai_memories', json);
      }
    } catch (e) {
      debugPrint('AiMemoryService: Failed to save memories: $e');
    }
  }

  /// Safe wrapper for web localStorage get.
  String? _webStorageGet(String key) {
    try {
      // Use conditional import pattern for web storage
      return _WebStorage.get(key);
    } catch (_) {
      return null;
    }
  }

  /// Safe wrapper for web localStorage set.
  void _webStorageSet(String key, String value) {
    try {
      _WebStorage.set(key, value);
    } catch (_) {
      // Ignore storage errors
    }
  }
}

/// Storage helper using SharedPreferences (works on web + native).
class _WebStorage {
  static SharedPreferences? _prefs;

  static Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? get(String key) {
    return _prefs?.getString(key);
  }

  static void set(String key, String value) {
    _prefs?.setString(key, value);
  }

  /// Must be called once at startup to initialize SharedPreferences.
  static Future<void> init() async {
    await _ensureInit();
  }
}
