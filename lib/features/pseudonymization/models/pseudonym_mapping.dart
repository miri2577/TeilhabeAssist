import 'pseudonym_category.dart';

enum ConfidenceLevel { high, medium, low }

class PseudonymMapping {
  final String placeholder;
  final String original;
  final PseudonymCategory category;
  final ConfidenceLevel confidence;
  final int startIndex;
  final int endIndex;

  const PseudonymMapping({
    required this.placeholder,
    required this.original,
    required this.category,
    this.confidence = ConfidenceLevel.high,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson() => {
        'placeholder': placeholder,
        'original': original,
        'category': category.name,
        'confidence': confidence.name,
      };

  factory PseudonymMapping.fromJson(Map<String, dynamic> json) {
    return PseudonymMapping(
      placeholder: json['placeholder'] as String,
      original: json['original'] as String,
      category: PseudonymCategory.values.byName(json['category'] as String),
      confidence: ConfidenceLevel.values.byName(json['confidence'] as String),
      startIndex: 0,
      endIndex: 0,
    );
  }
}
