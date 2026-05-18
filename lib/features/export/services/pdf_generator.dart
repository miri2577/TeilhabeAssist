import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/pdf_design.dart';

const _germanMonths = [
  '',
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Erzeugt druckfertige Berichte im FEGH-Hybrid-Design.
///
/// Das Layout kombiniert einen klassischen behördlichen Header/Footer
/// (Trägername + Berichtstyp + Aktenzeichen + Datum) mit einer modernen
/// Hero-Sektion (Zeitraum/Titel groß), KPI-Karten für Kennzahlen und
/// nummerierten Section-Headings.
class PdfGenerator {
  PdfGenerator._();

  static const String _appName = 'TeilhabeAssist';
  static const String _appTagline = 'Eingliederungshilfe nach SGB IX';

  /// Generiert einen Informationsbericht.
  /// Wenn `structured` vorhanden: pro Ziel/Sektion eigene Sub-Blöcke mit
  /// passenden Höhen — sauber strukturiert statt Markdown-Fließtext.
  static Future<Uint8List> generateInformationsbericht({
    required String generatedText,
    required Map<String, String> metadata,
    Map<String, dynamic>? structured,
    Uint8List? logoBytes,
  }) {
    return _generate(
      title: 'Informationsbericht',
      hero: ('BERICHTSZEITRAUM', _heroTitle(metadata), _heroSubtitle(metadata)),
      kpiRow: _kpiRow(metadata, isBrp: false),
      sections: _informationsberichtSections(generatedText),
      structured: structured,
      metadata: metadata,
      logoBytes: logoBytes,
    );
  }

  /// Generiert einen BRP-Bericht.
  static Future<Uint8List> generateBrp({
    required String generatedText,
    required Map<String, String> metadata,
    Map<String, dynamic>? structured,
    Uint8List? logoBytes,
  }) {
    return _generate(
      title: 'BRP — 4. Berliner Fassung',
      hero: ('BERICHTSZEITRAUM', _heroTitle(metadata), _heroSubtitle(metadata)),
      kpiRow: _kpiRow(metadata, isBrp: true),
      sections: _brpSections(generatedText),
      structured: structured,
      metadata: metadata,
      logoBytes: logoBytes,
    );
  }

  static Future<Uint8List> _generate({
    required String title,
    required (String, String, String) hero,
    required List<PdfKpi> kpiRow,
    required List<_PdfSection> sections,
    required Map<String, String> metadata,
    Map<String, dynamic>? structured,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    final aktenzeichen = metadata['id_kostenuebernahme'] ?? '';
    final authorName = metadata['leistungserbringer'] ?? '';
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final children = <pw.Widget>[
      pw.SizedBox(height: 24),
      buildHero(label: hero.$1, title: hero.$2, subtitle: hero.$3),
      pw.SizedBox(height: 28),
      if (kpiRow.isNotEmpty) ...[
        buildKpiRow(kpiRow),
        pw.SizedBox(height: 28),
      ],
      // Heading + KV-Tabelle als atomarer Block — verhindert dass die
      // Überschrift auf einer Seite steht und die Tabelle auf der nächsten
      // beginnt.
      _atomic([
        buildSectionHeading('I', 'Angaben zur leistungsberechtigten Person'),
        pw.SizedBox(height: 12),
        buildEditableKeyValueTable(_personalEntriesEditable(metadata)),
      ]),
      pw.SizedBox(height: 28),
    ];

    // Wenn die strukturierte Schema-Map vorhanden ist (Informationsbericht
    // Kompakt oder TIB), rendern wir jede Sub-Sektion eigenständig — pro
    // Schema-Key ein eigenes TextField mit passender Höhe. Das verhindert
    // Roh-Markdown-Inhalt im Fließtext und liefert sauber strukturierte
    // Editierfelder.
    final hasStructuredAllgemein = structured != null &&
        structured['allgemeine_informationen'] is Map;
    final hasStructuredZiele = structured != null &&
        (structured['teilhabeziele'] is List) &&
        (structured['teilhabeziele'] as List).isNotEmpty;
    final hasStructuredAssistenz = structured != null &&
        structured['assistenzleistungen'] is Map;
    final hasStructuredZusammenfassung = structured != null &&
        structured['zusammenfassung'] is Map;
    final useStructured = hasStructuredAllgemein ||
        hasStructuredZiele ||
        hasStructuredAssistenz ||
        hasStructuredZusammenfassung;

    if (useStructured) {
      var n = 2;
      // Jede Hauptsektion startet auf einer neuen Seite — Section I
      // (Angaben zur Person) bleibt als „Deckblatt" auf Seite 1.
      if (hasStructuredAllgemein) {
        children.add(pw.NewPage());
        children.addAll(_renderAllgemeineInfoStructured(
          number: _roman(n++),
          sectionTitle: 'Allgemeine Informationen zur Lebenssituation',
          info: Map<String, dynamic>.from(
              structured['allgemeine_informationen'] as Map),
        ));
      }
      if (hasStructuredZiele) {
        children.add(pw.NewPage());
        children.addAll(_renderTeilhabezieleStructured(
          number: _roman(n++),
          sectionTitle: 'Bericht zu vereinbarten Teilhabezielen',
          ziele: List<Map<String, dynamic>>.from(
              (structured['teilhabeziele'] as List).whereType<Map>()),
        ));
      }
      if (hasStructuredAssistenz) {
        children.add(pw.NewPage());
        children.addAll(_renderAssistenzleistungenStructured(
          number: _roman(n++),
          sectionTitle: 'Assistenzleistungen',
          assistenz: Map<String, dynamic>.from(
              structured['assistenzleistungen'] as Map),
        ));
      }
      if (hasStructuredZusammenfassung) {
        children.add(pw.NewPage());
        children.addAll(_renderZusammenfassungStructured(
          number: _roman(n++),
          sectionTitle: 'Zusammenfassung und Ausblick',
          zus: Map<String, dynamic>.from(
              structured['zusammenfassung'] as Map),
        ));
      }
    } else {
      // Fallback: Markdown-Sections-Pfad (z.B. BRP oder wenn keine
      // strukturierte Map vorhanden ist).
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final number = _roman(i + 2);
        children.add(_atomic([
          buildSectionHeading(number, section.title),
          pw.SizedBox(height: 12),
        ]));
        children.add(buildEditableBlock(
          name: 'section_${i + 1}',
          defaultValue: section.body.trim(),
          minHeight: 120,
        ));
        children.add(pw.SizedBox(height: 24));
      }
    }

    children
      ..add(pw.SizedBox(height: 16))
      ..add(buildSignatureRow(authorName: authorName));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 50),
      // Safety-Net: Default ist 20 Seiten. Lange Berichte oder ein
      // kurzfristig zu großer Block würden sonst eine
      // TooManyPagesException auslösen, statt einfach paginiert zu werden.
      maxPages: 200,
      header: (ctx) => buildHeader(
        title: title,
        appName: _appName,
        appTagline: _appTagline,
        aktenzeichen: aktenzeichen.isEmpty ? null : aktenzeichen,
        logo: logoImage,
      ),
      footer: (ctx) => buildFooter(ctx, appName: _appName),
      build: (ctx) => children,
    ));

    return Uint8List.fromList(await doc.save());
  }

  // ──────────────────────────────────────────────────────────────────
  //   Strukturierter Teilhabeziele-Renderer
  // ──────────────────────────────────────────────────────────────────

  /// Rendert die Teilhabeziele-Sektion als Folge eigenständiger Goal-
  /// Blöcke. Jedes Ziel bekommt:
  ///   • Sub-Heading "Teilhabeziel N"
  ///   • editierbare KV-Tabelle (Leitziel, evtl. Indikator/TZ-ZLP,
  ///     Zielerreichungsgrad)
  ///   • Multiline-TextField mit der Erläuterung (`erlaeuterung_zielerreichung`
  ///     in der Kompakt-Variante, `sicht_leistungserbringer` in TIB)
  ///   • Multiline-TextField mit der abweichenden Sicht der LB Person
  ///     (`abweichende_einschaetzung_klient` bzw. `sicht_klient`)
  ///
  /// Heading + Intro + erster Ziel-Block werden in einem `_atomic`-Wrap
  /// zusammengehalten, damit die Section-Überschrift nicht alleine am
  /// Seitenende landet.
  static List<pw.Widget> _renderTeilhabezieleStructured({
    required String number,
    required String sectionTitle,
    required List<Map<String, dynamic>> ziele,
  }) {
    final widgets = <pw.Widget>[];

    final introText = pw.Text(
      'Die folgenden Ziele wurden aus dem aktuellen Berichtsstand '
      'übernommen. Inhalte können direkt im PDF angepasst werden.',
      style: const pw.TextStyle(
        fontSize: 9.5,
        color: PdfDesignTokens.muted,
      ),
    );

    for (var idx = 0; idx < ziele.length; idx++) {
      // Goals separieren wir nicht mehr mit `pw.NewPage()` — das hat
      // zuvor Leerseiten produziert. Mit der jetzt engeren Höhen-
      // Heuristik landet jedes Ziel meistens auf einer eigenen Seite
      // bzw. teilt sich sauber mit dem nächsten.
      final ziel = ziele[idx];
      final n = idx + 1;
      final leitziel = (ziel['leitziel'] ?? '').toString().trim();
      // Kompakt-Variante: `indikator`. TIB hat das Feld nicht — dann
      // verwenden wir `umfang_unterstuetzung` als Ersatz-Zeile in der
      // KV-Tabelle, damit dort etwas Inhalt steht.
      final indikator = (ziel['indikator'] ??
              ziel['teilhabeziel_zlp'] ??
              ziel['umfang_unterstuetzung'] ??
              '')
          .toString()
          .trim();
      final indikatorLabel = ziel.containsKey('indikator')
          ? 'Indikator'
          : ziel.containsKey('teilhabeziel_zlp')
              ? 'Teilhabeziel ZLP'
              : ziel.containsKey('umfang_unterstuetzung')
                  ? 'Umfang Unterstützung'
                  : 'Indikator';
      final grad =
          _displayZielerreichung((ziel['zielerreichungsgrad'] ?? '').toString().trim());

      // Erläuterung — Kompakt: `erlaeuterung_zielerreichung`,
      // TIB: `sicht_leistungserbringer`.
      final erlaeuterung = (ziel['erlaeuterung_zielerreichung'] ??
              ziel['sicht_leistungserbringer'] ??
              ziel['erlaeuterung'] ??
              ziel['erläuterung'] ??
              '')
          .toString()
          .trim();

      // Abweichende Sicht — Kompakt: `abweichende_einschaetzung_klient`,
      // TIB: `sicht_klient`.
      final abweichend = (ziel['abweichende_einschaetzung_klient'] ??
              ziel['sicht_klient'] ??
              ziel['abweichende_sicht'] ??
              '')
          .toString()
          .trim();

      // TIB-Spezifika — falls vorhanden, als eigene Felder rendern.
      final begruendung =
          (ziel['zielerreichungs_begruendung'] ?? '').toString().trim();
      final veraenderungsbedarf =
          (ziel['veraenderungsbedarf'] ?? '').toString().trim();

      // Sub-Heading + KV-Tabelle des aktuellen Ziels.
      // Für das ERSTE Ziel zusätzlich Section-Heading + Intro mit in das
      // atomic, damit „III. Bericht zu vereinbarten Teilhabezielen" nicht
      // orphan oben auf einer Seite steht.
      final atomicHead = <pw.Widget>[];
      if (idx == 0) {
        atomicHead.addAll([
          buildSectionHeading(number, sectionTitle),
          pw.SizedBox(height: 12),
          introText,
          pw.SizedBox(height: 16),
        ]);
      }
      atomicHead.addAll([
        _zielSubHeading(n),
        pw.SizedBox(height: 8),
        buildEditableMultilineKeyValueTable([
          (
            label: 'Leitziel',
            fieldName: 'ziel_${n}_leitziel',
            value: leitziel,
            minHeight: 40.0,
          ),
          (
            label: indikatorLabel,
            fieldName: 'ziel_${n}_indikator',
            value: indikator,
            minHeight: 40.0,
          ),
          (
            label: 'Zielerreichungsgrad',
            fieldName: 'ziel_${n}_zielerreichungsgrad',
            value: grad,
            minHeight: 24.0,
          ),
        ]),
      ]);
      widgets.add(_atomic(atomicHead));
      widgets.add(pw.SizedBox(height: 10));

      // Label + Spacer atomar, Block splittbar — sonst kann ein langer
      // Erläuterungs-Text TooManyPagesException auslösen.
      widgets.add(_atomic([
        _subLabel('Erläuterung der Zielerreichung'),
        pw.SizedBox(height: 6),
      ]));
      widgets.add(buildEditableBlock(
        name: 'ziel_${n}_erlaeuterung',
        defaultValue: erlaeuterung,
        minHeight: 140,
      ));

      // TIB: Zusätzliche Begründung des Zielerreichungsgrads.
      if (begruendung.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 10));
        widgets.add(_atomic([
          _subLabel('Begründung des Zielerreichungsgrades'),
          pw.SizedBox(height: 6),
        ]));
        widgets.add(buildEditableBlock(
          name: 'ziel_${n}_begruendung',
          defaultValue: begruendung,
          minHeight: 80,
        ));
      }

      // TIB: Veränderungsbedarf für den kommenden Zeitraum.
      if (veraenderungsbedarf.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 10));
        widgets.add(_atomic([
          _subLabel('Veränderungsbedarf für den kommenden Zeitraum'),
          pw.SizedBox(height: 6),
        ]));
        widgets.add(buildEditableBlock(
          name: 'ziel_${n}_veraenderungsbedarf',
          defaultValue: veraenderungsbedarf,
          minHeight: 80,
        ));
      }

      widgets.add(pw.SizedBox(height: 10));
      widgets.add(_atomic([
        _subLabel('Abweichende Sicht der leistungsberechtigten Person'),
        pw.SizedBox(height: 6),
      ]));
      // Leerer Wert → "nein" als sinnvoller Default. So bleibt das
      // Feld nicht visuell leer, und der Inhalt deckt sich mit der
      // Markdown-Ansicht in der App.
      widgets.add(buildEditableBlock(
        name: 'ziel_${n}_abweichende_sicht',
        defaultValue: abweichend.isEmpty ? 'nein' : abweichend,
        minHeight: 50,
      ));
      widgets.add(pw.SizedBox(height: 22));
    }
    return widgets;
  }

  /// Wandelt den `zielerreichungsgrad`-Enum in lesbaren Text.
  static String _displayZielerreichung(String v) {
    return switch (v) {
      'voll_erreicht' => 'voll erreicht',
      'teilweise_erreicht' => 'teilweise erreicht',
      'nicht_erreicht' => 'nicht erreicht',
      'nicht_beurteilbar' => 'nicht beurteilbar',
      _ => v,
    };
  }

  /// Wandelt den `fls_empfehlung`-Enum in lesbaren Text.
  static String _displayFls(String v) {
    return switch (v) {
      'erhoehung' => 'Erhöhung empfohlen',
      'beibehaltung' => 'Beibehaltung empfohlen',
      'reduktion' => 'Reduktion empfohlen',
      'keine_aussage' => 'Keine Aussage',
      _ => v,
    };
  }

  // ──────────────────────────────────────────────────────────────────
  //   Strukturierte Sub-Renderer für Allgemeine Info / Assistenz /
  //   Zusammenfassung — je Sub-Schema-Key ein eigenes TextField.
  // ──────────────────────────────────────────────────────────────────

  /// Rendert „Allgemeine Informationen zur Lebenssituation" gegliedert in
  /// die drei Sub-Felder aus `_allgemeineInformationen`.
  /// Heading + erste Sub-Section sind atomar (Anti-Orphan).
  static List<pw.Widget> _renderAllgemeineInfoStructured({
    required String number,
    required String sectionTitle,
    required Map<String, dynamic> info,
  }) {
    return _renderStructuredBlocks(
      number: number,
      sectionTitle: sectionTitle,
      blocks: [
        (
          label: 'Ausbildung, Arbeit und sonstige Tagesstruktur',
          field: 'allg_ausbildung_arbeit',
          value: (info['ausbildung_arbeit_tagesstruktur'] ?? '').toString(),
        ),
        (
          label: 'Bedeutsame Kontakte',
          field: 'allg_bedeutsame_kontakte',
          value: (info['bedeutsame_kontakte'] ?? '').toString(),
        ),
        (
          label: 'Sozialraum und weitere Informationen',
          field: 'allg_sozialraum',
          value: (info['sozialraum_und_weiteres'] ?? '').toString(),
        ),
      ],
    );
  }

  /// Rendert „Assistenzleistungen" gegliedert in FLS-Übersicht, Nacht-
  /// Erreichbarkeit (Ja/Nein) und besondere Vorkommnisse.
  static List<pw.Widget> _renderAssistenzleistungenStructured({
    required String number,
    required String sectionTitle,
    required Map<String, dynamic> assistenz,
  }) {
    final nacht = assistenz['erreichbarkeit_nacht'];
    final nachtText = nacht == true
        ? 'Ja'
        : nacht == false
            ? 'Nein'
            : (nacht ?? '').toString();
    return _renderStructuredBlocks(
      number: number,
      sectionTitle: sectionTitle,
      blocks: [
        (
          label: 'Übersicht der erbrachten Fachleistungsstunden',
          field: 'assistenz_fls_uebersicht',
          value: (assistenz['fachleistungsstunden_uebersicht'] ?? '').toString(),
        ),
        (
          label: 'Erreichbarkeit in der Nacht',
          field: 'assistenz_nacht',
          value: nachtText,
        ),
        (
          label: 'Besondere Vorkommnisse',
          field: 'assistenz_vorkommnisse',
          value: (assistenz['besondere_vorkommnisse'] ?? '').toString(),
        ),
      ],
    );
  }

  /// Rendert „Zusammenfassung und Ausblick" gegliedert in
  /// Gesamteinschätzung, Empfehlung, FLS-Empfehlung (Enum + Begründung).
  static List<pw.Widget> _renderZusammenfassungStructured({
    required String number,
    required String sectionTitle,
    required Map<String, dynamic> zus,
  }) {
    final flsEnum = (zus['fls_empfehlung'] ?? '').toString().trim();
    final flsLabel = _displayFls(flsEnum);
    final flsBegruendung = (zus['fls_begruendung'] ?? '').toString().trim();
    final flsValue = flsLabel.isEmpty
        ? flsBegruendung
        : flsBegruendung.isEmpty
            ? flsLabel
            : '$flsLabel — $flsBegruendung';

    return _renderStructuredBlocks(
      number: number,
      sectionTitle: sectionTitle,
      blocks: [
        (
          label: 'Gesamteinschätzung der Teilhabesituation',
          field: 'zus_gesamteinschaetzung',
          value: (zus['gesamteinschaetzung'] ?? '').toString(),
        ),
        (
          label: 'Empfehlung für den kommenden Leistungszeitraum',
          field: 'zus_empfehlung',
          value: (zus['empfehlung_kommender_zeitraum'] ?? '').toString(),
        ),
        (
          label: 'Anpassung der Fachleistungsstunden',
          field: 'zus_fls',
          value: flsValue,
        ),
      ],
    );
  }

  /// Gemeinsame Render-Routine: Section-Heading + Folge benannter Blöcke.
  /// Heading + Label des ersten Blocks werden in einem `_atomic` gebündelt,
  /// damit die Section-Überschrift nicht ohne Folgeinhalt am Seitenende
  /// steht. Body-TextFields sind splittbar — lange Inhalte paginieren
  /// sauber über mehrere Seiten.
  static List<pw.Widget> _renderStructuredBlocks({
    required String number,
    required String sectionTitle,
    required List<({String label, String field, String value})> blocks,
  }) {
    final widgets = <pw.Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final atomicHead = <pw.Widget>[];
      if (i == 0) {
        atomicHead.addAll([
          buildSectionHeading(number, sectionTitle),
          pw.SizedBox(height: 14),
        ]);
      }
      atomicHead.addAll([
        _subLabel(b.label),
        pw.SizedBox(height: 6),
      ]);
      widgets.add(_atomic(atomicHead));
      widgets.add(buildEditableBlock(
        name: b.field,
        defaultValue: b.value.trim(),
        minHeight: 70,
      ));
      widgets.add(pw.SizedBox(height: 14));
    }
    return widgets;
  }

  static pw.Widget _zielSubHeading(int n) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            color: PdfDesignTokens.accent,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            'TZ $n',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          'Teilhabeziel $n',
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfDesignTokens.primaer,
          ),
        ),
      ],
    );
  }

  static pw.Widget _subLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfDesignTokens.muted,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Hält eine Folge von Widgets zusammen — verhindert dass MultiPage
  /// zwischen Heading und Body bricht. `pw.Wrap` wird vom pdf-Paket als
  /// atomare Box behandelt: passt der Wrap nicht mehr auf die aktuelle
  /// Seite, rutscht er als Ganzes auf die nächste.
  static pw.Widget _atomic(List<pw.Widget> children) {
    return pw.Wrap(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //   Hero + KPI-Helper
  // ──────────────────────────────────────────────────────────────────

  static String _heroTitle(Map<String, String> metadata) {
    final raw = metadata['berichtszeitraum'] ?? '';
    if (raw.isNotEmpty) {
      // "01.03.2026 bis 31.03.2026" → "März 2026"
      final match = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(raw);
      if (match != null) {
        final m = int.tryParse(match.group(2)!) ?? 0;
        final y = match.group(3);
        if (m >= 1 && m <= 12 && y != null) {
          return '${_germanMonths[m]} $y';
        }
      }
      return raw;
    }
    final now = DateTime.now();
    return '${_germanMonths[now.month]} ${now.year}';
  }

  static String _heroSubtitle(Map<String, String> metadata) {
    final name = metadata['name'] ?? '';
    final leistungstyp = metadata['leistungstyp'] ?? '';
    final parts = [name, leistungstyp].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }

  static List<PdfKpi> _kpiRow(Map<String, String> metadata, {required bool isBrp}) {
    final kpis = <PdfKpi>[];
    final leistungstyp = metadata['leistungstyp'] ?? '';
    final fls = metadata['fachleistungsstunden'] ?? '';
    final dauer = metadata['berichtsdauer'] ?? '';
    if (leistungstyp.isNotEmpty) {
      kpis.add(PdfKpi(
        label: 'Leistungstyp',
        value: leistungstyp,
        color: PdfDesignTokens.primaer,
        hero: true,
      ));
    }
    if (fls.isNotEmpty) {
      kpis.add(PdfKpi(label: 'Fachleistungsstunden', value: fls));
    }
    if (dauer.isNotEmpty) {
      kpis.add(PdfKpi(label: 'Berichtsdauer', value: dauer));
    }
    kpis.add(PdfKpi(
      label: 'Berichtstyp',
      value: isBrp ? 'BRP 4.0' : 'IB 1.01',
      color: PdfDesignTokens.accent,
    ));
    return kpis;
  }

  static List<({String label, String fieldName, String value})>
      _personalEntriesEditable(Map<String, String> metadata) {
    return [
      (
        label: 'Familienname',
        fieldName: 'field_familienname',
        value: metadata['familienname'] ?? ''
      ),
      (
        label: 'Vorname(n)',
        fieldName: 'field_vorname',
        value: metadata['vorname'] ?? ''
      ),
      (
        label: 'Geburtsdatum',
        fieldName: 'field_geburtsdatum',
        value: metadata['geburtsdatum'] ?? ''
      ),
      (
        label: 'Adresse',
        fieldName: 'field_strasse',
        value: metadata['strasse'] ?? ''
      ),
      (
        label: 'PLZ / Ort',
        fieldName: 'field_plz_ort',
        value: metadata['plz_ort'] ?? ''
      ),
      (
        label: 'Telefon',
        fieldName: 'field_telefon',
        value: metadata['telefon'] ?? ''
      ),
      (
        label: 'ID Kostenübernahme',
        fieldName: 'field_id_kostenuebernahme',
        value: metadata['id_kostenuebernahme'] ?? ''
      ),
      (
        label: 'Leistungserbringer',
        fieldName: 'field_leistungserbringer',
        value: metadata['leistungserbringer'] ?? ''
      ),
      (
        label: 'Kontakt LE',
        fieldName: 'field_kontakt_le',
        value: metadata['kontakt_le'] ?? ''
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────────
  //   Sektionen aus generiertem Text extrahieren
  // ──────────────────────────────────────────────────────────────────

  static List<_PdfSection> _informationsberichtSections(String text) {
    final parsed = _parseSections(text, [
      _SectionPattern(['allgemeine information', 'ausbildung, arbeit'],
          'Allgemeine Informationen zur Lebenssituation'),
      _SectionPattern(['teilhabeziel', 'zielerreichung'],
          'Bericht zu vereinbarten Teilhabezielen'),
      _SectionPattern(['anmerkung'], 'Weitere Anmerkungen zu den Zielen'),
      _SectionPattern(['zusammenfassung', 'ausblick', 'empfehlung'],
          'Zusammenfassung und Ausblick'),
    ]);
    // Falls Parsing nichts gefunden hat, alles in eine Sektion packen
    if (parsed.where((s) => s.body.trim().isNotEmpty).isEmpty) {
      return [_PdfSection('Bericht', text)];
    }
    return parsed;
  }

  static List<_PdfSection> _brpSections(String text) {
    final parsed = _parseSections(text, [
      _SectionPattern(['lebenssituation', 'ressourcen'],
          'Lebenssituation und Ressourcen'),
      _SectionPattern(['icf', 'beeinträchtigung', 'teilhabebedarf'],
          'ICF-orientierte Beschreibung des Teilhabebedarfs'),
      _SectionPattern(['ziel', 'planung'],
          'Teilhabeziele und Planung'),
      _SectionPattern(['maßnahme', 'rehabilitation', 'unterstützung'],
          'Maßnahmen und Unterstützungsleistungen'),
      _SectionPattern(['zusammenfassung', 'prognose', 'ausblick'],
          'Zusammenfassung, Prognose, Ausblick'),
    ]);
    if (parsed.where((s) => s.body.trim().isNotEmpty).isEmpty) {
      return [_PdfSection('Behandlungs- und Rehabilitationsplan', text)];
    }
    return parsed;
  }

  static List<_PdfSection> _parseSections(
      String text, List<_SectionPattern> patterns) {
    final result = [
      for (final p in patterns) _PdfSection(p.title, ''),
    ];
    var current = -1;
    final buffer = StringBuffer();

    void flush() {
      if (current < 0 || current >= result.length) return;
      final existing = result[current].body;
      result[current] = _PdfSection(
        result[current].title,
        existing.isEmpty
            ? buffer.toString().trim()
            : '$existing\n${buffer.toString().trim()}',
      );
      buffer.clear();
    }

    for (final line in text.split('\n')) {
      final lower = line.toLowerCase();
      final matchedIndex = patterns.indexWhere(
        (p) => p.keywords.any((k) => lower.contains(k)),
      );
      // Markdown-Heading-Zeile selbst nicht in Body übernehmen, wenn sie
      // ein Section-Trigger ist
      if (matchedIndex >= 0) {
        flush();
        current = matchedIndex;
        // Wenn die Zeile mehr als nur die Heading-Markierung enthält
        // (z.B. "## Allgemeine Informationen zur Lebenssituation"), wird
        // sie als Body-Heading nicht erneut gerendert.
        continue;
      }
      buffer.writeln(line);
    }
    flush();
    return result;
  }

  static String _roman(int n) {
    const numerals = [
      '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
      'XI', 'XII', 'XIII', 'XIV', 'XV',
    ];
    if (n >= 0 && n < numerals.length) return numerals[n];
    return '$n';
  }
}

class _PdfSection {
  const _PdfSection(this.title, this.body);
  final String title;
  final String body;
}

class _SectionPattern {
  const _SectionPattern(this.keywords, this.title);
  final List<String> keywords;
  final String title;
}
