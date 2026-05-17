import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/report_request.dart';
import '../prompts/system_prompts.dart';
import '../schemas/report_schemas.dart';
import 'llm_adapter.dart';

class AnthropicAdapter implements LLMAdapter {
  AnthropicAdapter() : _dio = _buildDio();
  AnthropicAdapter.withDio(Dio dio) : _dio = dio;

  final Dio _dio;

  static Dio _buildDio() => Dio(BaseOptions(
        baseUrl: 'https://api.anthropic.com',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

  @override
  String get name => 'Anthropic Claude';

  @override
  String get defaultModel => 'claude-sonnet-4-6';

  @override
  List<String> get availableModels => const [
        'claude-opus-4-7',
        'claude-sonnet-4-6',
        'claude-haiku-4-5-20251001',
      ];

  @override
  Future<ReportResponse> generateReport(ReportRequest request) async {
    final response = await _dio.post(
      '/v1/messages',
      options: Options(headers: _headers(request.apiKey)),
      data: _buildRequestBody(request),
    );

    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List;

    // Strukturierter Tool-Use-Output bevorzugt — er ist schema-validiert.
    Map<String, dynamic>? structured;
    String text = '';
    for (final c in content) {
      if (c is! Map<String, dynamic>) continue;
      if (c['type'] == 'tool_use' && c['name'] == ReportSchemas.toolName) {
        final input = c['input'];
        if (input is Map<String, dynamic>) structured = input;
      } else if (c['type'] == 'text') {
        text += c['text'] as String? ?? '';
      }
    }

    final usage = data['usage'] as Map<String, dynamic>;
    return ReportResponse(
      text: text,
      structured: structured,
      inputTokens: usage['input_tokens'] as int,
      outputTokens: usage['output_tokens'] as int,
      model: data['model'] as String,
      stopReason: data['stop_reason'] as String?,
    );
  }

  @override
  Stream<String> generateReportStream(ReportRequest request) async* {
    final response = await _dio.post<ResponseBody>(
      '/v1/messages',
      options: Options(
        headers: _headers(request.apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        ..._buildRequestBody(request),
        'stream': true,
      },
    );

    final stream = response.data!.stream;
    // Stream-Decoder: behält partielle Multi-Byte-Sequenzen über
    // Chunk-Grenzen hinweg (utf8.decode würde bei einem geteilten Umlaut
    // einen Fehler werfen).
    final textStream =
        const Utf8Decoder(allowMalformed: false).bind(stream);
    String buffer = '';

    await for (final chunk in textStream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // Unvollständige Zeile behalten

      for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

        try {
          final event = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = event['type'] as String?;

          if (type == 'content_block_delta') {
            final delta = event['delta'] as Map<String, dynamic>;
            if (delta['type'] == 'text_delta') {
              yield delta['text'] as String;
            }
          }
        } catch (_) {
          // Unvollständiges JSON ignorieren
        }
      }
    }
  }

  @override
  Future<bool> validateApiKey(String key) async {
    try {
      final response = await _dio.post(
        '/v1/messages',
        options: Options(headers: _headers(key)),
        data: {
          'model': defaultModel,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 ||
          e.response?.statusCode == 403) return false;
      rethrow;
    }
  }

  Map<String, String> _headers(String apiKey) => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };

  Map<String, dynamic> _buildRequestBody(ReportRequest request) {
    final schema = ReportSchemas.jsonSchemaFor(
      request.reportType,
      request.schema,
    );
    return {
      'model': request.model,
      'max_tokens': 8000,
      'temperature': request.temperature,
      'system': [
        {
          'type': 'text',
          'text': SystemPrompts.getPrompt(request.reportType, request.schema),
          'cache_control': {'type': 'ephemeral'},
        }
      ],
      // Tool-Use erzwingt die strukturierte JSON-Antwort gemäß Schema.
      // tool_choice mit type=tool zwingt Claude, exakt dieses Tool zu rufen.
      'tools': [
        {
          'name': ReportSchemas.toolName,
          'description': ReportSchemas.toolDescription,
          'input_schema': schema,
        }
      ],
      'tool_choice': {'type': 'tool', 'name': ReportSchemas.toolName},
      'messages': [
        {'role': 'user', 'content': request.buildUserContent()},
      ],
    };
  }
}
