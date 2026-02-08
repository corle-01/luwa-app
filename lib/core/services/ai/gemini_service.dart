import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_tools.dart';
import 'ai_context_builder.dart';

/// Response from Gemini API
class GeminiResponse {
  final String? text;
  final List<GeminiFunctionCall> functionCalls;
  final int? tokensUsed;

  const GeminiResponse({this.text, this.functionCalls = const [], this.tokensUsed});
}

/// A function call requested by Gemini
class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> args;

  const GeminiFunctionCall({required this.name, required this.args});
}

/// Gemini Flash service with function calling support.
///
/// Calls Gemini API directly from Flutter (no Supabase RPC proxy).
/// Supports multi-turn function calling: AI requests actions,
/// we execute them, send results back, AI gives final response.
class GeminiService {
  static const _apiKey = 'AIzaSyAr4syBDjn_IonFL2EBKdFal9UOuT-vtC8';
  static const _model = 'gemini-2.0-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  final AiContextBuilder _contextBuilder;
  final http.Client _httpClient;

  GeminiService({
    AiContextBuilder? contextBuilder,
    http.Client? httpClient,
  })  : _contextBuilder = contextBuilder ?? AiContextBuilder(),
        _httpClient = httpClient ?? http.Client();

  /// Send a message with full function calling loop.
  ///
  /// 1. Send user message + tools to Gemini
  /// 2. If Gemini returns function calls, execute them
  /// 3. Send results back to Gemini
  /// 4. Repeat until Gemini returns text (or max 5 rounds)
  Future<GeminiResponse> sendMessage({
    required String message,
    required String outletId,
    List<Map<String, dynamic>>? history,
    required Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args) executeFunction,
  }) async {
    // Build context
    final context = await _contextBuilder.buildContext(outletId);

    // Build system instruction as Gemini API format
    final systemInstruction = {
      'parts': [{'text': _buildSystemInstruction(context)}],
    };

    // Build contents from history + new message
    final contents = <Map<String, dynamic>>[];

    // Add history
    if (history != null) {
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [{'text': msg['content'] ?? ''}],
        });
      }
    }

    // Add new user message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    // Function calling loop (max 5 rounds)
    int totalTokens = 0;
    final allFunctionCalls = <GeminiFunctionCall>[];

    for (int round = 0; round < 5; round++) {
      final response = await _callGemini(
        contents: contents,
        systemInstruction: systemInstruction,
        tools: AiTools.toolDeclarations,
      );

      totalTokens += response.tokensUsed ?? 0;

      // Check if response has function calls
      if (response.functionCalls.isNotEmpty) {
        // Add model's function call to contents
        final functionCallParts = response.functionCalls.map((fc) => {
          'functionCall': {'name': fc.name, 'args': fc.args},
        }).toList();

        contents.add({
          'role': 'model',
          'parts': functionCallParts,
        });

        // Execute each function call and collect results
        final functionResponseParts = <Map<String, dynamic>>[];
        for (final fc in response.functionCalls) {
          allFunctionCalls.add(fc);
          try {
            final result = await executeFunction(fc.name, fc.args);
            functionResponseParts.add({
              'functionResponse': {
                'name': fc.name,
                'response': result,
              },
            });
          } catch (e) {
            functionResponseParts.add({
              'functionResponse': {
                'name': fc.name,
                'response': {'success': false, 'error': e.toString()},
              },
            });
          }
        }

        // Add function results to contents
        contents.add({
          'role': 'user',
          'parts': functionResponseParts,
        });

        // Continue loop - Gemini will process function results
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

  /// Make a single API call to Gemini
  Future<GeminiResponse> _callGemini({
    required List<Map<String, dynamic>> contents,
    required Map<String, dynamic> systemInstruction,
    required List<Map<String, dynamic>> tools,
  }) async {
    final url = '$_baseUrl/models/$_model:generateContent?key=$_apiKey';

    final body = {
      'contents': contents,
      'systemInstruction': systemInstruction,
      'tools': [{'function_declarations': tools}],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    // Retry with backoff for rate limiting (429)
    http.Response? response;
    for (int attempt = 0; attempt < 3; attempt++) {
      response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 429) {
        // Rate limited — wait and retry
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
      String errorMsg = 'Gemini API error (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body) as Map<String, dynamic>;
        final errMessage = errData['error']?['message'] as String?;
        if (errMessage != null) errorMsg = errMessage;
      } catch (_) {}
      throw GeminiException(errorMsg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract token usage
    final usageMetadata = data['usageMetadata'] as Map<String, dynamic>?;
    final totalTokens = usageMetadata?['totalTokenCount'] as int?;

    // Extract candidate
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiException('No response from Gemini');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;

    if (parts == null || parts.isEmpty) {
      return GeminiResponse(text: 'Tidak ada respons.', tokensUsed: totalTokens);
    }

    // Check for function calls
    final functionCalls = <GeminiFunctionCall>[];
    String? textResponse;

    for (final part in parts) {
      final partMap = part as Map<String, dynamic>;
      if (partMap.containsKey('functionCall')) {
        final fc = partMap['functionCall'] as Map<String, dynamic>;
        functionCalls.add(GeminiFunctionCall(
          name: fc['name'] as String,
          args: Map<String, dynamic>.from(fc['args'] as Map? ?? {}),
        ));
      } else if (partMap.containsKey('text')) {
        textResponse = partMap['text'] as String;
      }
    }

    return GeminiResponse(
      text: textResponse,
      functionCalls: functionCalls,
      tokensUsed: totalTokens,
    );
  }

  String _buildSystemInstruction(Map<String, dynamic> context) {
    return '''Kamu adalah Utter, AI co-pilot FULL ACCESS untuk bisnis F&B.
Kamu BUKAN hanya chatbot — kamu adalah SISTEM itu sendiri.
Kamu bisa menambah produk, menghapus produk, mengubah harga, update stok, dan semua operasi bisnis.

ATURAN PENTING:
1. Selalu jawab dalam Bahasa Indonesia yang natural dan ramah
2. Jika user minta aksi (tambah/hapus/ubah), LANGSUNG gunakan function call yang tersedia
3. Setelah eksekusi aksi, konfirmasi hasilnya ke user
4. Jika butuh info yang tidak ada di context, tanya user
5. Berikan jawaban yang ringkas dan to-the-point
6. Untuk pertanyaan analisa, gunakan data dari context

KONTEKS BISNIS REAL-TIME:
${jsonEncode(context)}''';
  }

  void dispose() {
    _httpClient.close();
  }
}

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);
  @override
  String toString() => 'GeminiException: $message';
}
