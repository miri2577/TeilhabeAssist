import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models/report_draft.dart';
import 'models/report_module.dart';
import 'providers/report_providers.dart';
import 'services/pdf_import_service.dart';
import 'services/quality_checker.dart';
import 'services/template_storage.dart';
import 'widgets/module_card.dart';
import 'widgets/module_palette.dart';
import 'widgets/quality_panel.dart';
import 'widgets/template_dialog.dart';

/// Einstiegs-Auswahl
enum EditorMode { initial, erstbericht, folgebericht }

class ReportEditorScreen extends ConsumerStatefulWidget {
  const ReportEditorScreen({super.key});

  @override
  ConsumerState<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends ConsumerState<ReportEditorScreen> {
  EditorMode _mode = EditorMode.initial;
  String? _expandedModuleId;
  bool _isDragging = false;
  final _previousReportController = TextEditingController();
  final _notesController = TextEditingController();
  final _templateStorage = TemplateStorage();
  List<QualityIssue>? _qualityIssues;

  @override
  void initState() {
    super.initState();
    _templateStorage.init();
  }

  @override
  void dispose() {
    _previousReportController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- File Drop / Import ---

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    for (final xFile in details.files) {
      final path = xFile.path;
      final ext = path.split('.').last.toLowerCase();
      String extractedText;
      String fileName = xFile.name;

      if (ext == 'pdf') {
        final bytes = await File(path).readAsBytes();
        final result = await PdfImportService.extractText(bytes, fileName, filePath: path);
        extractedText = result.text;
        fileName = '${result.fileName} (${result.pageCount} Seiten)';
      } else if (ext == 'txt' || ext == 'md') {
        extractedText = await File(path).readAsString();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('.$ext nicht unterstützt – bitte PDF oder TXT.')),
          );
        }
        continue;
      }

