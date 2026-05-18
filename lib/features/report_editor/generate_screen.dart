import 'dart:async';
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
import '../api/schemas/canonical_words.dart';
import '../api/schemas/json_reconstruct.dart';
import '../api/schemas/report_markdown_renderer.dart';
import '../privacy/privacy_policy_text.dart';
import '../privacy/privacy_signature_screen.dart';
import '../pseudonymization/engine/pseudonym_engine.dart';
import '../pseudonymization/models/pseudonym_result.dart';
import '../pseudonymization/providers/pseudonym_providers.dart';
import '../pseudonymization/ui/widgets/highlighted_text.dart';
import 'models/report_draft.dart';
import 'providers/report_providers.dart';
import 'services/quality_checker.dart';
import 'widgets/quality_panel.dart';

enum GenerateStep { pseudonymize, review, generate, result }

/// Mindest-Anzeigedauer der Preview, bevor die Bestätigung möglich ist.
/// Verhindert reflexartiges Durchklicken ohne tatsächliche Sichtprüfung.
const _kPreviewMinimumReadDuration = Duration(seconds: 5);

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  GenerateStep _step = GenerateStep.pseudonymize;
  PseudonymResult? _pseudonymResult;
  bool _confirmed = false;
  bool _acknowledgedWarnings = false;
  bool _canConfirmYet = false;
  Timer? _previewReadTimer;
  String _generatedText = '';
  bool _isStreaming = false;
  ReportResponse? _usageData;
  String? _error;
  List<QualityIssue> _qualityIssues = [];

  @override
  void dispose() {
    _previewReadTimer?.cancel();
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
  String? _pseudonymizedReferenceReport;

  void _runPseudonymization() {
    final draft = ref.read(reportDraftNotifierProvider);
    if (draft == null) return;

    // EINE Engine für alle Texte → eindeutige Platzhalter-Nummern
    _engine = PseudonymEngine();
    final dictionary = ref.read(userDictionaryProvider);
    _engine!.loadUserDictionary(dictionary);

    // Stammdaten als gelernte Phrasen: damit auch alternative Schreibweisen
    // (z.B. "Vrislaff" im Vorbericht) auf dieselben Platzhalter gemappt
    // werden. Die kanonische Schreibweise aus den Stammdaten wird im
    // Reconstruct als Source-of-Truth verwendet.
    _registerStammdatenAsLearnedNames(draft.stammdaten);

    // Referenz-Bericht ZUERST pseudonymisieren (eigene Platzhalter-Serie)
    if (draft.referenceReport.isNotEmpty) {
      final refResult = _engine!.pseudonymize(draft.referenceReport);
      _pseudonymizedReferenceReport = refResult.cleanText;
    }

    // Vorbericht pseudonymisieren (gleiche Namen bekommen gleiche Platzhalter)
    if (draft.previousReport.isNotEmpty) {
      final prevResult = _engine!.pseudonymize(draft.previousReport, keepMappings: true);
      _pseudonymizedPreviousReport = prevResult.cleanText;
    }

    // Dann Notizen
    _pseudonymResult = _engine!.pseudonymize(draft.allNotesAsText, keepMappings: true);
    _pseudonymizedNotes = _pseudonymResult!.cleanText;

    setState(() => _step = GenerateStep.review);

    // Pflicht-Lesedauer: Bestätigung erst nach kurzer Mindestzeit aktivieren
    _previewReadTimer?.cancel();
    _previewReadTimer = Timer(_kPreviewMinimumReadDuration, () {
      if (mounted) setState(() => _canConfirmYet = true);
    });
  }

  /// Trägt die Stammdaten-Werte als gelernte Phrasen in die Engine ein —
  /// damit erkennt sie auch alternative Schreibweisen im Vorbericht und
  /// mappt sie auf einen gemeinsamen Platzhalter. Beim Reconstruct kommt
  /// die kanonische Schreibweise aus den Stammdaten zurück.
  void _registerStammdatenAsLearnedNames(Map<String, String> stamm) {
    const nameKeys = ['familienname', 'vorname', 'geburtsname'];
    for (final k in nameKeys) {
      final v = (stamm[k] ?? '').trim();
      if (v.isEmpty) continue;
      _engine!.learnName(v);
      // Bei Doppelnamen ("Müller-Schmidt") auch die Einzelteile lernen
      for (final part in v.split(RegExp(r'[\s\-]+'))) {
        if (part.length >= 3) _engine!.learnName(part);
      }
    }
  }

  /// Rekonstruktion + Validierung für strukturierten Output:
  /// Geht durch alle String-Werte der JSON-Map und ersetzt Platzhalter.
  /// Rendert anschließend den Markdown-Text aus dem rekonstruierten JSON.
  ({String text, String? error, Map<String, dynamic>? structured})
      _reconstructStructuredAndRender(
    ReportResponse response,
    ReportSchema schema,
  ) {
    final draft = ref.read(reportDraftNotifierProvider);
    final reportType = draft?.type ?? ReportType.informationsbericht;

    final structured = response.structured;
    if (structured == null) {
      // Fallback: kein strukturierter Output → roher Text
      var fallback = _stripAiClosingText(response.text);
      if (_engine != null) fallback = _engine!.reconstruct(fallback);
      return (text: fallback, error: null, structured: null);
    }

    // 1. Pseudonyme zurück-übersetzen (rekursiv durch das JSON)
    var rebuilt = _engine != null
        ? reconstructMap(structured, _engine!.reconstruct)
        : structured;

    // 1b. Großschreibungs-Korrektur: Behörden, Einrichtungen, Fachbegriffe
    // werden zuverlässig großgeschrieben — egal wie das LLM sie ausgibt.
    rebuilt = capitalizeMap(rebuilt);

    // 2. Übrig gebliebene Platzhalter prüfen
    final remaining = findRemainingPlaceholders(rebuilt);
    String? error;
    if (remaining.isNotEmpty) {
      final preview = remaining.take(3).join(', ');
      error = 'Rekonstruktion unvollständig: ${remaining.length} '
          'Platzhalter konnten nicht aufgelöst werden ($preview). '
          'Bericht NICHT exportieren!';
    }

    // 3. Markdown-Rendering aus dem strukturierten Objekt
    final markdown =
        ReportMarkdownRenderer.render(rebuilt, reportType, schema);
    return (text: markdown, error: error, structured: rebuilt);
  }

  /// Baut den Preview-Payload **identisch** zu dem, was die LLM-Adapter
  /// an die API senden — siehe `ReportRequest.buildUserContent`. Damit
  /// sieht die Fachkraft die komplette User-Message inklusive aller
  /// Trenner-Marker und sowohl Vorbericht als auch Referenzbericht.
  ///
  /// Die Mappings aus dem ursprünglichen `_pseudonymResult` werden an den
  /// Preview-Result drangehängt, damit `HighlightedText` die Platzhalter
  /// farblich markieren kann.
  PseudonymResult _buildPreviewResult() {
    final draft = ref.read(reportDraftNotifierProvider);
    final reportType = draft?.type ?? ReportType.informationsbericht;
    final request = ReportRequest(
      apiKey: '',
      model: '',
      reportType: reportType,
      pseudonymizedNotes: _pseudonymizedNotes ?? '',
      pseudonymizedPreviousReport: _pseudonymizedPreviousReport,
      pseudonymizedReferenceReport: _pseudonymizedReferenceReport,
    );
    return PseudonymResult(
      cleanText: request.buildUserContent(),
      mappings: _pseudonymResult?.mappings ?? const [],
      warnings: _pseudonymResult?.warnings ?? const [],
    );
  }

  /// Gibt zurück ob der Generate-Button freigegeben ist.
  /// Bei vorhandenen Warnungen ist eine ZUSÄTZLICHE Bestätigung nötig
  /// (doppeltes Häkchen), und die Mindest-Lesedauer muss abgelaufen sein.
  bool get _canGenerate {
    if (!_confirmed) return false;
    if (!_canConfirmYet) return false;
    final hasWarnings = _pseudonymResult?.warnings.isNotEmpty ?? false;
    if (hasWarnings && !_acknowledgedWarnings) return false;
    return true;
  }


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

      // Stammdaten ebenfalls pseudonymisieren, damit sie als "verbindliche
      // Schreibweisen" im User-Content stehen — ohne Klarnamen an die API
      // zu senden.
      final pseudoStamm = <String, String>{};
      currentDraft.stammdaten.forEach((k, v) {
        if (v.trim().isEmpty) return;
        // Schickt den Wert durch dieselbe Engine — Namen → Platzhalter
        final res = _engine!.pseudonymize(v, keepMappings: true);
        pseudoStamm[k] = res.cleanText.trim();
      });

      final baseRequest = ReportRequest(
        apiKey: apiKey,
        model: model,
        reportType: currentDraft.type,
        pseudonymizedNotes: _pseudonymizedNotes ?? _pseudonymResult!.cleanText,
        pseudonymizedPreviousReport: _pseudonymizedPreviousReport,
        pseudonymizedReferenceReport: _pseudonymizedReferenceReport,
        pseudonymizedStammdaten: pseudoStamm,
      );

      // Beide Schema-Varianten parallel generieren — Input-Tokens werden
      // durch Anthropic-Prompt-Caching deduplikziert, nur Output zählt
      // doppelt. UX-Vorteil: User kann beide direkt vergleichen.
      final results = await Future.wait([
        adapter.generateReport(
          baseRequest.copyWith(schema: ReportSchema.ausfuehrlichTib),
        ),
        adapter.generateReport(
          baseRequest.copyWith(schema: ReportSchema.kompaktOffiziell),
        ),
      ]);

      if (!mounted) return;

      final tibResponse = results[0];
      final offiziellResponse = results[1];
      _usageData = tibResponse; // Anzeige nur für die primäre Variante

      final tibText = _reconstructStructuredAndRender(
        tibResponse,
        ReportSchema.ausfuehrlichTib,
      );
      final offiziellText = _reconstructStructuredAndRender(
        offiziellResponse,
        ReportSchema.kompaktOffiziell,
      );

      // Diagnose: Wenn keine strukturierte Map vom Adapter zurückkommt,
      // hat das LLM Schema/Tool-Use ignoriert. Wir zeigen einen klaren
      // Hinweis statt schweigend einen Markdown-Fallback zu liefern.
      if (tibText.structured == null && offiziellText.structured == null) {
        throw Exception(
          'Der LLM-Adapter hat keinen strukturierten Output geliefert. '
          'Modell: ${tibResponse.model}. '
          'Bitte ein Modell mit Tool-Use-/JSON-Schema-Unterstützung wählen '
          '(z.B. claude-sonnet-4-6, gpt-5.4 oder gpt-4o).',
        );
      }

      final notifier = ref.read(reportDraftNotifierProvider.notifier);
      notifier.setGeneratedTextForSchema(
        ReportSchema.ausfuehrlichTib,
        tibText.text,
      );
      notifier.setGeneratedTextForSchema(
        ReportSchema.kompaktOffiziell,
        offiziellText.text,
      );
      if (tibText.structured != null) {
        notifier.setStructuredReportForSchema(
          ReportSchema.ausfuehrlichTib,
          tibText.structured!,
        );
      }
      if (offiziellText.structured != null) {
        notifier.setStructuredReportForSchema(
          ReportSchema.kompaktOffiziell,
          offiziellText.structured!,
        );
      }
      // Legacy-Feld auf die aktive Variante zeigen lassen.
      notifier.setGeneratedText(tibText.text);

      // Wenn auch nur EINE Variante Probleme hat, zeige eine Warnung —
      // aber blockiere den Export erst, wenn die aktiv angezeigte Variante
      // betroffen ist.
      final draft = ref.read(reportDraftNotifierProvider);
      final activeError = draft?.selectedSchema == ReportSchema.kompaktOffiziell
          ? offiziellText.error
          : tibText.error;
      _error = activeError;

      // Audit-Log: ein Eintrag pro tatsächlicher API-Generierung.
      final auditLog = ref.read(auditLogProvider);
      for (final r in results) {
        auditLog.log(AuditEvent.reportGenerated(
          mappingCount: _pseudonymResult?.totalReplacements ?? 0,
          model: r.model,
          reportType: currentDraft.type.name,
          inputTokens: r.inputTokens,
          outputTokens: r.outputTokens,
          costUsd: r.costUsd,
        ));
      }

      _qualityIssues = QualityChecker.checkGeneratedText(
        draft?.activeGeneratedText ?? tibText.text,
        draft?.type ?? ReportType.informationsbericht,
      );

      setState(() {
        _generatedText = draft?.activeGeneratedText ?? tibText.text;
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
          onPressed: () => context.pop(),
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
  /// Nur die letzten Absätze werden geprüft — nie mitten im Text löschen.
  String _stripAiClosingText(String text) {
    final lines = text.trimRight().split('\n');

    // Von hinten die letzten Absätze prüfen (max. letzte 8 Zeilen)
    var cutIndex = lines.length;
    for (var i = lines.length - 1; i >= 0 && i >= lines.length - 8; i--) {
      final line = lines[i].trim().toLowerCase();
      if (line.isEmpty) continue;

      if (line.startsWith('wenn du möchtest') ||
          line.startsWith('möchtest du') ||
          line.startsWith('soll ich') ||
          line.startsWith('gerne kann ich') ||
          line.startsWith('bei bedarf') ||
          line.startsWith('ich kann') && line.contains('erstellen') ||
          line == '---') {
        cutIndex = i;
      } else {
        // Sobald eine echte Inhaltszeile kommt, aufhören
        break;
      }
    }

    return lines.sublist(0, cutIndex).join('\n').trimRight();
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

        // Pseudonymisierungs-Warnings
        if (_pseudonymResult!.warnings.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
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
          const SizedBox(height: 12),
        ],

        // Hinweis: Gesamter Text der an die API gesendet wird
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gesamter pseudonymisierter Text der an die API '
                  'gesendet wird — vollständig, in der exakten Reihenfolge:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Kompletter pseudonymisierter Payload (Vorbericht + Referenz +
        // Notizen + Trenner-Marker) — identisch zu dem, was die Adapter
        // als User-Message-Content an die API senden.
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: SingleChildScrollView(
              child: HighlightedText(result: _buildPreviewResult()),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pflicht-Bestätigung
        CheckboxListTile(
          value: _confirmed,
          onChanged: _canConfirmYet
              ? (v) => setState(() => _confirmed = v ?? false)
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            _canConfirmYet
                ? 'Ich habe den Text Zeile für Zeile geprüft und bestätige, '
                    'dass keine personenbezogenen Daten mehr enthalten sind.'
                : 'Bitte den Text sorgfältig prüfen — Bestätigung in Kürze '
                    'freigegeben.',
          ),
          tileColor: _confirmed
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        // Zweite Bestätigung — nur bei vorhandenen Warnungen
        if (_pseudonymResult?.warnings.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledgedWarnings,
            onChanged: (v) =>
                setState(() => _acknowledgedWarnings = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Ich habe die Warnungen oben einzeln gelesen und bewertet. '
              'Etwaige Restrisiken übernehme ich in meiner fachlichen '
              'Verantwortung.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            tileColor: _acknowledgedWarnings
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.08),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ],
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
          onPressed: _canGenerate ? _generate : null,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Bericht generieren'),
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
    final draft = ref.watch(reportDraftNotifierProvider);
    final hasBothVariants = draft != null &&
        draft.generatedTexts.length >= 2 &&
        draft.generatedTexts.containsKey(ReportSchema.ausfuehrlichTib) &&
        draft.generatedTexts.containsKey(ReportSchema.kompaktOffiziell);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasBothVariants
                    ? 'Bericht in zwei Varianten generiert'
                    : 'Bericht erfolgreich generiert',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasBothVariants
              ? 'Du kannst zwischen der ausführlichen TIB-Variante und der '
                  'kompakten Berliner Vorlage umschalten. Beide enthalten '
                  'denselben Inhalt, in unterschiedlicher Strukturtiefe. '
                  'Die aktuell aktive Variante wird auch im PDF-Export '
                  'verwendet.'
              : 'Die Platzhalter wurden durch die Originaldaten ersetzt. '
                  'Bitte prüfe den Bericht sorgfältig vor dem Export.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (hasBothVariants) ...[
          const SizedBox(height: 12),
          SegmentedButton<ReportSchema>(
            segments: const [
              ButtonSegment(
                value: ReportSchema.ausfuehrlichTib,
                label: Text('Ausführlich (TIB)'),
                icon: Icon(Icons.account_tree, size: 18),
              ),
              ButtonSegment(
                value: ReportSchema.kompaktOffiziell,
                label: Text('Kompakt (Berliner Vorlage)'),
                icon: Icon(Icons.description, size: 18),
              ),
            ],
            selected: {draft.selectedSchema},
            onSelectionChanged: (set) {
              final newSchema = set.first;
              ref
                  .read(reportDraftNotifierProvider.notifier)
                  .selectSchema(newSchema);
              setState(() {
                _generatedText =
                    draft.generatedTexts[newSchema] ?? _generatedText;
                final remaining = RegExp(r'\[[A-Z]+_\d{3}\]');
                _error = remaining.hasMatch(_generatedText)
                    ? 'Rekonstruktion unvollständig in dieser Variante. '
                        'Bericht NICHT exportieren!'
                    : null;
                _qualityIssues = QualityChecker.checkGeneratedText(
                  _generatedText,
                  draft.type,
                );
              });
            },
          ),
        ],
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
              onPressed: () => context.pop(),
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
