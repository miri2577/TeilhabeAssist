import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Befüllt die offiziellen Berliner PDF-Vorlagen mit den Berichtsdaten.
///
/// Die Feld-IDs (z.B. `IB_S1_06_02`, `IB_S2_05_01`, `IB_S3_02_03_a`) folgen
/// der amtlichen Berliner Vorlage 1.01 und sind mit dem Berliner Informations-
/// bericht im Form-Center der Senatsverwaltung abgestimmt.
///
/// Designentscheidung: ausschließlich AcroForm-Felder befüllen — keine
/// eigenen `drawString`-Operationen. Felder bleiben editierbar; die
/// Fachkraft kann vor dem Druck Korrekturen vornehmen. **Niemals**
/// `flattenAllFields` aufrufen — das löscht bei dieser Vorlage die Werte.
class FormFillerService {
  FormFillerService._();

  /// Suffixe für bis zu zehn Teilhabeziele (Felder `_a` bis `_j`).
  static const _goalSuffixes = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'];

  // ──────────────────────────────────────────────────────────────────
  //   Informationsbericht 1.01
  // ──────────────────────────────────────────────────────────────────

  static Future<Uint8List> fillInformationsbericht({
    required String generatedText,
    required Map<String, String> metadata,
    Map<String, dynamic>? structured,
  }) async {
    // Legacy-Pfad: füllt das offizielle PDF, aber nur Slot _a kann
    // sicher beschrieben werden (siehe Diskussion in der README).
    // Bevorzugt wird stattdessen der `BerlinFormGenerator` aufgerufen.
    final templateBytes = await _loadTemplate(
      'assets/templates/informationsbericht_101.pdf',
    );
    final doc = PdfDocument(inputBytes: templateBytes);
    final fields = _buildFieldMap(doc);

    // ── Seite 1: Kopfdaten ────────────────────────────────────────
    _setText(fields, 'IB_S1_06_02', metadata['id_kostenuebernahme']);
    _setText(fields, 'IB_S1_07_02', metadata['berichtszeitraum_von']);
    _setText(fields, 'IB_S1_07_04', metadata['berichtszeitraum_bis']);
    _setText(fields, 'IB_S1_08_02', metadata['leistungstyp']);
    _setText(fields, 'IB_S1_09_02', metadata['leistungserbringer']);
    _setText(fields, 'IB_S1_10_02', metadata['kontakt_le']);
    _setText(fields, 'IB_S1_12_02', metadata['strasse']);
    _setText(fields, 'IB_S1_13_02', metadata['hausnummer']);
    _setText(fields, 'IB_S1_14_02', metadata['weitere_adresse']);
    _setText(fields, 'IB_S1_15_02', metadata['plz']);
    _setText(fields, 'IB_S1_16_02', metadata['ort']);

    // ── Seite 1: Persönliche Daten ────────────────────────────────
    _setText(fields, 'IB_S1_20_02', metadata['familienname']);
    _setText(fields, 'IB_S1_21_02', metadata['vorname']);
    _setText(fields, 'IB_S1_23_02', metadata['geburtsdatum']);
    _setText(fields, 'IB_S1_24_02', metadata['geburtsort']);
    _setText(fields, 'IB_S1_28_02', metadata['telefon_festnetz']);
    _setText(fields, 'IB_S1_29_02', metadata['telefon_mobil']);
    _setText(fields, 'IB_S1_30_02', metadata['email']);

    // Header auf Folgeseiten (wiederholt sich pro Seite)
    _setText(fields, 'IB_gesamt_02', metadata['vorname']);
    _setText(fields, 'IB_gesamt_04', metadata['familienname']);

    // Wenn strukturierte Map vorhanden: direkt befüllen (verlässlich, da
    // schema-validiert). Andernfalls: Fallback auf Markdown-Parsing.
    if (structured != null) {
      _fillInfoberichtFromStructured(fields, structured);
      final bytes = Uint8List.fromList(await doc.save());
      doc.dispose();
      return bytes;
    }

    // ── Fallback: Markdown-Parsing (legacy) ───────────────────────
    final sections = _parseSections(generatedText);

    // Seite 2: Allgemeine Informationen (großes Multiline-Feld)
    final allgemeineInfo = _plain(sections['allgemeine'] ?? '');
    _setText(fields, 'IB_S2_05_01', allgemeineInfo);

    // Seite 3: Teilhabeziele — bis zu 10 Slots mit Suffix _a, _b, ...
    final goals = _parseGoals(sections['ziele'] ?? '');
    for (var i = 0; i < goals.length && i < _goalSuffixes.length; i++) {
      final goal = goals[i];
      final s = _goalSuffixes[i];

      _setText(fields, 'IB_S3_02_02_$s', '${i + 1}');
      _setText(fields, 'IB_S3_02_03_$s', _plain(goal.leitziel));
      _setText(fields, 'IB_S3_03_02_$s', '${i + 1}');
      _setText(fields, 'IB_S3_03_04_$s', _plain(goal.teilhabezielText));
      _setText(fields, 'IB_S3_04_02_$s', _plain(goal.indikator));
      _setText(fields, 'IB_S3_14_01_$s', _plain(goal.erlaeuterung));

      // Zielerreichungs-Checkboxes
      final z = goal.zielerreichung.toLowerCase();
      _setCheck(fields, 'IB_S3_06_01_$s', z.contains('voll'));
      _setCheck(
        fields,
        'IB_S3_07_01_$s',
        z.contains('teilweise'),
      );
      _setCheck(
        fields,
        'IB_S3_08_01_$s',
        z.contains('nicht erreicht'),
      );
      _setCheck(
        fields,
        'IB_S3_09_01_$s',
        z.contains('beurteilbar') || z.contains('kann nicht'),
      );

      // Abweichende Sicht der leistungsberechtigten Person
      _setCheck(
        fields,
        'IB_S3_11_01_$s',
        goal.abweichendeSicht.trim().isEmpty,
      );
      _setCheck(
        fields,
        'IB_S3_11_03_$s',
        goal.abweichendeSicht.trim().isNotEmpty,
      );
    }

    // Seite 4: Weitere Anmerkungen
    final anmerkungen = _plain(sections['anmerkungen'] ?? '');
    if (anmerkungen.isNotEmpty) {
      _setText(fields, 'IB_S4_03_01', anmerkungen);
    }

    // Erreichbarkeit in der Nacht — Default "Nein", da der LLM-Output
    // selten anders angegeben ist.
    _setCheck(fields, 'IB_S4_05_01', true); // "Nein"
    _setCheck(fields, 'IB_S4_05_03', false); // "Ja"

    // Seite 5: Zusammenfassung
    final zusammenfassung = _plain(sections['zusammenfassung'] ?? '');
    if (zusammenfassung.isNotEmpty) {
      _setText(fields, 'IB_S8_02_01', zusammenfassung);
    }

    // ⚠ KEIN flattenAllFields — würde bei dieser Vorlage die Werte löschen.

    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  // ──────────────────────────────────────────────────────────────────
  //   Hilfsfunktionen
  // ──────────────────────────────────────────────────────────────────

  static Future<Uint8List> _loadTemplate(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      throw Exception(
        'PDF-Vorlage "$assetPath" konnte nicht geladen werden.',
      );
    }
  }