      if (extractedText.isNotEmpty) {
        _previousReportController.text = extractedText;
        ref
            .read(reportDraftNotifierProvider.notifier)
            .updatePreviousReport(extractedText);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName importiert')),
        );
      }
      break;
    }
  }

  Future<void> _importPdf() async {
    final result = await PdfImportService.pickAndExtract();
    if (result == null || !mounted) return;
    _previousReportController.text = result.text;
    ref
        .read(reportDraftNotifierProvider.notifier)
        .updatePreviousReport(result.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.fileName} importiert (${result.pageCount} Seiten)')),
    );
  }

  // --- Template ---

  void _saveAsTemplate(ReportDraft draft) {
    showDialog(
      context: context,
      builder: (_) => SaveTemplateDialog(
        draft: draft,
        onSave: (template) async {
          await _templateStorage.save(template);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Vorlage "${template.name}" gespeichert')),
            );
          }
        },
      ),
    );
  }

  void _loadTemplate() {
    showDialog(
      context: context,
      builder: (_) => LoadTemplateDialog(
        templates: _templateStorage.getAll(),
        onSelect: (template) {
          // Kompletten Draft aus Template erzeugen (inkl. aller Module + Notes)
          final notifier = ref.read(reportDraftNotifierProvider.notifier);
          notifier.loadFromTemplate(template);
          setState(() => _mode = EditorMode.erstbericht);
        },
        onDelete: (id) async {
          await _templateStorage.delete(id);
          if (!mounted) return;
          Navigator.of(context).pop();
          _loadTemplate();
        },
      ),
    );
  }

  // --- Erstbericht starten ---

  void _startErstbericht(ReportType type) {
    ref.read(reportDraftNotifierProvider.notifier).createNew(type);
    setState(() => _mode = EditorMode.erstbericht);
  }

  // --- Folgebericht starten ---

  void _startFolgebericht(ReportType type) {
    ref.read(reportDraftNotifierProvider.notifier).createNew(type);
    setState(() => _mode = EditorMode.folgebericht);
  }

  // --- Notizen in Draft übernehmen ---

  void _syncNotesToDraft() {
    ref
        .read(reportDraftNotifierProvider.notifier)
        .updateCurrentNotes(_notesController.text);
  }

  // --- Referenz-Bericht ---

  Future<void> _importReferenceReport() async {
    final result = await PdfImportService.pickAndExtract();
    if (result == null || !mounted) return;
    ref
        .read(reportDraftNotifierProvider.notifier)
        .updateReferenceReport(result.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Referenz-Bericht geladen: ${result.fileName}')),
    );
  }

  Widget _buildReferenceReportSection(ThemeData theme, ReportDraft draft) {
    final hasRef = draft.referenceReport.isNotEmpty;

    if (!hasRef) {
      return OutlinedButton.icon(
        onPressed: _importReferenceReport,
        icon: const Icon(Icons.style, size: 18),
        label: const Text('Referenz-Bericht laden (optional)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final wordCount = draft.referenceReport
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.style, color: Colors.purple.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Referenz-Bericht geladen ($wordCount Wörter) – '
              'KI orientiert sich am Stil',
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              ref
                  .read(reportDraftNotifierProvider.notifier)
                  .updateReferenceReport('');
            },
            tooltip: 'Referenz entfernen',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftNotifierProvider);
    final theme = Theme.of(context);

    return switch (_mode) {
      EditorMode.initial => _buildInitialScreen(theme),
      EditorMode.folgebericht when draft != null && draft.previousReport.isEmpty =>
        _buildDropScreen(theme, draft),
      _ when draft != null => _buildEditorScreen(theme, draft),
      _ => _buildInitialScreen(theme),
    };
  }

  // ========== SCREEN 1: Erstbericht oder Folgebericht? ==========

  Widget _buildInitialScreen(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Neuer Bericht'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 72,
                    color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Was möchtest du erstellen?',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Wähle zuerst den Berichtstyp und ob ein Vorbericht vorliegt.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Berichtstyp
                for (final type in ReportType.values) ...[
                  Text(type.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _choiceCard(
                          theme,
                          icon: Icons.add_circle_outline,
                          title: 'Erstbericht',
                          subtitle: 'Komplett neuer Bericht',
                          onTap: () => _startErstbericht(type),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _choiceCard(
                          theme,
                          icon: Icons.update,
                          title: 'Folgebericht',
                          subtitle: 'Basierend auf Vorbericht',
                          onTap: () => _startFolgebericht(type),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                const Divider(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadTemplate,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Aus Vorlage erstellen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ========== SCREEN 2: Vorbericht importieren (Drag & Drop) ==========

  Widget _buildDropScreen(ThemeData theme, ReportDraft draft) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _mode = EditorMode.initial),
        ),
        title: const Text('Vorbericht importieren'),
      ),
      body: DropTarget(
        onDragDone: _handleFileDrop,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text('Vorherigen Bericht laden',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Der Vorbericht dient als Grundlage. Die KI vergleicht ihn '
                    'mit deinen Notizen und erstellt den Folgebericht.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Drop-Zone
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _isDragging
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isDragging
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: _isDragging ? 3 : 1.5,
                        ),
                      ),
                      child: _previousReportController.text.isEmpty
                          ? _buildEmptyDropZone(theme)
                          : _buildFilledDropZone(theme),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Aktions-Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _importPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF auswählen'),
                      ),
                      const SizedBox(width: 12),
                      if (_previousReportController.text.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () {
                            // Weiter zum Editor
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Weiter'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDropZone(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.file_download_outlined, size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text('PDF oder Textdatei hierher ziehen',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const SizedBox(height: 8),
        Text('oder Text unten einfügen',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TextField(
            controller: _previousReportController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Oder Vorbericht hier einfügen (Copy & Paste)...',
              border: OutlineInputBorder(),
            ),
            onChanged: (text) {
              ref
                  .read(reportDraftNotifierProvider.notifier)
                  .updatePreviousReport(text);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilledDropZone(ThemeData theme) {
    final draft = ref.read(reportDraftNotifierProvider);
    final reportText = draft?.previousReport ?? _previousReportController.text;
    final charCount = reportText.length;
    final wordCount = reportText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text('Vorbericht geladen ($wordCount Wörter, $charCount Zeichen)',
                  style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _previousReportController.clear();
                  ref
                      .read(reportDraftNotifierProvider.notifier)
                      .updatePreviousReport('');
                  setState(() {});
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Entfernen'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  reportText,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SCREEN 3: Editor (Module + Notizen) ==========

  Widget _buildEditorScreen(ThemeData theme, ReportDraft draft) {
    final isFollowUp = _mode == EditorMode.folgebericht;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(reportDraftNotifierProvider.notifier).createNew(draft.type);
            setState(() => _mode = EditorMode.initial);
          },
        ),
        title: Text(isFollowUp
            ? '${draft.type.label} – Folgebericht'
            : '${draft.type.label} – Erstbericht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Qualitätsprüfung',
            onPressed: () => setState(() {
              _qualityIssues = QualityChecker.checkDraft(draft);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Als Vorlage speichern',
            onPressed: () => _saveAsTemplate(draft),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _canGenerate(draft) ? () {
              _syncNotesToDraft();
              context.push('/generate');
            } : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generieren'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: DropTarget(
        onDragDone: _handleFileDrop,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Qualitäts-Panel
                      if (_qualityIssues != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: QualityPanel(issues: _qualityIssues!),
                        ),

                      // Vorbericht-Hinweis (Folgebericht)
                      if (isFollowUp && draft.previousReport.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.06),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vorbericht geladen '
                                  '(${draft.previousReport.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} Wörter). '
                                  'Trage unten die aktuellen Veränderungen als Stichpunkte ein.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Freies Notizfeld (Folgebericht)
                      if (isFollowUp) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: TextField(
                            controller: _notesController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Aktuelle Notizen / Veränderungen',
                              hintText:
                                  'Was hat sich seit dem letzten Bericht verändert?\n'
                                  '• Neue Ziele, Fortschritte, Rückschritte\n'
                                  '• Änderungen in der Lebenssituation\n'
                                  '• FLS-Anpassungen',
                              hintMaxLines: 5,
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (text) {
                              // Notizen live in allgemeineInfos-Modul schreiben
                              _syncNotesToDraft();
                            },
                          ),
                        ),
                        const Divider(height: 24),
                      ],

                      // Referenz-Bericht (optional)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _buildReferenceReportSection(theme, draft),
                      ),

                      // Module (ReorderableListView)
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: draft.modules.length,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(reportDraftNotifierProvider.notifier)
                                .reorderModules(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final module = draft.modules[index];
                            return ModuleCard(
                              key: ValueKey(module.id),
                              module: module,
                              expanded: _expandedModuleId == module.id,
                              onToggleExpand: () {
                                setState(() {
                                  _expandedModuleId =
                                      _expandedModuleId == module.id
                                          ? null
                                          : module.id;
                                });
                              },
                              onNotesChanged: (notes) {
                                ref
                                    .read(reportDraftNotifierProvider.notifier)
                                    .updateModuleNotes(module.id, notes);
                              },
                              onRemove: module.type.required
                                  ? null
                                  : () {
                                      ref
                                          .read(reportDraftNotifierProvider
                                              .notifier)
                                          .removeModule(module.id);
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Palette (rechts)
                ModulePalette(
                  onAddModule: (type, domain) {
                    final notifier =
                        ref.read(reportDraftNotifierProvider.notifier);
                    if (type == ModuleType.teilhabeziel) {
                      notifier.addGoal();
                    } else if (type == ModuleType.icfDomain && domain != null) {
                      notifier.addIcfDomain(domain);
                    } else {
                      notifier.addModule(ReportModule(type: type));
                    }
                  },
                ),
              ],
            ),

            // Drag & Drop Overlay
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined,
                              size: 64, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('Bericht hier ablegen',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _canGenerate(ReportDraft draft) {
    if (_mode == EditorMode.folgebericht) {
      return draft.previousReport.isNotEmpty;
    }
    return draft.modules.any((m) => m.notes.trim().isNotEmpty);
  }
}
