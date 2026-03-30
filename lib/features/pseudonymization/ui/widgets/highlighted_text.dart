import 'package:flutter/material.dart';
import '../../models/pseudonym_mapping.dart';
import '../../models/pseudonym_result.dart';

class HighlightedText extends StatelessWidget {
  final PseudonymResult result;
  final void Function(PseudonymMapping mapping)? onTapMapping;

  const HighlightedText({
    super.key,
    required this.result,
    this.onTapMapping,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = _buildSpans(context);

    return SelectableText.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final text = result.cleanText;
    final spans = <InlineSpan>[];

    // Finde alle Platzhalter im Text und ersetze sie durch farbige Spans
    final placeholderPattern = RegExp(r'\[[A-Z]+_\d{3}\]');
    var lastEnd = 0;

    for (final match in placeholderPattern.allMatches(text)) {
      // Text vor dem Platzhalter
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Platzhalter mit Farbe
      final placeholder = match.group(0)!;
      final mapping = result.mappings.where(
        (m) => m.placeholder == placeholder,
      );

      if (mapping.isNotEmpty) {
        final m = mapping.first;
        final color = _colorForConfidence(m.confidence, context);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onTapMapping != null ? () => onTapMapping!(m) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  placeholder,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(
          text: placeholder,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      }

      lastEnd = match.end;
    }

    // Restlicher Text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  Color _colorForConfidence(ConfidenceLevel confidence, BuildContext context) {
    return switch (confidence) {
      ConfidenceLevel.high => Colors.green.shade700,
      ConfidenceLevel.medium => Colors.orange.shade700,
      ConfidenceLevel.low => Colors.red.shade600,
    };
  }
}
