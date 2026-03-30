import 'package:flutter/material.dart';
import '../services/quality_checker.dart';

class QualityPanel extends StatelessWidget {
  final List<QualityIssue> issues;
  final VoidCallback? onDismiss;

  const QualityPanel({super.key, required this.issues, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 8),
            const Text('Keine Qualitätsprobleme erkannt.'),
          ],
        ),
      );
    }

    final errors =
        issues.where((i) => i.severity == QualityIssueSeverity.error).toList();
    final warnings =
        issues.where((i) => i.severity == QualityIssueSeverity.warning).toList();
    final infos =
        issues.where((i) => i.severity == QualityIssueSeverity.info).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errors.isNotEmpty) _section(errors, 'Fehler', Colors.red, Icons.error),
        if (warnings.isNotEmpty)
          _section(warnings, 'Warnungen', Colors.orange, Icons.warning_amber),
        if (infos.isNotEmpty)
          _section(infos, 'Hinweise', Colors.blue, Icons.info_outline),
      ],
    );
  }

  Widget _section(
    List<QualityIssue> items,
    String title,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                '$title (${items.length})',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in items)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 4),
              child: Text('• ${issue.message}',
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
