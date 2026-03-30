import 'pseudonym_mapping.dart';

class PseudonymResult {
  final String cleanText;
  final List<PseudonymMapping> mappings;
  final List<String> warnings;

  const PseudonymResult({
    required this.cleanText,
    required this.mappings,
    this.warnings = const [],
  });

  int get totalReplacements => mappings.length;

  int get highConfidenceCount =>
      mappings.where((m) => m.confidence == ConfidenceLevel.high).length;

  int get warningCount => warnings.length;
}
