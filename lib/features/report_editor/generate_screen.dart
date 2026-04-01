import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/storage/audit_log.dart';
import '../api/models/report_request.dart';
import '../api/providers/api_providers.dart';
import '../privacy/privacy_policy_text.dart';
import '../privacy/privacy_signature_screen.dart';
import '../pseudonymization/engine/brp_page4_detector.dart';
import '../pseudonymization/engine/pseudonym_engine.dart';
import '../pseudonymization/models/pseudonym_result.dart';
import '../pseudonymization/providers/pseudonym_providers.dart';
import '../pseudonymization/ui/widgets/highlighted_text.dart';
import 'models/report_draft.dart';
import 'providers/report_providers.dart';
import 'services/quality_checker.dart';
import 'widgets/quality_panel.dart';

enum GenerateStep { pseudonymize, review, generate, result }

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  GenerateStep _step = GenerateStep.pseudonymize;
  PseudonymResult? _pseudonymResult;
  bool _confirmed = false;
  String _generatedText = '';
  bool _isStreaming = false;
  ReportResponse? _usageData;
  String? _error;
  List<BrpPage4Warning> _page4Warnings = [];
  List<QualityIssue> _qualityIssues = [];

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _runPseudonymization();
  }

  // Eine einzige Engine für ALLE Texte – verhindert Platzhalter-Kollisionen
  PseudonymEngine? _engine;
  String? _pseudonymizedNotes;
  String? _pseudonymizedPreviousReport;

  void _runPseudonymization() {
    final draft = ref.read(reportDraftNotifierProvider);
    if (draft == null) return;

    // BRP Seite-4-Schutz
    if (draft.type == ReportType.brp) {
      final allText = '${draft.allNotesAsText}\n${draft.previousReport}';
      _page4Warnings = BrpPage4Detector.detect(allText);
    }

    // EINE Engine für alle Texte → eindeutige Platzhalter-Nummern
    _engine = PseudonymEngine();
    final dictionary = ref.read(userDictionaryProvider);
    _engine!.loadUserDictionary(dictionary);

    // Vorbericht ZUERST pseudonymisieren (gleiche Namen bekommen gleiche Platzhalter)
    if (draft.previousReport.isNotEmpty) {
      final prevResult = _engine!.pseudonymize(draft.previousReport);
      _pseudonymizedPreviousReport = prevResult.cleanText;
    }

    // Dann Notizen – keepMappings: true damit gleiche Namen gleiche Platzhalter bekommen
    _pseudonymResult = _engine!.pseudonymize(draft.allNotesAsText, keepMappings: true);
    _pseudonymizedNotes = _pseudonymResult!.cleanText;

    setState(() => _step = GenerateStep.review);
  }

  bool get _isBlocked =>
      _page4Warnings.any((w) => w.severity == BrpPage4Severity.blocked);

  Future<void> _generate() async {
    // Signatur-Check: Datenschutzerklärung muss unterzeichnet sein
    final sigStore = ref.read(signatureStoreProvider);
    if (!sigStore.isSignatureValid(kPrivacyPolicyText)) {
      setState(() => _error =
          'Bitte zuerst die Datenschutzerklärung unterzeichnen '
          '(Einstellungen → Datenschutz & Recht).');
      return;
    }

    final apiKey = ref.read(activeApiKeyProvider);
    if (apiKey.isEmpty) {
      setState(() => _error = 'Bitte zuerst einen API-Key in den Einstellungen hinterlegen.');
      return;
    }

    final currentDraft = ref.read(reportDraftNotifierProvider);
    if (currentDraft == null || _pseudonymResult == null) return;

    setState(() {
      _step = GenerateStep.generate;
      _isStreaming = true;
      _generatedText = '';
      _error = null;
    });

    try {
      final adapter = ref.read(llmAdapterProvider);
      final model = ref.read(selectedModelProvider);

      final request = ReportRequest(
        apiKey: apiKey,
        model: model,
        reportType: currentDraft.type,
        pseudonymizedNotes: _pseudonymizedNotes ?? _pseudonymResult!.cleanText,
        pseudonymizedPreviousReport: _pseudonymizedPreviousReport,
      );

      // Non-Streaming Aufruf – liefert echte Token-Usage-Daten
      final response = await adapter.generateReport(request);

      if (!mounted) return;

      _generatedText = _stripAiClosingText(response.text);
      _usageData = response;

      // Rekonstruktion: Platzhalter durch Originaldaten ersetzen
      // Nutzt die EINE Engine die ALLE Mappings kennt
      var finalText = _generatedText;
      if (_engine != null) {
        finalText = _engine!.reconstruct(finalText);
      }

      // F1: Validierung – Prüfe ob noch Platzhalter im Text
      final remainingPlaceholders = RegExp(r'\[[A-Z]+_\d{3}\]');
      if (remainingPlaceholders.hasMatch(finalText)) {
        final matches = remainingPlaceholders.allMatches(finalText).toList();
        _error = 'Rekonstruktion unvollständig: ${matches.length} Platzhalter '
            'konnten nicht aufgelöst werden (${matches.take(3).map((m) => m.group(0)).join(", ")}). '
            'Bericht NICHT exportieren!';
      }

      ref.read(reportDraftNotifierProvider.notifier).setGeneratedText(finalText);

      // Audit-Log: Berichtsgenerierung mit echten Kosten protokollieren
      ref.read(auditLogProvider).log(AuditEvent.reportGenerated(
        mappingCount: _pseudonymResult?.totalReplacements ?? 0,
        model: response.model,
        reportType: currentDraft.type.name,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        costUsd: response.costUsd,
      ));

      final draft = ref.read(reportDraftNotifierProvider);
      _qualityIssues = QualityChecker.checkGeneratedText(
        finalText,
        draft?.type ?? ReportType.informationsbericht,
      );

      setState(() {
        _generatedText = finalText;
        _isStreaming = false;
        _step = GenerateStep.result;
      });
    } catch (e) {
      String errorMsg = e.toString();
      // Bei DioException: Response-Body auslesen für bessere Fehlermeldung
      if (e is DioException && e.response?.data != null) {
        try {
          final data = e.response!.data;
          if (data is Map) {
            final apiError = data['error'];
            if (apiError is Map) {
              errorMsg = 'API-Fehler: ${apiError['message'] ?? apiError}';
            }
          }
        } catch (_) {}
      }
      setState(() {
        _error = errorMsg;
        _isStreaming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == GenerateStep.review) {
              context.go('/editor');
            } else if (_step == GenerateStep.result) {
              context.go('/editor');
            } else {
              context.go('/editor');
            }
          },
        ),
        actions: [
          if (_step == GenerateStep.result)
            FilledButton.icon(
              onPressed: () => context.push('/export'),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF exportieren'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              GenerateStep.pseudonymize => const Center(
                  child: CircularProgressIndicator(),
                ),
              GenerateStep.review => _buildReviewStep(theme),
              GenerateStep.generate => _buildGenerateStep(theme),
              GenerateStep.result => _buildResultStep(theme),
            },
          ),
        ),
      ),
    );
  }

  /// Entfernt typische KI-Schlussfloskeln, die nicht in den Bericht gehören.
  String _stripAiClosingText(String text) {
    // Muster für KI-Metakommentare am Ende des Textes
    final patterns = [
      RegExp(r'\n---\s*\n.*$', dotAll: true), // Alles nach "---" Trennlinie
      RegExp(r'\nWenn du möchtest[^]*$', caseSensitive: false),
      RegExp(r'\nMöchtest du[^]*$', caseSensitive: false),
      RegExp(r'\nSoll ich[^]*$', caseSensitive: false),
      RegExp(r'\nIch kann[^]*?erstellen\.\s*$', caseSensitive: false),
      RegExp(r'\nBei Bedarf[^]*$', caseSensitive: false),
      RegExp(r'\nGerne kann ich[^]*$', caseSensitive: false),
      RegExp(r'\nBitte beachte,? dass[^]*$', caseSensitive: false),
      RegExp(r'\nHinweis:?\s*Dies[^]*$', caseSensitive: false),
    ];

    var result = text;
    for (final pattern in patterns) {
      result = result.replaceAll(pattern, '');
    }
    return result.trimRight();
  }

  String get _stepTitle => switch (_step) {
        GenerateStep.pseudonymize => 'Pseudonymisierung...',
        GenerateStep.review => 'Pseudonymisierung prüfen',
        GenerateStep.generate => 'Bericht wird generiert...',
        GenerateStep.result => 'Bericht fertig',
      };

  Widget _buildReviewStep(ThemeData theme) {
    if (_pseudonymResult == null) {
      return const Center(child: Text('Keine Daten vorhanden.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status
        Wrap(
          spacing: 12,
          children: [
            Chip(
              avatar: const Icon(Icons.check_circle, size: 18),
              label: Text('${_pseudonymResult!.totalReplacements} Ersetzungen'),
              backgroundColor: Colors.green.withValues(alpha: 0.1),
            ),
            if (_pseudonymResult!.warningCount > 0)
              Chip(
                avatar: const Icon(Icons.warning_amber, size: 18),
                label: Text('${_pseudonymResult!.warningCount} Warnungen'),
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // BRP Seite-4-Blockierung
        if (_page4Warnings.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isBlocked
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.08),
              border: Border.all(
                color: _isBlocked ? Colors.red : Colors.orange,
                width: _isBlocked ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.block : Icons.warning_amber,
                      color: _isBlocked ? Colors.red.shade700 : Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isBlocked
                          ? 'BRP Seite 4 erkannt – Übermittlung blockiert!'
                          : 'Mögliche BRP Seite 4 Inhalte:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isBlocked ? Colors.red.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._page4Warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 4),
                    child: Text('• ${w.message}', style: theme.textTheme.bodySmall),
                  ),
                ),
                if (_isBlocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Die psychiatrische Anamnese (Seite 4 des BRP) darf nicht '
                    'an die API übermittelt werden. Bitte entferne diese Inhalte '
                    'und versuche es erneut.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Pseudonymisierungs-Warnings (scrollbar, max 120px)
        if (_pseudonymResult!.warnings.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bitte prüfen (${_pseudonymResult!.warningCount}):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _pseudonymResult!.warnings.map(
                          (w) => Text('• $w', style: theme.textTheme.bodySmall),
                        ).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Pseudonymisierter Text
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: HighlightedText(result: _pseudonymResult!),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(height: 16),

        // Generate Button
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _confirmed && !_isBlocked ? _generate : null,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_isBlocked
              ? 'Blockiert – Seite 4 entfernen'
              : 'Bericht generieren'),
        ),
      ],
    );
  }

  Widget _buildGenerateStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isStreaming)
          const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Der Bericht wird generiert...',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Der pseudonymisierte Text wurde an die API gesendet. '
          'Die Platzhalter werden nach Erhalt der Antwort automatisch '
          'durch die Originaldaten ersetzt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _generatedText.isEmpty
                ? const Center(child: Text('Warte auf Antwort...'))
                : Markdown(
                    data: _generatedText,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ],
    );
  }

  Future<void> _exportAsTxt() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Bericht als Textdatei speichern',
      fileName: 'Bericht_${DateTime.now().toIso8601String().substring(0, 10)}.txt',
    );
    if (path == null) return;
    await File(path).writeAsString(_generatedText);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bericht als TXT gespeichert')),
      );
    }
  }

  Widget _buildResultStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Bericht erfolgreich generiert',
                  style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Die Platzhalter wurden durch die Originaldaten ersetzt. '
          'Bitte prüfe den Bericht sorgfältig vor dem Export.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Token-Kosten-Anzeige (echte Werte aus der API)
        if (_usageData != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API-Verbrauch: ${_usageData!.tokenDisplay}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modell: ${_usageData!.model} · '
                        'Kosten: ${_usageData!.costDisplay}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_qualityIssues.isNotEmpty) ...[
          const SizedBox(height: 12),
          QualityPanel(issues: _qualityIssues),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Markdown(
                data: _generatedText,
                selectable: true,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
          ),
        ),
        const SizedBox(height: 16),
        // Export-Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/editor'),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Zurück'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('In Zwischenablage kopiert')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Kopieren'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportAsTxt(),
              icon: const Icon(Icons.text_snippet_outlined, size: 18),
              label: const Text('Als TXT'),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/export'),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Als PDF'),
            ),
          ],
        ),
      ],
    );
  }
}
