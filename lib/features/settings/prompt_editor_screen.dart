import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/settings_storage.dart';
import '../api/prompts/system_prompts.dart';
import '../report_editor/models/report_draft.dart';

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen({super.key});

  @override
  ConsumerState<PromptEditorScreen> createState() =>
      _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  late final TextEditingController _infoController;
  final _settingsStorage = SettingsStorage();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _infoController = TextEditingController(
      text: SystemPrompts.getPrompt(ReportType.informationsbericht),
    );
    _infoController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final infoText = _infoController.text.trim();
    final defaultInfo =
        SystemPrompts.getDefaultPrompt(ReportType.informationsbericht);

    _settingsStorage.customInfoPrompt =
        infoText == defaultInfo ? null : infoText;

    SystemPrompts.loadCustomPrompts(
      infoPrompt: infoText == defaultInfo ? null : infoText,
    );

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompt gespeichert')),
      );
    }
  }

  void _resetToDefault() {
    final defaultPrompt =
        SystemPrompts.getDefaultPrompt(ReportType.informationsbericht);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auf Standard zurücksetzen?'),
        content: const Text(
          'Der benutzerdefinierte Prompt wird durch den '
          'Standard-Prompt ersetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _infoController.text = defaultPrompt;
              });
            },
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = _infoController.text.trim() !=
        SystemPrompts.getDefaultPrompt(ReportType.informationsbericht);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              _showUnsavedDialog();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('System-Prompt bearbeiten'),
        actions: [
          if (_hasChanges)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Speichern'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dieser Prompt wird als System-Anweisung an die KI '
                      'gesendet. Er bestimmt Struktur, Stil und Fachlichkeit '
                      'des generierten Berichts.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isCustom) ...[
                  Chip(
                    avatar: const Icon(Icons.edit, size: 16),
                    label: const Text('Benutzerdefiniert'),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Standard wiederherstellen'),
                  ),
                ] else
                  Chip(
                    avatar: const Icon(Icons.check, size: 16),
                    label: const Text('Standard-Prompt'),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _infoController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'System-Prompt eingeben...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnsavedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
            'Möchtest du die Änderungen speichern oder verwerfen?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/settings');
            },
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _save().then((_) {
                if (mounted) context.pop();
              });
            },
            child: const Text('Speichern & Zurück'),
          ),
        ],
      ),
    );
  }
}
