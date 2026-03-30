import 'package:flutter/material.dart';
import '../../models/pseudonym_mapping.dart';

class MappingDetailDialog extends StatelessWidget {
  final PseudonymMapping mapping;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const MappingDetailDialog({
    super.key,
    required this.mapping,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (mapping.confidence) {
      ConfidenceLevel.high => Colors.green,
      ConfidenceLevel.medium => Colors.orange,
      ConfidenceLevel.low => Colors.red,
    };
    final label = switch (mapping.confidence) {
      ConfidenceLevel.high => 'Hohe Konfidenz',
      ConfidenceLevel.medium => 'Mittlere Konfidenz',
      ConfidenceLevel.low => 'Niedrige Konfidenz (Verdacht)',
    };

    return AlertDialog(
      title: Text('Erkannte Daten: ${mapping.category.prefix}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Original:', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              mapping.original,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text('Ersetzt durch:', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              mapping.placeholder,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onReject != null)
          TextButton(
            onPressed: () {
              onReject!();
              Navigator.of(context).pop();
            },
            child: const Text('Ist kein personenbezogenes Datum'),
          ),
        if (onConfirm != null)
          FilledButton(
            onPressed: () {
              onConfirm!();
              Navigator.of(context).pop();
            },
            child: const Text('Ersetzung bestätigen'),
          ),
      ],
    );
  }
}
