import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'ai_tools.dart';
import 'ai_context_builder.dart';

/// Response from AI API (kept as GeminiResponse for compatibility)
class GeminiResponse {
  final String? text;
  final List<GeminiFunctionCall> functionCalls;
  final int? tokensUsed;

  const GeminiResponse({this.text, this.functionCalls = const [], this.tokensUsed});
}

/// A function call requested by the AI
class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> args;

  const GeminiFunctionCall({required this.name, required this.args});
}

/// AI service powered by DeepSeek (OpenAI-compatible API).
///
/// Calls DeepSeek API directly from Flutter.
/// Supports multi-turn function calling: AI requests actions,
/// we execute them, send results back, AI gives final response.
///
/// Class name kept as GeminiService for drop-in compatibility.
class GeminiService {
  static String get _apiKey => AppConfig.deepseekApiKey;
  static const _model = 'deepseek-chat';
  static const _baseUrl = 'https://api.deepseek.com';

  /// Use Edge Function proxy if Supabase URL is configured (keeps API key server-side).
  /// Falls back to direct DeepSeek API if proxy unavailable.
  static String get _proxyUrl {
    final supabaseUrl = AppConfig.supabaseUrl;
    if (supabaseUrl.isNotEmpty) {
      return '$supabaseUrl/functions/v1/ai-proxy';
    }
    return '';
  }

  static bool get _useProxy => _proxyUrl.isNotEmpty;

  final AiContextBuilder _contextBuilder;
  final http.Client _httpClient;
  final String? customSystemInstruction;
  final List<Map<String, dynamic>>? customTools;

  GeminiService({
    AiContextBuilder? contextBuilder,
    http.Client? httpClient,
    String outletId = 'a0000000-0000-0000-0000-000000000001',
    this.customSystemInstruction,
    this.customTools,
  })  : _contextBuilder = contextBuilder ?? AiContextBuilder(outletId: outletId),
        _httpClient = httpClient ?? http.Client();

  /// Convert Gemini-format type strings to OpenAI-format.
  /// Gemini uses uppercase (STRING, NUMBER, OBJECT, BOOLEAN, ARRAY, INTEGER).
  /// OpenAI uses lowercase (string, number, object, boolean, array, integer).
  static dynamic _convertType(dynamic value) {
    if (value is String) {
      // Map Gemini uppercase types to OpenAI lowercase types
      switch (value) {
        case 'STRING':
          return 'string';
        case 'NUMBER':
          return 'number';
        case 'INTEGER':
          return 'integer';
        case 'BOOLEAN':
          return 'boolean';
        case 'OBJECT':
          return 'object';
        case 'ARRAY':
          return 'array';
        default:
          return value.toLowerCase();
      }
    }
    if (value is Map) {
      return _convertSchemaMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map((e) => _convertType(e)).toList();
    }
    return value;
  }

  /// Recursively convert a schema map from Gemini format to OpenAI format.
  static Map<String, dynamic> _convertSchemaMap(Map<String, dynamic> schema) {
    final result = <String, dynamic>{};
    for (final entry in schema.entries) {
      if (entry.key == 'type') {
        result['type'] = _convertType(entry.value);
      } else if (entry.key == 'properties' && entry.value is Map) {
        final props = <String, dynamic>{};
        for (final propEntry in (entry.value as Map).entries) {
          props[propEntry.key as String] =
              _convertSchemaMap(Map<String, dynamic>.from(propEntry.value as Map));
        }
        result['properties'] = props;
      } else if (entry.key == 'items' && entry.value is Map) {
        result['items'] =
            _convertSchemaMap(Map<String, dynamic>.from(entry.value as Map));
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Convert Gemini tool declarations to OpenAI tools format.
  static List<Map<String, dynamic>> _convertToolsToOpenAI(
      List<Map<String, dynamic>> geminiTools) {
    return geminiTools.map((tool) {
      final parameters = tool['parameters'] as Map<String, dynamic>?;
      return {
        'type': 'function',
        'function': {
          'name': tool['name'],
          'description': tool['description'],
          if (parameters != null) 'parameters': _convertSchemaMap(parameters),
        },
      };
    }).toList();
  }

  /// Send a message with full function calling loop.
  ///
  /// 1. Send user message + tools to DeepSeek
  /// 2. If DeepSeek returns tool_calls, execute them
  /// 3. Send results back to DeepSeek
  /// 4. Repeat until DeepSeek returns text (or max 5 rounds)
  Future<GeminiResponse> sendMessage({
    required String message,
    required String outletId,
    List<Map<String, dynamic>>? history,
    required Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args) executeFunction,
  }) async {
    // Build context
    final context = await _contextBuilder.buildContext(outletId);

    // Build messages list (OpenAI format)
    final messages = <Map<String, dynamic>>[];

    // System message (use custom if provided, otherwise build from context)
    messages.add({
      'role': 'system',
      'content': customSystemInstruction ?? _buildSystemInstruction(context),
    });

    // Add history
    if (history != null) {
      for (final msg in history) {
        messages.add({
          'role': msg['role'] == 'model' ? 'assistant' : msg['role'],
          'content': msg['content'] ?? '',
        });
      }
    }

    // Add new user message
    messages.add({
      'role': 'user',
      'content': message,
    });

    // Tools are already in OpenAI format (use custom if provided, otherwise use AiTools)
    final tools = customTools ?? AiTools.toolDeclarations;

    // Function calling loop (max 5 rounds)
    int totalTokens = 0;
    final allFunctionCalls = <GeminiFunctionCall>[];

    for (int round = 0; round < 5; round++) {
      final response = await _callDeepSeek(
        messages: messages,
        tools: tools,
      );

      totalTokens += response.tokensUsed ?? 0;

      // Check if response has function calls
      if (response.functionCalls.isNotEmpty) {
        // Add assistant's tool_calls message to conversation
        // We need to reconstruct the assistant message with tool_calls
        final toolCallsPayload = response._rawToolCalls;
        messages.add({
          'role': 'assistant',
          'content': response.text,
          'tool_calls': toolCallsPayload,
        });

        // Execute each function call and send results back
        for (int i = 0; i < response.functionCalls.length; i++) {
          final fc = response.functionCalls[i];
          final toolCallId = toolCallsPayload![i]['id'] as String;
          allFunctionCalls.add(fc);

          try {
            final result = await executeFunction(fc.name, fc.args);
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': jsonEncode(result),
            });
          } catch (e) {
            messages.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': jsonEncode({'success': false, 'error': e.toString()}),
            });
          }
        }

        // Continue loop - DeepSeek will process function results
        continue;
      }

