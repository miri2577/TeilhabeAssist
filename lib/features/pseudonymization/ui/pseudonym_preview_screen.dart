import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../report_editor/services/pdf_import_service.dart';
import '../models/pseudonym_mapping.dart';
import '../models/pseudonym_result.dart';
import '../providers/pseudonym_providers.dart';
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
  bool _isDragging = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    for (final xFile in details.files) {
      final path = xFile.path;
      final ext = path.split('.').last.toLowerCase();

      if (ext == 'pdf') {
        final bytes = await File(path).readAsBytes();
        final result = await PdfImportService.extractText(bytes, xFile.name, filePath: path);
        _textController.text = result.text;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${xFile.name} importiert')),
          );
        }
      } else if (ext == 'txt' || ext == 'md') {
        _textController.text = await File(path).readAsString();
      }
      setState(() {});
      break;
    }
  }

  Future<void> _importPdf() async {
    final result = await PdfImportService.pickAndExtract();
    if (result == null || !mounted) return;
    _textController.text = result.text;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.fileName} importiert (${result.pageCount} Seiten)')),
    );
  }

  void _runPseudonymization() {
    final engine = ref.read(pseudonymEngineProvider);
    final dictionary = ref.read(userDictionaryProvider);
    engine.loadUserDictionary(dictionary);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/'),
        ),
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
                child: DropTarget(
                  onDragDone: _handleFileDrop,
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  child: Container(
                    decoration: _isDragging
                        ? BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                            border: Border.all(color: theme.colorScheme.primary, width: 2),
                          )
                        : null,
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
                          'Text einfügen, PDF hierher ziehen oder importieren. '
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
                                  'Text hier einfügen, eingeben oder PDF hierher ziehen...',
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _importPdf,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('PDF importieren'),
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              onPressed: _textController.text.trim().isEmpty
                                  ? null
                                  : _runPseudonymization,
                              icon: const Icon(Icons.shield_outlined),
                              label: const Text('Pseudonymisierung starten'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Bitte prüfen (${result.warningCount}):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 4),
                    child: Text('• $w', style: theme.textTheme.bodySmall),
                  ),
                ).toList(),
              ),
            ),
          ),
        ],
        ),
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
    final dictionary = ref.read(userDictionaryProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Erkannt: "${mapping.original}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategorie: ${mapping.category.prefix}'),
            const SizedBox(height: 4),
            Text('Ersetzt durch: ${mapping.placeholder}'),
            const SizedBox(height: 4),
            Text(
              'Konfidenz: ${mapping.confidence.name}',
              style: TextStyle(
                color: switch (mapping.confidence) {
                  ConfidenceLevel.high => Colors.green,
                  ConfidenceLevel.medium => Colors.orange,
                  ConfidenceLevel.low => Colors.red,
                },
              ),
            ),
          ],
        ),
        actions: [
          // Kein Name → ins Wörterbuch, nicht mehr flaggen
          TextButton.icon(
            onPressed: () async {
              await dictionary.excludeWord(mapping.original);
              _rejectMapping(mapping);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${mapping.original}" wird ab jetzt NICHT mehr als Name erkannt'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Kein Name – nie mehr erkennen'),
          ),
          // Nur diesmal entfernen
          TextButton(
            onPressed: () {
              _rejectMapping(mapping);
              Navigator.of(ctx).pop();
            },
            child: const Text('Nur diesmal entfernen'),
          ),
          // Ist ein Name → lernen
          FilledButton.icon(
            onPressed: () async {
              await dictionary.learnName(mapping.original);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${mapping.original}" als Name gelernt – wird zukünftig erkannt'),
                ),
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Ist ein Name – immer erkennen'),
          ),
        ],
      ),
    );
  }

  void _rejectMapping(PseudonymMapping mapping) {
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
  }

  void _onRelease() {
    final result = ref.read(pseudonymResultProvider);
    if (result == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Pseudonymisierung erfolgreich'),
        content: Text(
          '${result.totalReplacements} Ersetzungen durchgeführt.\n'
          '${result.warningCount} Warnungen.\n\n'
          'Der Text kann jetzt sicher an die API gesendet werden.\n'
          'Nutze den Berichtseditor für die vollständige Generierung.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
