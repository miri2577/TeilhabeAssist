import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/report_request.dart';
import '../prompts/system_prompts.dart';
import '../schemas/report_schemas.dart';
import 'llm_adapter.dart';

class OpenAIAdapter implements LLMAdapter {
  OpenAIAdapter() : _dio = _buildDio();
  OpenAIAdapter.withDio(Dio dio) : _dio = dio;

  final Dio _dio;

  static Dio _buildDio() => Dio(BaseOptions(
        baseUrl: 'https://api.openai.com',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

  @override
  String get name => 'OpenAI GPT';

  @override
  String get defaultModel => 'gpt-5.4';

  @override
  List<String> get availableModels => const [
        'gpt-5.5',
        'gpt-5.4',
        'gpt-5.4-mini',
        'gpt-5.4-nano',
        'o3',
        'gpt-4o',
      ];

  @override
  Future<ReportResponse> generateReport(ReportRequest request) async {
    final response = await _dio.post(
      '/v1/chat/completions',
      options: Options(headers: _headers(request.apiKey)),
      data: _buildRequestBody(request),
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List;
    final message = choices[0]['message'] as Map<String, dynamic>;
    final rawContent = message['content'] as String;
    final usage = data['usage'] as Map<String, dynamic>;

    // Mit response_format=json_schema ist content garantiert JSON.
    Map<String, dynamic>? structured;
    try {
      final parsed = jsonDecode(rawContent);
      if (parsed is Map<String, dynamic>) structured = parsed;
    } catch (_) {
      // Sollte mit strict-Schema nicht passieren — Fallback: Plain-Text.
    }

    return ReportResponse(
      text: rawContent,
      structured: structured,
      inputTokens: usage['prompt_tokens'] as int,
      outputTokens: usage['completion_tokens'] as int,
      model: data['model'] as String,
      stopReason: choices[0]['finish_reason'] as String?,
    );
  }

  @override
  Stream<String> generateReportStream(ReportRequest request) async* {
    final response = await _dio.post<ResponseBody>(
      '/v1/chat/completions',
      options: Options(
        headers: _headers(request.apiKey),
        responseType: ResponseType.stream,
      ),
      data: {
        ..._buildRequestBody(request),
        'stream': true,
        'stream_options': {'include_usage': true},
      },
    );

    final stream = response.data!.stream;
    // Stream-Decoder: hält Multi-Byte-UTF-8-Sequenzen über Chunk-Grenzen
    // hinweg zusammen (utf8.decode würde sonst bei einem geteilten Umlaut
    // werfen).
    final textStream =
        const Utf8Decoder(allowMalformed: false).bind(stream);
    String buffer = '';

    await for (final chunk in textStream) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

        try {
          final event = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = event['choices'] as List;
          if (choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>;
            final content = delta['content'] as String?;
            if (content != null) yield content;
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<bool> validateApiKey(String key) async {
    try {
      final response = await _dio.get(
        '/v1/models',
        options: Options(headers: _headers(key)),
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
        'Authorization': 'Bearer $apiKey',
      };

  Map<String, dynamic> _buildRequestBody(ReportRequest request) {
    final schema = ReportSchemas.jsonSchemaFor(
      request.reportType,
      request.schema,
    );
    final body = <String, dynamic>{
      'model': request.model,
      'messages': [
        {
          'role': 'system',
          'content':
              SystemPrompts.getPrompt(request.reportType, request.schema),
        },
        {'role': 'user', 'content': request.buildUserContent()},
      ],
      // Schema-gezwungene JSON-Antwort.
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': ReportSchemas.toolName,
          'strict': true,
          'schema': schema,
        },
      },
    };

    // Neuere Modelle (gpt-5.x, o3) nutzen max_completion_tokens
    if (request.model.startsWith('gpt-5') ||
        request.model.startsWith('o3')) {
      body['max_completion_tokens'] = 8000;
    } else {
      body['max_tokens'] = 8000;
      body['temperature'] = request.temperature;
    }

    return body;
  }
}
