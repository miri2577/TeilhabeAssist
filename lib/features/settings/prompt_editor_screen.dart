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

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _infoController;
  late final TextEditingController _brpController;
  final _settingsStorage = SettingsStorage();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Aktuellen Prompt laden (benutzerdefiniert oder Default)
    _infoController = TextEditingController(
      text: SystemPrompts.getPrompt(ReportType.informationsbericht),
    );
    _brpController = TextEditingController(
      text: SystemPrompts.getPrompt(ReportType.brp),
    );

    _infoController.addListener(_onChanged);
    _brpController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _infoController.dispose();
    _brpController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final infoText = _infoController.text.trim();
    final brpText = _brpController.text.trim();

    // Nur speichern wenn vom Default abweichend
    final defaultInfo =
        SystemPrompts.getDefaultPrompt(ReportType.informationsbericht);
    final defaultBrp = SystemPrompts.getDefaultPrompt(ReportType.brp);

    _settingsStorage.customInfoPrompt =
        infoText == defaultInfo ? null : infoText;
    _settingsStorage.customBrpPrompt =
        brpText == defaultBrp ? null : brpText;

    // Prompts im laufenden Betrieb aktualisieren
    SystemPrompts.loadCustomPrompts(
      infoPrompt: infoText == defaultInfo ? null : infoText,
      brpPrompt: brpText == defaultBrp ? null : brpText,
    );

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompts gespeichert')),
      );
    }
  }

  void _resetToDefault(ReportType type) {
    final defaultPrompt = SystemPrompts.getDefaultPrompt(type);
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
                if (type == ReportType.informationsbericht) {
                  _infoController.text = defaultPrompt;
                } else {
                  _brpController.text = defaultPrompt;
                }
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
        title: const Text('System-Prompts bearbeiten'),
        actions: [
          if (_hasChanges)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Speichern'),
            ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informationsbericht'),
            Tab(text: 'BRP'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditor(
            theme,
            controller: _infoController,
            type: ReportType.informationsbericht,
          ),
          _buildEditor(
            theme,
            controller: _brpController,
            type: ReportType.brp,
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(
    ThemeData theme, {
    required TextEditingController controller,
    required ReportType type,
  }) {
    final isCustom =
        controller.text.trim() != SystemPrompts.getDefaultPrompt(type);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info-Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dieser Prompt wird als System-Anweisung an die KI gesendet. '
                    'Er bestimmt Struktur, Stil und Fachlichkeit des generierten Berichts.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Status + Reset-Button
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
                  onPressed: () => _resetToDefault(type),
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
          // Editor
          Expanded(
            child: TextField(
              controller: controller,
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