  /// Füllt die Felder des Informationsberichts direkt aus dem strukturierten
  /// JSON-Objekt (schema-validierter Output von Anthropic/OpenAI). Vermeidet
  /// jegliches Markdown-Parsing — alle Werte sind bereits typisiert und
  /// vollständig.
  static void _fillInfoberichtFromStructured(
    Map<String, PdfField> fields,
    Map<String, dynamic> data,
  ) {
    final ai = data['allgemeine_informationen'] as Map<String, dynamic>?;
    if (ai != null) {
      final buf = StringBuffer();
      _appendIfNotEmpty(buf,
          'Ausbildung, Arbeit und sonstige Tagesstruktur',
          ai['ausbildung_arbeit_tagesstruktur']);
      _appendIfNotEmpty(buf, 'Bedeutsame Kontakte', ai['bedeutsame_kontakte']);
      _appendIfNotEmpty(buf, 'Weitere relevante Informationen',
          ai['sozialraum_und_weiteres']);
      _setText(fields, 'IB_S2_05_01', buf.toString().trim());
    }

    final goals = (data['teilhabeziele'] as List?) ?? const [];
    for (var i = 0; i < goals.length && i < _goalSuffixes.length; i++) {
      final goal = goals[i] as Map<String, dynamic>;
      final s = _goalSuffixes[i];
      final num = '${i + 1}';

      _setText(fields, 'IB_S3_02_02_$s', num);
      _setText(fields, 'IB_S3_02_03_$s', goal['leitziel']?.toString());
      _setText(fields, 'IB_S3_03_02_$s', num);
      _setText(
          fields, 'IB_S3_03_04_$s', goal['teilhabeziel_zlp']?.toString());
      _setText(fields, 'IB_S3_04_02_$s', goal['indikator']?.toString());
      // Erläuterung — kompakt: `erlaeuterung_zielerreichung`,
      //               TIB:    `sicht_leistungserbringer` + Begründung
      final erlaeuterung = (goal['erlaeuterung_zielerreichung'] ??
              goal['sicht_leistungserbringer'])
          ?.toString();
      _setText(fields, 'IB_S3_14_01_$s', erlaeuterung);

      final zg = goal['zielerreichungsgrad']?.toString() ?? '';
      _setCheck(fields, 'IB_S3_06_01_$s', zg == 'voll_erreicht');
      _setCheck(fields, 'IB_S3_07_01_$s', zg == 'teilweise_erreicht');
      _setCheck(fields, 'IB_S3_08_01_$s', zg == 'nicht_erreicht');
      _setCheck(fields, 'IB_S3_09_01_$s', zg == 'nicht_beurteilbar');

      final abw = goal['abweichende_einschaetzung_klient']?.toString() ?? '';
      _setCheck(fields, 'IB_S3_11_01_$s', abw.trim().isEmpty);
      _setCheck(fields, 'IB_S3_11_03_$s', abw.trim().isNotEmpty);
    }

    final assist = data['assistenzleistungen'] as Map<String, dynamic>?;
    if (assist != null) {
      final buf = StringBuffer();
      _appendIfNotEmpty(buf, 'Fachleistungsstunden',
          assist['fachleistungsstunden_uebersicht']);
      _appendIfNotEmpty(
          buf, 'Besondere Vorkommnisse', assist['besondere_vorkommnisse']);
      _setText(fields, 'IB_S4_03_01', buf.toString().trim());

      final nacht = assist['erreichbarkeit_nacht'] == true;
      _setCheck(fields, 'IB_S4_05_01', !nacht);
      _setCheck(fields, 'IB_S4_05_03', nacht);
    }

    final zus = data['zusammenfassung'] as Map<String, dynamic>?;
    if (zus != null) {
      final buf = StringBuffer();
      _appendIfNotEmpty(
          buf, 'Gesamteinschätzung', zus['gesamteinschaetzung']);
      _appendIfNotEmpty(buf, 'Empfehlung für den kommenden Leistungszeitraum',
          zus['empfehlung_kommender_zeitraum']);
      final flsLabel = switch (zus['fls_empfehlung']?.toString()) {
        'erhoehung' => 'FLS-Empfehlung: Erhöhung',
        'beibehaltung' => 'FLS-Empfehlung: Beibehaltung',
        'reduktion' => 'FLS-Empfehlung: Reduktion',
        _ => 'FLS-Empfehlung'
      };
      _appendIfNotEmpty(buf, flsLabel, zus['fls_begruendung']);
      _setText(fields, 'IB_S8_02_01', buf.toString().trim());
    }
  }

