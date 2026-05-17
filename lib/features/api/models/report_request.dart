import '../../report_editor/models/report_draft.dart';

class ReportRequest {
  final String apiKey;
  final String model;
  final ReportType reportType;
  final ReportSchema schema;
  final String pseudonymizedNotes;
  final String? pseudonymizedPreviousReport;
  final String? pseudonymizedReferenceReport;
  final double temperature;

  /// Pseudonymisierte Stammdaten als "verbindliche Schreibweisen".
  /// Werden im User-Content als kurze Tabelle oben angefügt — damit das
  /// LLM nicht aus dem Vorbericht abweichende Schreibweisen übernimmt.
  final Map<String, String> pseudonymizedStammdaten;

  const ReportRequest({
    required this.apiKey,
    required this.model,
    required this.reportType,
    this.schema = ReportSchema.ausfuehrlichTib,
    required this.pseudonymizedNotes,
    this.pseudonymizedPreviousReport,
    this.pseudonymizedReferenceReport,
    this.pseudonymizedStammdaten = const {},
    this.temperature = 0.3,
  });

  ReportRequest copyWith({ReportSchema? schema}) => ReportRequest(
        apiKey: apiKey,
        model: model,
        reportType: reportType,
        schema: schema ?? this.schema,
        pseudonymizedNotes: pseudonymizedNotes,
        pseudonymizedPreviousReport: pseudonymizedPreviousReport,
        pseudonymizedReferenceReport: pseudonymizedReferenceReport,
        pseudonymizedStammdaten: pseudonymizedStammdaten,
        temperature: temperature,
      );

  /// Zentral gebauter User-Message-Content, der **identisch** an Anthropic
  /// und OpenAI als Nutzerteil des Prompts gesendet wird. Der Generate-
  /// Screen verwendet diese Methode auch für die Pflicht-Preview, damit
  /// die Fachkraft 1:1 sieht, was das Gerät verlässt.
  String buildUserContent() {
    final buffer = StringBuffer();

    if (pseudonymizedStammdaten.isNotEmpty) {
      buffer.writeln(
        '## VERBINDLICHE STAMMDATEN — diese Schreibweisen sind im Bericht '
        'durchgängig zu verwenden, auch wenn der Vorbericht abweichende '
        'Varianten enthält:',
      );
      pseudonymizedStammdaten.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
      buffer.writeln();
    }

    if (pseudonymizedPreviousReport != null &&
        pseudonymizedPreviousReport!.isNotEmpty) {
      buffer.writeln('## VORBERICHT (pseudonymisiert):');
      buffer.writeln(pseudonymizedPreviousReport);
      buffer.writeln();
    }

    if (pseudonymizedReferenceReport != null &&
        pseudonymizedReferenceReport!.isNotEmpty) {
      buffer.writeln(
        '## REFERENZ-BERICHT (zur stilistischen Orientierung, '
        'pseudonymisiert):',
      );
      buffer.writeln(
        'Orientiere dich am Stil und Sprachduktus dieses Berichts.',
      );
      buffer.writeln(pseudonymizedReferenceReport);
      buffer.writeln();
    }

    buffer.writeln('## AKTUELLE STICHPUNKTE:');
    buffer.writeln(pseudonymizedNotes);

    return buffer.toString();
  }
}

class ReportResponse {
  final String text;
  final Map<String, dynamic>? structured;
  final int inputTokens;
  final int outputTokens;
  final String model;
  final String? stopReason;
  final int? cachedTokens;

  const ReportResponse({
    required this.text,
    this.structured,
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
