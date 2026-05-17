import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../api/providers/api_providers.dart';
import '../report_editor/models/report_draft.dart';
import '../report_editor/providers/report_providers.dart';
import 'services/pdf_generator.dart';

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key});

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
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
            onPressed: () => context.pop(),
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
                onPressed: () => context.pop(),
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
          onPressed: () => context.pop(),
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

              // Option 2: TXT
              _exportOption(
                theme,
                icon: Icons.text_snippet_outlined,
                title: 'Nur Text (TXT)',
                subtitle: 'Reiner Text zum Kopieren in andere Programme',
                selected: _mode == _ExportMode.txt,
                onTap: () => setState(() => _mode = _ExportMode.txt),
              ),
              const SizedBox(height: 12),

              // Option 3: Zwischenablage
              _exportOption(
                theme,
                icon: Icons.copy,
                title: 'In Zwischenablage kopieren',
                subtitle: 'Text direkt zum Einfügen in Formulare',
                selected: _mode == _ExportMode.clipboard,
                onTap: () => setState(() => _mode = _ExportMode.clipboard),
              ),

              const SizedBox(height: 24),

              // Hinweis: kein automatisches Befüllen des Original-PDF
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Für die offizielle Berliner Vorlage: relevante '
                        'Textstellen aus der Vorschau bzw. dem TXT-Export '
                        'in das Original-PDF einfügen (Adobe Acrobat / '
                        'PDF-Editor). Das eigene Layout enthält bereits '
                        'alle Strukturen für Druck und Unterschrift.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
        IconButton(
          icon: const Icon(Icons.save_as),
          onPressed: _saveAs,
          tooltip: 'Speichern unter...',
        ),
      ],
    );
  }

  Future<void> _saveAs() async {
    if (_pdfBytes == null) return;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'PDF speichern unter...',
      fileName: _generateFileName(),
      allowedExtensions: ['pdf'],
      type: FileType.custom,
    );
    if (path == null) return;
    await File(path).writeAsBytes(_pdfBytes!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF gespeichert: ${path.split('/').last}')),
      );
    }
  }

  Future<void> _export(ReportDraft draft) async {
    setState(() => _generating = true);

    try {
      final text = draft.generatedText!;
      final metadata = _buildMetadata(draft);
      final logoBytes = ref.read(customLogoProvider);

      switch (_mode) {
        case _ExportMode.professional:
          // Eigenes FEGH-Layout mit editierbaren AcroForm-Feldern —
          // Personalien-Tabelle + Section-Bodies sind im PDF änderbar.
          // Wenn ein Träger-Logo hinterlegt ist, erscheint es im Header.
          final structured = draft.activeStructured;
          final bytes = draft.type == ReportType.brp
              ? await PdfGenerator.generateBrp(
                  generatedText: text,
                  metadata: metadata,
                  structured: structured,
                  logoBytes: logoBytes,
                )
              : await PdfGenerator.generateInformationsbericht(
                  generatedText: text,
                  metadata: metadata,
                  structured: structured,
                  logoBytes: logoBytes,
                );
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
    // Strukturierte Stammdaten direkt aus dem Draft — keine Freitext-
    // Parserei mehr. Felder, die nicht gepflegt sind, bleiben leer
    // und kommen im PDF als editierbare Leer-Felder an.
    final s = draft.stammdaten;
    final familienname = (s['familienname'] ?? '').trim();
    final vorname = (s['vorname'] ?? '').trim();
    final fullName = familienname.isNotEmpty || vorname.isNotEmpty
        ? '$familienname, $vorname'.replaceAll(RegExp(r'^,\s*|,\s*$'), '')
        : '';

    return {
      'name': fullName,
      'berichtszeitraum': _combineFields(
          s, 'berichtszeitraum_von', 'berichtszeitraum_bis'),
      'berichtszeitraum_von': s['berichtszeitraum_von'] ?? '',
      'berichtszeitraum_bis': s['berichtszeitraum_bis'] ?? '',
      'leistungstyp': s['leistungstyp'] ?? '',
      'leistungserbringer': s['leistungserbringer'] ?? '',
      'familienname': familienname,
      'vorname': vorname,
      'titel': s['titel'] ?? '',
      'anrede': s['anrede'] ?? '',
      'geburtsname': s['geburtsname'] ?? '',
      'geburtsdatum': s['geburtsdatum'] ?? '',
      'geburtsort': s['geburtsort'] ?? '',
      'geschlecht': s['geschlecht'] ?? '',
      'familienstand': s['familienstand'] ?? '',
      'strasse': s['strasse'] ?? '',
      'hausnummer': s['hausnummer'] ?? '',
      'weitere_adresse': s['weitere_adresse'] ?? '',
      'plz_ort': _combineFields(s, 'plz', 'ort'),
      'plz': s['plz'] ?? '',
      'ort': s['ort'] ?? '',
      'telefon_festnetz': s['telefon_festnetz'] ?? '',
      'telefon_mobil': s['telefon_mobil'] ?? '',
      'telefon': s['telefon_festnetz'] ?? s['telefon_mobil'] ?? '',
      'email': s['email'] ?? '',
      'id_kostenuebernahme': s['id_kostenuebernahme'] ?? '',
      'kontakt_le': s['kontakt_le'] ?? '',
      'teilhabefachdienst': s['teilhabefachdienst'] ?? '',
    };
  }

  String _combineFields(Map<String, String> fields, String a, String b) {
    final va = fields[a] ?? '';
    final vb = fields[b] ?? '';
    if (va.isEmpty && vb.isEmpty) return '';
    if (va.isEmpty) return vb;
    if (vb.isEmpty) return va;
    return '$va – $vb';
  }

  String _generateFileName({String ext = 'pdf'}) {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return 'Bericht_$date.$ext';
  }

}

enum _ExportMode { professional, txt, clipboard }