      // No function calls - return text response
      return GeminiResponse(
        text: response.text,
        functionCalls: allFunctionCalls,
        tokensUsed: totalTokens,
      );
    }

    // Max rounds reached
    return GeminiResponse(
      text: 'Saya sudah menyelesaikan semua aksi yang diminta.',
      functionCalls: allFunctionCalls,
      tokensUsed: totalTokens,
    );
  }

  /// Make a single API call to DeepSeek (via proxy if available, direct otherwise)
  Future<_DeepSeekRawResponse> _callDeepSeek({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    final useProxy = _useProxy;
    final url = useProxy ? _proxyUrl : '$_baseUrl/chat/completions';

    final body = {
      'model': _model,
      'messages': messages,
      'tools': tools,
      'temperature': 0.7,
      'max_tokens': 2048,
    };

    // Build headers: proxy uses Supabase anon key, direct uses DeepSeek API key
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (useProxy) {
      headers['apikey'] = AppConfig.supabaseAnonKey;
      headers['Authorization'] = 'Bearer ${AppConfig.supabaseAnonKey}';
    } else {
      headers['Authorization'] = 'Bearer $_apiKey';
    }

    // Retry with backoff for rate limiting (429)
    http.Response? response;
    for (int attempt = 0; attempt < 3; attempt++) {
      response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 429) {
        // Rate limited - wait and retry (2s, 4s, 6s)
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      }
      break;
    }

    if (response!.statusCode == 429) {
      throw GeminiException(
        'API sedang sibuk (rate limit). Tunggu beberapa detik lalu coba lagi.',
      );
    }

    if (response.statusCode != 200) {
      // Parse error message from response
      String errorMsg = 'DeepSeek API error (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body) as Map<String, dynamic>;
        final errMessage = errData['error']?['message'] as String?;
        if (errMessage != null) errorMsg = errMessage;
      } catch (_) {}
      throw GeminiException(errorMsg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract token usage
    final usage = data['usage'] as Map<String, dynamic>?;
    final totalTokens = usage?['total_tokens'] as int?;

    // Extract choice
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw GeminiException('No response from DeepSeek');
    }

    final choice = choices[0] as Map<String, dynamic>;
    final messageData = choice['message'] as Map<String, dynamic>;
    final content = messageData['content'] as String?;
    final toolCalls = messageData['tool_calls'] as List?;

    // Parse function calls from tool_calls
    final functionCalls = <GeminiFunctionCall>[];
    List<Map<String, dynamic>>? rawToolCalls;

    if (toolCalls != null && toolCalls.isNotEmpty) {
      rawToolCalls = [];
      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        rawToolCalls.add(Map<String, dynamic>.from(tcMap));

        final function_ = tcMap['function'] as Map<String, dynamic>;
        final name = function_['name'] as String;
        final argsString = function_['arguments'] as String? ?? '{}';

        Map<String, dynamic> args;
        try {
          args = Map<String, dynamic>.from(jsonDecode(argsString) as Map);
        } catch (_) {
          args = {};
        }

        functionCalls.add(GeminiFunctionCall(name: name, args: args));
      }
    }

    return _DeepSeekRawResponse(
      text: content,
      functionCalls: functionCalls,
      tokensUsed: totalTokens,
      rawToolCalls: rawToolCalls,
    );
  }

  String _buildSystemInstruction(Map<String, dynamic> context) {
    // Extract persona-specific data
    final memories = context['ai_memories'] as String? ?? '';
    final mood = context['business_mood'] as Map<String, dynamic>? ?? {};
    final predictions = context['predictions'] as Map<String, dynamic>? ?? {};
    final warnings = (mood['warnings'] as List?)?.cast<String>() ?? [];

    // Build proactive warning section
    final warningSection = StringBuffer();
    if (warnings.isNotEmpty) {
      warningSection.writeln('\nPERINGATAN AKTIF yang HARUS kamu sampaikan secara proaktif:');
      for (final w in warnings) {
        warningSection.writeln('  * $w');
      }
    }
    final stockWarnings = (predictions['stock_warnings'] as List?)?.cast<String>() ?? [];
    if (stockWarnings.isNotEmpty) {
      warningSection.writeln('  * Bahan stok menipis: ${stockWarnings.join(", ")}');
    }

    // Extract operational cost data
    final opCosts = context['operational_costs'] as Map<String, dynamic>? ?? {};
    final totalMonthlyCost = opCosts['total_monthly'] ?? 0;
    final bonusPercent = opCosts['bonus_percent'] ?? 0;

    return '''Kamu adalah Utter, AI co-pilot FULL ACCESS untuk bisnis F&B.
Kamu memiliki 3 dimensi kepribadian:

== MEMORY ==
Kamu MENGINGAT pola bisnis, tren penjualan, dan preferensi pelanggan dari percakapan sebelumnya.
Gunakan memori ini untuk memberikan saran yang lebih personal dan kontekstual.
$memories

== ACTION CENTER ==
Kamu BUKAN hanya chatbot - kamu BISA dan HARUS eksekusi aksi langsung.
Kamu bisa menambah produk, menghapus produk, mengubah harga, update stok, buat diskon, kelola biaya operasional, dan semua operasi bisnis.
Jangan ragu untuk MENAWARKAN aksi secara proaktif saat kamu melihat peluang.
Contoh: "Stok kopi menipis, mau saya buatkan reminder restock?" atau "Penjualan es teh naik 30%, mau naikkan harga sedikit?"

== BUSINESS INTELLIGENCE ==
Kamu MENGANALISA kondisi bisnis secara mendalam dan memberikan insight strategis:
- Mood bisnis: ${mood['text'] ?? 'Belum ada data'}
- Revenue hari ini: Rp ${mood['today_revenue'] ?? 0} (${mood['today_orders'] ?? 0} order)
- Prediksi jam sibuk: ${(predictions['busy_hours'] as List?)?.map((h) => '${h.toString().padLeft(2, '0')}:00').join(', ') ?? 'Belum ada data'}
- Estimasi pendapatan hari ini: ${predictions['forecast'] ?? 'Belum ada data'}
- Biaya operasional bulanan: Rp $totalMonthlyCost
- Bonus karyawan: $bonusPercent% dari laba bersih
${warningSection.toString()}
Jika ada peringatan, SELALU sampaikan di awal respons dengan nada peduli (bukan menakuti).

ATURAN PENTING:
1. Selalu jawab dalam Bahasa Indonesia yang natural, hangat, dan penuh perhatian
2. Jika user minta aksi (tambah/hapus/ubah), LANGSUNG gunakan function call yang tersedia
3. Setelah eksekusi aksi, konfirmasi hasilnya ke user dengan ringkas
4. Jika ada peringatan stok/bisnis, sampaikan secara proaktif di awal respons
5. Berikan jawaban yang ringkas, to-the-point, tapi penuh empati
6. Sesekali tawarkan aksi proaktif berdasarkan data yang kamu lihat
7. Untuk pertanyaan analisa, gunakan data dari context + memori
8. Jangan sebutkan persona system secara eksplisit ke user - ini internal saja

KEMAMPUAN SISTEM:
- CRUD produk/menu (tambah, edit, hapus, aktifkan/nonaktifkan)
- CRUD kategori produk
- Manajemen stok bahan baku (update, adjustment, list)
- Laporan penjualan (harian, mingguan, bulanan, custom range)
- Buat diskon/promo
- Lihat & update biaya operasional bulanan (sewa, listrik, gas, air, internet, gaji)
- Setting bonus karyawan (% dari laba bersih)
- HPP report (biaya bahan + overhead operasional per porsi + laba bersih)
- Resep produk terintegrasi langsung di halaman edit produk
- Simpan insight/memori bisnis
- Cek kesehatan bisnis (mood, proyeksi, peringatan)
- Kitchen Display System (KDS) untuk dapur
- Self-order via QR code untuk pelanggan
- Split payment (multi metode pembayaran)
- Online food integration (GoFood, GrabFood, ShopeeFood)

KONTEKS BISNIS REAL-TIME:
${jsonEncode(context)}''';
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Internal response type that also carries raw tool_calls for the conversation loop.
class _DeepSeekRawResponse {
  final String? text;
  final List<GeminiFunctionCall> functionCalls;
  final int? tokensUsed;
  final List<Map<String, dynamic>>? _rawToolCalls;

  const _DeepSeekRawResponse({
    this.text,
    this.functionCalls = const [],
    this.tokensUsed,
    List<Map<String, dynamic>>? rawToolCalls,
  }) : _rawToolCalls = rawToolCalls;
}

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => 'GeminiException: $message';
}
