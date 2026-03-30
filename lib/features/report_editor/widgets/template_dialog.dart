import 'package:flutter/material.dart';
import '../models/report_draft.dart';
import '../models/report_template.dart';

/// Dialog zum Speichern eines Templates aus dem aktuellen Entwurf
class SaveTemplateDialog extends StatefulWidget {
  final ReportDraft draft;
  final ValueChanged<ReportTemplate> onSave;

  const SaveTemplateDialog({
    super.key,
    required this.draft,
    required this.onSave,
  });

  @override
  State<SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<SaveTemplateDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vorlage speichern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Die aktuelle Modul-Anordnung und Stichpunkte werden '
            'als wiederverwendbare Vorlage gespeichert.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name der Vorlage',
              hintText: 'z.B. "BEW Standardbericht" oder "Team Neukölln"',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.draft.modules.length} Module, '
            'Typ: ${widget.draft.type.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            final template = ReportTemplate.fromDraft(widget.draft, name);
            widget.onSave(template);
            Navigator.of(context).pop();
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Dialog zum Laden eines gespeicherten Templates
class LoadTemplateDialog extends StatelessWidget {
  final List<ReportTemplate> templates;
  final ValueChanged<ReportTemplate> onSelect;
  final ValueChanged<String> onDelete;

  const LoadTemplateDialog({
    super.key,
    required this.templates,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Vorlage laden'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: templates.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open, size: 48,
                        color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    const Text('Keine Vorlagen gespeichert.'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        template.reportType == ReportType.informationsbericht
                            ? Icons.article_outlined
                            : Icons.medical_information_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(template.name),
                      subtitle: Text(
                        '${template.reportType.label} • '
                        '${template.modules.length} Module • '
                        '${_formatDate(template.createdAt)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => onDelete(template.id),
                      ),
                      onTap: () {
                        onSelect(template);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
