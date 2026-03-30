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

  const ReportResponse({
    required this.text,
    required this.inputTokens,
    required this.outputTokens,
    required this.model,
    this.stopReason,
  });

  double get estimatedCostUsd {
    // Sonnet 4.6 Preise
    final inputCost = inputTokens * 3.0 / 1000000;
    final outputCost = outputTokens * 15.0 / 1000000;
    return inputCost + outputCost;
  }
}
