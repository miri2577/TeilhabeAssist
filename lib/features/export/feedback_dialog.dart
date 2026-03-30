import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum FeedbackRating {
  minimal('Fast nichts geändert (< 10%)', 1),
  some('Einige Anpassungen (10–30%)', 2),
  much('Viel überarbeitet (30–60%)', 3),
  rewritten('Größtenteils neu geschrieben (> 60%)', 4);

  const FeedbackRating(this.label, this.value);
  final String label;
  final int value;
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  FeedbackRating? _rating;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == null) return;

    // Lokal speichern (anonym, keine Berichtsinhalte)
    final box = await Hive.openBox<String>('feedback');
    final entry = {
      'rating': _rating!.value,
      'comment': _commentController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await box.add(entry.toString());

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Wie war die Qualität?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wie viel musstest du am generierten Text verändern?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final rating in FeedbackRating.values)
            ListTile(
              leading: _rating == rating
                  ? Icon(Icons.radio_button_checked,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.radio_button_unchecked),
              title: Text(rating.label, style: const TextStyle(fontSize: 14)),
              dense: true,
              onTap: () => setState(() => _rating = rating),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Was war das Hauptproblem? (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Überspringen'),
        ),
        FilledButton(
          onPressed: _rating != null ? _submit : null,
          child: const Text('Absenden'),
        ),
      ],
    );
  }
}
