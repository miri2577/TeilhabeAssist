import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/report_request.dart';
import '../prompts/system_prompts.dart';
import 'llm_adapter.dart';

class OpenAIAdapter implements LLMAdapter {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.openai.com',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  @override
  String get name => 'OpenAI GPT-4o';

  @override
  String get defaultModel => 'gpt-5.4-2026-03-05';

  @override
  List<String> get availableModels => [
        'gpt-5.4-2026-03-05',
        'gpt-5.4-mini-2026-03-17',
        'gpt-5.4-nano-2026-03-17',
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
    final text = message['content'] as String;
    final usage = data['usage'] as Map<String, dynamic>;

    return ReportResponse(
      text: text,
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
      },
    );

    final stream = response.data!.stream;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
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
      if (e.response?.statusCode == 401) return false;
      rethrow;
    }
  }

  Map<String, String> _headers(String apiKey) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  Map<String, dynamic> _buildRequestBody(ReportRequest request) {
    final userContent = StringBuffer();

    if (request.pseudonymizedPreviousReport != null &&
        request.pseudonymizedPreviousReport!.isNotEmpty) {
      userContent.writeln('## VORBERICHT (pseudonymisiert):');
      userContent.writeln(request.pseudonymizedPreviousReport);
      userContent.writeln();
    }

    userContent.writeln('## AKTUELLE STICHPUNKTE:');
    userContent.writeln(request.pseudonymizedNotes);

    return {
      'model': request.model,
      'temperature': request.temperature,
      'max_tokens': 8000,
      'messages': [
        {
          'role': 'system',
          'content': SystemPrompts.getPrompt(request.reportType),
        },
        {'role': 'user', 'content': userContent.toString()},
      ],
    };
  }
}