  static void _appendIfNotEmpty(StringBuffer buf, String label, dynamic value) {
    final v = (value ?? '').toString().trim();
    if (v.isEmpty) return;
    if (buf.isNotEmpty) {
      buf.writeln();
      buf.writeln();
    }
    buf.writeln('$label:');
    buf.write(v);
  }

  static Map<String, PdfField> _buildFieldMap(PdfDocument doc) {
    final map = <String, PdfField>{};
    try {
      final form = doc.form;
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        final name = field.name;
        if (name == null || name.isEmpty) continue;
        map.putIfAbsent(name, () => field);
      }
    } catch (_) {}
    return map;
  }

  static void _setText(
    Map<String, PdfField> fields,
    String fieldName,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) return;
    final field = fields[fieldName];
    if (field is PdfTextBoxField) {
      field.text = value;
    }
  }

  static void _setCheck(
    Map<String, PdfField> fields,
    String fieldName,
    bool checked,
  ) {
    final field = fields[fieldName];
    if (field is PdfCheckBoxField) {
      field.isChecked = checked;
    }
  }

  /// Entfernt Markdown-Syntax für PDF-Ausgabe. `replaceAllMapped`, nicht
  /// `replaceAll(RegExp, String)` — letzteres würde `$1` als wörtlichen
  /// Text in den Output schreiben.
  static String _plain(String text) {
    return text
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*'),
          (m) => m.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\*(.+?)\*'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll(RegExp(r'^---+\s*$', multiLine: true), '')
        .trim();
  }

  static Map<String, String> _parseSections(String text) {
    final sections = <String, String>{};
    final lines = text.split('\n');
    var currentKey = 'allgemeine';
    final buffer = StringBuffer();

    for (final line in lines) {
      final lower = line.toLowerCase();
      // Nur top-level Headings ("## ", "# ") als Sektion-Trigger werten —
      // sonst zerlegen Sub-Headings wie "### Ausbildung" die Sektion falsch.
      final isHeading = line.startsWith('## ') || line.startsWith('# ');
      if (!isHeading) {
        buffer.writeln(line);
        continue;
      }

      String? newKey;
      if (lower.contains('allgemeine information') ||
          lower.contains('tagesstruktur')) {
        newKey = 'allgemeine';
      } else if (lower.contains('teilhabeziel') ||
          lower.contains('zielerreichung')) {
        newKey = 'ziele';
      } else if (lower.contains('assistenzleistung') ||
          lower.contains('anmerkung') ||
          lower.contains('vorkommnis')) {
        newKey = 'anmerkungen';
      } else if (lower.contains('zusammenfassung') ||
          lower.contains('ausblick') ||
          lower.contains('empfehlung')) {
        newKey = 'zusammenfassung';
      } else if (lower.contains('entwicklung') ||
          lower.contains('problemlage')) {
        newKey = 'entwicklung';
      } else if (lower.contains('fähigkeit') ||
          lower.contains('ressource')) {
        newKey = 'faehigkeiten';
      } else if (lower.contains('selbstversorgung') ||
          lower.contains('wohnen')) {
        newKey = 'ziele_wohnen';
      }

      if (newKey != null && newKey != currentKey) {
        if (buffer.isNotEmpty) {
          sections[currentKey] = buffer.toString().trim();
        }
        currentKey = newKey;
        buffer.clear();
      }
      buffer.writeln(line);
    }
    if (buffer.isNotEmpty) {
      sections[currentKey] = buffer.toString().trim();
    }
    return sections;
  }

  /// Parst die Teilhabeziele-Sektion in einzelne Ziel-Blöcke.
  /// Erkennt mehrere Marker-Varianten, die das LLM benutzt:
  ///   - `### Teilhabeziel N` / `### Ziel N` (TIB-Schema)
  ///   - `---` Trenner zwischen Zielen
  ///   - `**Leitziel:** …` als impliziter Start eines neuen Ziels
  ///     (Kompakt-Schema, wenn das LLM die `###`-Marker weglässt)
  static List<_GoalEntry> _parseGoals(String text) {
    final goals = <_GoalEntry>[];
    if (text.trim().isEmpty) return goals;

    // Erst nach `**Leitziel:**` splitten — das ist der robusteste Marker,
    // da jedes Ziel mit einem Leitziel-Block startet. Wir kapseln den
    // Lookahead, damit der Match-Text nicht im Split-Output verschwindet.
    // Wenn das LLM `###`-Header verwendet, sind diese Vor-Leitziel-Texte
    // im Block-Header, was unsere Extraktion nicht stört.
    final splitter = RegExp(
      r'(?=^[\s\-•]*\*\*Leitziel\b)',
      multiLine: true,
      caseSensitive: false,
    );
    final blocks = text.split(splitter);

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      // Header der ## 2. Teilhabeziele-Sektion oder andere Vor-Texte
      // ohne eigenes Leitziel überspringen.
      if (!RegExp(r'^[\s\-•]*\*\*Leitziel\b', caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }

      final goal = _GoalEntry();
      goal.leitziel = _extractField(trimmed, [
            'Leitziel',
            r'a\)\s*Leitziel',
          ]) ??
          '';
      goal.teilhabezielText = _extractField(trimmed, [
            'Teilhabeziel aus ZLP',
            'Teilhabeziel',
          ]) ??
          '';
      goal.indikator = _extractField(trimmed, ['Indikator']) ?? '';
      goal.zielerreichung = _extractField(trimmed, [
            'Zielerreichungsgrad',
            'Ziel erreicht',
          ]) ??
          '';
      goal.erlaeuterung = _extractField(trimmed, [
            'Erläuterung zur Zielerreichung',
            r'c\)\s*Sichtweise des Leistungserbringers',
          ]) ??
          '';
      goal.abweichendeSicht = _extractField(trimmed, [
            'Abweichende Einschätzung der leistungsberechtigten Person',
            'Abweichende Einschätzung',
          ]) ??
          '';

      if (goal.leitziel.isNotEmpty || goal.erlaeuterung.isNotEmpty) {
        goals.add(goal);
      }
    }
    return goals;
  }

  /// Extrahiert den Inhalt einer Markdown-Sektion. Unterstützt drei
  /// Schreibweisen:
  ///   1) `- **Indikator:** Wert auf gleicher Zeile`
  ///   2) `**Indikator**` auf eigener Zeile, Wert in den Folgezeilen
  ///   3) `Indikator: Wert` ohne Markdown-Bold
  /// Liefert den ersten passenden Treffer.
  static String? _extractField(String block, List<String> headlines) {
    for (final h in headlines) {
      // Toleranter Label-Teil: erlaubt optional einen Klammer-Zusatz im
      // Bold, z.B. "**Indikator (woran ist die Erreichung erkennbar?):**".
      // Das LLM legt manchmal solche Hinweise ins Label.
      final labelFlex =
          h + r'(?:\s*\([^)]*\))?'; // optional " (…irgendwas…)"

      // 1) Inline-Variante (Kompakt-Schema):
      //    "- **Indikator:** Herr Frisch verlässt die Wohnung..."
      final inlineBold = RegExp(
        r'^[\s\-•]*\*\*' + labelFlex + r'\s*:?\s*\*\*\s*:?\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      );
      final inlineMatch = inlineBold.firstMatch(block);
      if (inlineMatch != null) {
        final val = inlineMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }

      // 2) Block-Variante (TIB-Schema): "**Indikator**" auf eigener Zeile,
      //    Wert in den Folgezeilen bis zur nächsten Headline / Trenner.
      final blockBold = RegExp(
        r'^[\s\-•]*\*\*' + labelFlex + r'\s*:?\s*\*\*\s*$\s*([^*\n][^\n]*(?:\n(?![\s\-•]*\*\*|[a-h]\)\s|###|---)[^\n]*)*)',
        multiLine: true,
        caseSensitive: false,
      );
      final blockMatch = blockBold.firstMatch(block);
      if (blockMatch != null) {
        final val = blockMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }

      // 3) Plain-Variante ohne Markdown: "Indikator: Wert"
      final plain = RegExp(
        r'^[\s\-•]*' + labelFlex + r'\s*:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      );
      final plainMatch = plain.firstMatch(block);
      if (plainMatch != null) {
        final val = plainMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
    }
    return null;
  }
}

class _GoalEntry {
  String leitziel = '';
  String teilhabezielText = '';
  String indikator = '';
  String zielerreichung = '';
  String erlaeuterung = '';
  String abweichendeSicht = '';
}
