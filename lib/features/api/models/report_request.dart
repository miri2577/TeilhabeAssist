import '../../report_editor/models/report_draft.dart';

class ReportRequest {
  final String apiKey;
  final String model;
  final ReportType reportType;
  final String pseudonymizedNotes;
  final String? pseudonymizedPreviousReport;
  final double temperature;

  const ReportRequest({
    required this.apiKey,
    required this.model,
    required this.reportType,
    required this.pseudonymizedNotes,
    this.pseudonymizedPreviousReport,
    this.temperature = 0.3,
  });
}

class ReportResponse {
  final String text;
  final int inputTokens;
  final int outputTokens;
  final String model;
  final String? stopReason;
  final int? cachedTokens;

  const ReportResponse({
    required this.text,
    required this.inputTokens,
    required this.outputTokens,
    required this.model,
    this.stopReason,
    this.cachedTokens,
  });

  int get totalTokens => inputTokens + outputTokens;

  /// Echte Kosten basierend auf dem verwendeten Modell
  double get costUsd {
    final prices = _modelPrices[model] ?? _modelPrices[_matchModel(model)];
    if (prices == null) return 0;

    final inputCost = inputTokens * prices.$1 / 1000000;
    final outputCost = outputTokens * prices.$2 / 1000000;
    // Cached tokens kosten 90% weniger (Anthropic Prompt-Caching)
    final cachedSaving = (cachedTokens ?? 0) * prices.$1 * 0.9 / 1000000;

    return inputCost + outputCost - cachedSaving;
  }

  double get costEur => costUsd * 0.92; // Ungefährer Wechselkurs

  String get costDisplay {
    if (costEur < 0.01) return '< 0,01 €';
    return '${costEur.toStringAsFixed(3)} €';
  }

  String get tokenDisplay =>
      '$inputTokens input + $outputTokens output = $totalTokens total';

  /// Modell-Preise: (input $/1M, output $/1M)
  static const _modelPrices = <String, (double, double)>{
    // Anthropic
    'claude-sonnet-4-20250514': (3.0, 15.0),
    'claude-haiku-4-5-20251001': (1.0, 5.0),
    // OpenAI
    'gpt-5.4-2026-03-05': (2.5, 10.0),
    'gpt-5.4-mini-2026-03-17': (0.4, 1.6),
    'gpt-5.4-nano-2026-03-17': (0.1, 0.4),
    'o3': (10.0, 40.0),
    'gpt-4o': (2.5, 10.0),
    'gpt-4o-mini': (0.15, 0.6),
  };

  static String? _matchModel(String model) {
    for (final key in _modelPrices.keys) {
      if (model.startsWith(key.split('-').take(2).join('-'))) return key;
    }
    return null;
  }
}
