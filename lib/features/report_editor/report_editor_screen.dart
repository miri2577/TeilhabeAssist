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

class ReportEditorScreen extends ConsumerStatefulWidget {
  const ReportEditorScreen({super.key});

  @override
  ConsumerState<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends ConsumerState<ReportEditorScreen> {
  String? _expandedModuleId;
  bool _showPreviousReport = false;
  final _previousReportController = TextEditingController();
  final _templateStorage = TemplateStorage();
  List<QualityIssue>? _qualityIssues;

  @override
  void initState() {
    super.initState();
    _initTemplateStorage();
  }

  Future<void> _initTemplateStorage() async {
    await _templateStorage.init();
  }

  @override
  void dispose() {
    _previousReportController.dispose();
    super.dispose();
  }

  void _runQualityCheck(ReportDraft draft) {
    setState(() {
      _qualityIssues = QualityChecker.checkDraft(draft);
    });
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
      SnackBar(
        content: Text(
          '${result.fileName} importiert (${result.pageCount} Seiten)',
        ),
      ),
    );
  }

  void _saveAsTemplate(ReportDraft draft) {
    showDialog(
      context: context,
      builder: (ctx) => SaveTemplateDialog(
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
    final templates = _templateStorage.getAll();
    showDialog(
      context: context,
      builder: (ctx) => LoadTemplateDialog(
        templates: templates,
        onSelect: (template) {
          ref.read(reportDraftNotifierProvider.notifier).createNew(template.reportType);
          // Module aus Template übernehmen
          for (final tm in template.modules) {
            ref.read(reportDraftNotifierProvider.notifier).updateModuleNotes(
              // Finde das passende Modul im Draft
              ref.read(reportDraftNotifierProvider)?.modules
                  .where((m) => m.type == tm.type)
                  .firstOrNull?.id ?? '',
              tm.defaultNotes,
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vorlage "${template.name}" geladen')),
          );
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftNotifierProvider);
    final theme = Theme.of(context);

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Neuer Bericht')),
        body: Center(
          child: _buildTypeSelector(theme),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(draft.type.label),
        actions: [
          // Qualitätsprüfung
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Qualitätsprüfung',
            onPressed: () => _runQualityCheck(draft),
          ),
          // Template speichern
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Als Vorlage speichern',
            onPressed: () => _saveAsTemplate(draft),
          ),
          const SizedBox(width: 8),
          // Generieren
          FilledButton.icon(
            onPressed: _canGenerate(draft)
                ? () => context.go('/generate')
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generieren'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Hauptbereich: Module
          Expanded(
            child: Column(
              children: [
                // Qualitäts-Panel
                if (_qualityIssues != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: QualityPanel(issues: _qualityIssues!),
                  ),

                // Alter Bericht Toggle
                _buildPreviousReportSection(draft, theme),
                const Divider(height: 1),

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
                                    .read(
                                        reportDraftNotifierProvider.notifier)
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
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 64,
              color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Berichtstyp wählen', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 32),
          for (final type in ReportType.values) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  type == ReportType.informationsbericht
                      ? Icons.article_outlined
                      : Icons.medical_information_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(type.label),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ref
                      .read(reportDraftNotifierProvider.notifier)
                      .createNew(type);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadTemplate,
            icon: const Icon(Icons.folder_open),
            label: const Text('Aus Vorlage erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousReportSection(ReportDraft draft, ThemeData theme) {
    return ExpansionTile(
      initiallyExpanded: _showPreviousReport,
      onExpansionChanged: (v) => setState(() => _showPreviousReport = v),
      leading: const Icon(Icons.history),
      title: const Text('Vorheriger Bericht (optional)'),
      subtitle: draft.previousReport.isEmpty
          ? const Text('Keinen Vorbericht eingefügt')
          : Text('${draft.previousReport.split('\n').length} Zeilen'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _importPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF importieren'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'oder Text manuell einfügen:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _previousReportController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Vorherigen Bericht hier einfügen (Copy & Paste)...\n\n'
                      'Dieser wird pseudonymisiert und der KI als Kontext '
                      'für die Fortschreibung mitgegeben.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) {
                  ref
                      .read(reportDraftNotifierProvider.notifier)
                      .updatePreviousReport(text);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canGenerate(ReportDraft draft) {
    return draft.modules.any((m) => m.notes.trim().isNotEmpty);
  }
}
