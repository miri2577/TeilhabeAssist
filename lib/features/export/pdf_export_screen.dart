import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../report_editor/models/report_draft.dart';
import '../report_editor/providers/report_providers.dart';
import 'feedback_dialog.dart';
import 'services/form_filler_service.dart';
import 'services/pdf_generator.dart';

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key});

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
  bool _feedbackShown = false;
  _ExportMode _mode = _ExportMode.professional;
  bool _generating = false;
  Uint8List? _pdfBytes;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftNotifierProvider);
    final theme = Theme.of(context);

    if (draft == null || draft.generatedText == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/editor'),
          ),
          title: const Text('Export'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Kein generierter Bericht vorhanden.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/editor'),
                child: const Text('Zurück zum Editor'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/editor'),
        ),
        title: const Text('Bericht exportieren'),
      ),
      body: _pdfBytes != null
          ? _buildPreview()
          : _buildModeSelector(draft, theme),
    );
  }

  Widget _buildModeSelector(ReportDraft draft, ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 64,
                  color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Export-Format wählen',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${draft.type.label} – ${draft.generatedText!.split(' ').length} Wörter',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Option 1: Professionelles PDF
              _exportOption(
                theme,
                icon: Icons.description,
                title: 'Professionelles PDF',
                subtitle: 'Eigenständiges, druckfertiges A4-Dokument mit '
                    'professionellem Layout',
                selected: _mode == _ExportMode.professional,
                onTap: () => setState(() => _mode = _ExportMode.professional),
              ),
              const SizedBox(height: 12),

              // Option 2: Original-Formular befüllen
              _exportOption(
                theme,
                icon: Icons.edit_document,
                title: 'Original-Formular befüllen',
                subtitle: draft.type == ReportType.informationsbericht
                    ? 'Informationsbericht v1.01 – Offizielles Berliner Formular'
                    : 'BRP Ges 100 – Offizielles Berliner Formular',
                selected: _mode == _ExportMode.formFill,
                onTap: () => setState(() => _mode = _ExportMode.formFill),
              ),
              const SizedBox(height: 12),

              // Option 3: TXT
              _exportOption(
                theme,
                icon: Icons.text_snippet_outlined,
                title: 'Nur Text (TXT)',
                subtitle: 'Reiner Text zum Kopieren in andere Programme',
                selected: _mode == _ExportMode.txt,
                onTap: () => setState(() => _mode = _ExportMode.txt),
              ),
              const SizedBox(height: 12),

              // Option 4: Zwischenablage
              _exportOption(
                theme,
                icon: Icons.copy,
                title: 'In Zwischenablage kopieren',
                subtitle: 'Text direkt zum Einfügen in Formulare',
                selected: _mode == _ExportMode.clipboard,
                onTap: () => setState(() => _mode = _ExportMode.clipboard),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _generating ? null : () => _export(draft),
                  icon: _generating
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(_generating ? 'Wird erstellt...' : 'Exportieren'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon,
            color: selected ? theme.colorScheme.primary : null),
        title: Text(title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: selected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildPreview() {
    return PdfPreview(
      build: (_) async => _pdfBytes!,
      pdfFileName: _generateFileName(),
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _pdfBytes = null),
          tooltip: 'Zurück zur Auswahl',
        ),
      ],
    );
  }

  Future<void> _export(ReportDraft draft) async {
    setState(() => _generating = true);

    try {
      final text = draft.generatedText!;
      final metadata = _buildMetadata(draft);

      switch (_mode) {
        case _ExportMode.professional:
          final bytes = await PdfGenerator.generateInformationsbericht(
            generatedText: text,
            metadata: metadata,
          );
          setState(() => _pdfBytes = bytes);

        case _ExportMode.formFill:
          Uint8List bytes;
          if (draft.type == ReportType.informationsbericht) {
            bytes = await FormFillerService.fillInformationsbericht(
              generatedText: text,
              metadata: metadata,
            );
          } else {
            bytes = await FormFillerService.fillBrp(
              generatedText: text,
              metadata: metadata,
            );
          }
          setState(() => _pdfBytes = bytes);

        case _ExportMode.txt:
          final path = await FilePicker.platform.saveFile(
            dialogTitle: 'Bericht als Text speichern',
            fileName: _generateFileName(ext: 'txt'),
          );
          if (path != null) {
            await File(path).writeAsString(text);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Textdatei gespeichert')),
              );
            }
          }

        case _ExportMode.clipboard:
          await Clipboard.setData(ClipboardData(text: text));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Text in die Zwischenablage kopiert')),
            );
          }
      }

      _showFeedback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export-Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Map<String, String> _buildMetadata(ReportDraft draft) {
    // Metadaten aus den Modul-Notes extrahieren (Kopfdaten + Persondaten)
    final kopf = draft.modules
        .where((m) => m.type.name == 'kopfdaten')
        .firstOrNull?.notes ?? '';
    final person = draft.modules
        .where((m) => m.type.name == 'persondaten')
        .firstOrNull?.notes ?? '';

    return {
      'name': person.isNotEmpty ? person.split('\n').first : '',
      'berichtszeitraum': '',
      'leistungstyp': draft.type.label,
      'leistungserbringer': '',
      'familienname': '',
      'vorname': '',
      'geburtsdatum': '',
      'strasse': '',
      'plz_ort': '',
      'telefon': '',
      'id_kostenuebernahme': '',
      'kontakt_le': '',
    };
  }

  String _generateFileName({String ext = 'pdf'}) {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return 'Bericht_$date.$ext';
  }

  void _showFeedback() {
    if (_feedbackShown) return;
    _feedbackShown = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => const FeedbackDialog(),
        );
      }
    });
  }
}

enum _ExportMode { professional, formFill, txt, clipboard }
