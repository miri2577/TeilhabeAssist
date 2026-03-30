import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pseudonym_mapping.dart';
import '../models/pseudonym_result.dart';
import '../providers/pseudonym_providers.dart';
import 'widgets/confirmation_dialog.dart';
import 'widgets/highlighted_text.dart';

class PseudonymPreviewScreen extends ConsumerStatefulWidget {
  const PseudonymPreviewScreen({super.key});

  @override
  ConsumerState<PseudonymPreviewScreen> createState() =>
      _PseudonymPreviewScreenState();
}

class _PseudonymPreviewScreenState
    extends ConsumerState<PseudonymPreviewScreen> {
  final _textController = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _runPseudonymization() {
    final engine = ref.read(pseudonymEngineProvider);
    final result = engine.pseudonymize(_textController.text);
    ref.read(pseudonymResultProvider.notifier).state = result;
    setState(() => _confirmed = false);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(pseudonymResultProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pseudonymisierung'),
        actions: [
          if (result != null)
            FilledButton.icon(
              onPressed: _confirmed ? _onRelease : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Für API freigeben'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Linke Seite: Eingabe
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Originaltext eingeben',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Füge hier den Bericht oder Stichpunkte ein. '
                        'Personenbezogene Daten werden automatisch erkannt.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText:
                                'Text hier einfügen oder eingeben...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _textController.text.trim().isEmpty
                            ? null
                            : _runPseudonymization,
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Pseudonymisierung starten'),
                      ),
                    ],
                  ),
                ),
              ),

              const VerticalDivider(width: 1),

              // Rechte Seite: Vorschau
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: result == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.preview_outlined,
                                size: 64,
                                color: theme.colorScheme.outlineVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Vorschau des pseudonymisierten Textes',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildPreview(result, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(PseudonymResult result, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status-Zeile
        _buildStatusBar(result, theme),
        const SizedBox(height: 12),

        // Warnings
        if (result.warnings.isNotEmpty) ...[
          _buildWarnings(result, theme),
          const SizedBox(height: 12),
        ],

        // Legende
        _buildLegend(theme),
        const SizedBox(height: 12),

        // Pseudonymisierter Text
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: HighlightedText(
                result: result,
                onTapMapping: (mapping) => _showMappingDetail(mapping),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pflicht-Bestätigung
        CheckboxListTile(
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'Ich habe den Text geprüft und bestätige, dass keine '
            'personenbezogenen Daten mehr enthalten sind.',
          ),
          tileColor: _confirmed
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(PseudonymResult result, ThemeData theme) {
    return Wrap(
      spacing: 12,
      children: [
        Chip(
          avatar: const Icon(Icons.check_circle, size: 18),
          label: Text('${result.totalReplacements} Ersetzungen'),
          backgroundColor: Colors.green.withValues(alpha: 0.1),
        ),
        if (result.warningCount > 0)
          Chip(
            avatar: const Icon(Icons.warning_amber, size: 18),
            label: Text('${result.warningCount} Warnungen'),
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
          ),
      ],
    );
  }

  Widget _buildWarnings(PseudonymResult result, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bitte prüfen:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text('• $w', style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      children: [
        _legendItem(Colors.green.shade700, 'Sicher erkannt'),
        const SizedBox(width: 16),
        _legendItem(Colors.orange.shade700, 'Mittlere Konfidenz'),
        const SizedBox(width: 16),
        _legendItem(Colors.red.shade600, 'Verdachtsstelle'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  void _showMappingDetail(PseudonymMapping mapping) {
    showDialog(
      context: context,
      builder: (ctx) => MappingDetailDialog(
        mapping: mapping,
        onConfirm: () {
          // Bestätigung – Mapping bleibt
        },
        onReject: () {
          // Verwerfen – Mapping entfernen und Text rekonstruieren
          final result = ref.read(pseudonymResultProvider);
          if (result != null) {
            final newCleanText = result.cleanText.replaceAll(
              mapping.placeholder,
              mapping.original,
            );
            final newMappings = result.mappings
                .where((m) => m.placeholder != mapping.placeholder)
                .toList();
            ref.read(pseudonymResultProvider.notifier).state = PseudonymResult(
              cleanText: newCleanText,
              mappings: newMappings,
              warnings: result.warnings,
            );
          }
        },
      ),
    );
  }

  void _onRelease() {
    // TODO: Pseudonymisierten Text an API-Modul weiterleiten
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text für API freigegeben (API-Modul noch nicht implementiert)'),
      ),
    );
  }
}
