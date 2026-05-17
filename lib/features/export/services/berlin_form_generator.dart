import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart' as pdf show PdfFieldFlags;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Originalgetreuer PDF-Generator für den Berliner Informationsbericht 1.01.
///
/// Statt die offizielle JavaScript-getriebene PDF-Vorlage zu befüllen (das
/// scheitert wegen der dynamischen `Weiteres Teilhabeziel angeben`-Buttons),
/// bauen wir das Layout 1:1 mit dem `pdf`-Package nach: gleiche Sektion-
/// Reihenfolge, gleiche Beschriftungen, gleicher Stil — pro Teilhabeziel
/// eine eigene Seite im 3a-Stil.
class BerlinFormGenerator {
  BerlinFormGenerator._();

  /// Schwarz-Weiß-Layout wie im Original — keine farbigen Header-Balken.
  static const _black = PdfColors.black;
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFEEEEEE);
  static const _borderGrey = PdfColor.fromInt(0xFFAAAAAA);

  static pw.TextStyle _h1(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      );
  static pw.TextStyle _sectionTitle(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      );
  static pw.TextStyle _label(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 9,
        color: _grey,
      );
  static pw.TextStyle _body(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 10,
        color: _black,
      );
  static pw.TextStyle _hint(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 8,
        fontStyle: pw.FontStyle.italic,
        color: _grey,
      );
  static pw.TextStyle _footer(pw.Font font) => pw.TextStyle(
        font: font,
        fontSize: 8,
        color: _grey,
      );

  static Future<Uint8List> generate({
    required Map<String, dynamic> data,
    required Map<String, String> metadata,
  }) async {
    final logoBytes = (await rootBundle.load(
      'assets/templates/land_berlin_logo.jpg',
    )).buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    final doc = pw.Document();

    // Schriften — Roboto via printing-Package. Wird beim ersten Aufruf
    // einmalig aus dem Asset-Cache geladen und liefert volle Umlaut-
    // Unterstützung (Helvetica-Standard-PDF-Font kann ASCII-only).
    final regular = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();

    final klientName = _klientName(metadata);

    // ── Seite 1: Kopfdaten + Personalien ──────────────────────────
    doc.addPage(_titlePage(
      logo: logo,
      regular: regular,
      bold: bold,
      metadata: metadata,
      klientName: klientName,
    ));

    // ── Seite 2: Allgemeine Informationen ─────────────────────────
    doc.addPage(_pageAllgemeineInformationen(
      regular: regular,
      bold: bold,
      data: data['allgemeine_informationen'] as Map<String, dynamic>?,
      klientName: klientName,
    ));

    // ── Seite 3a, 3b, ... : Teilhabeziele (eine Seite pro Ziel) ───
    final goals = (data['teilhabeziele'] as List?) ?? const [];
    for (var i = 0; i < goals.length; i++) {
      doc.addPage(_pageTeilhabeziel(
        regular: regular,
        bold: bold,
        goal: goals[i] as Map<String, dynamic>,
        goalIndex: i + 1,
        totalGoals: goals.length,
        klientName: klientName,
      ));
    }

    // ── Seite 4: Weitere Anmerkungen + Erreichbarkeit Nacht ──────
    doc.addPage(_pageAnmerkungen(
      regular: regular,
      bold: bold,
      assistenz: data['assistenzleistungen'] as Map<String, dynamic>?,
      klientName: klientName,
    ));

    // ── Seite 5: Zusammenfassung + Unterschriften ────────────────
    doc.addPage(_pageZusammenfassung(
      regular: regular,
      bold: bold,
      zus: data['zusammenfassung'] as Map<String, dynamic>?,
      metadata: metadata,
      klientName: klientName,
    ));

    return doc.save().then((b) => Uint8List.fromList(b));
  }

  // ────────────────────────────────────────────────────────────────────
  //   Seite 1 — Titelblatt mit Kopfdaten und Personalien
  // ────────────────────────────────────────────────────────────────────

  static pw.Page _titlePage({
    required pw.MemoryImage logo,
    required pw.Font regular,
    required pw.Font bold,
    required Map<String, String> metadata,
    required String klientName,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header: Logo + "Land Berlin / Teilhabefachdienst Soziales"
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 45,
                width: 52,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Land Berlin',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 12,
                      )),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Teilhabefachdienst Soziales — '
                    '${metadata['teilhabefachdienst'] ?? 'bitte auswählen'}',
                    style: pw.TextStyle(font: regular, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text(
              'Informationsbericht für Leistungen der Eingliederungshilfe',
              style: _h1(bold),
            ),
          ),
          pw.SizedBox(height: 18),
          _kvTable(regular, bold, [
            ('field_id_kostenuebernahme', 'ID Kostenübernahme',
                metadata['id_kostenuebernahme']),
            ('field_berichtszeitraum', 'Berichtszeitraum',
                _combineDates(metadata['berichtszeitraum_von'],
                    metadata['berichtszeitraum_bis'])),
            ('field_leistungstyp', 'Leistungstyp', metadata['leistungstyp']),
            ('field_leistungserbringer', 'Leistungserbringer',
                metadata['leistungserbringer']),
            ('field_kontakt_le', 'E-Mail / Tel Nr', metadata['kontakt_le']),
          ]),
          pw.SizedBox(height: 14),
          pw.Text('Adresse', style: _sectionTitle(bold)),
          pw.SizedBox(height: 4),
          _kvTable(regular, bold, [
            ('field_strasse', 'Straße', metadata['strasse']),
            ('field_hausnummer', 'Hausnummer (von)', metadata['hausnummer']),
            ('field_weitere_adresse', 'weiterer Adresshinweis',
                metadata['weitere_adresse']),
            ('field_plz', 'Postleitzahl', metadata['plz']),
            ('field_ort', 'Ort', metadata['ort']),
          ]),
          pw.SizedBox(height: 18),
          pw.Text(
            '1. Angaben zur leistungsberechtigten Person '
            '(Bitte die Angaben zur Person immer prüfen)',
            style: _sectionTitle(bold),
          ),
          pw.SizedBox(height: 6),
          _kvTable(regular, bold, [
            ('field_anrede', 'Anrede', metadata['anrede']),
            ('field_titel', 'Titel', metadata['titel']),
            ('field_familienname', 'Familienname', metadata['familienname']),
            ('field_vorname', 'Vorname(n)', metadata['vorname']),
            ('field_geburtsname', 'Geburtsname', metadata['geburtsname']),
            ('field_geburtsdatum', 'Geburtsdatum', metadata['geburtsdatum']),
            ('field_geburtsort', 'Geburtsort', metadata['geburtsort']),
            ('field_geschlecht', 'Geschlecht', metadata['geschlecht']),
            ('field_familienstand', 'Familienstand',
                metadata['familienstand']),
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Kontaktinformationen', style: _sectionTitle(bold)),
          pw.SizedBox(height: 4),
          _kvTable(regular, bold, [
            ('field_telefon_festnetz', 'Telefon (Festnetz)',
                metadata['telefon_festnetz']),
            ('field_telefon_mobil', 'Telefon (Mobil)',
                metadata['telefon_mobil']),
            ('field_email', 'E-Mail', metadata['email']),
          ]),
          pw.Spacer(),
          _pageFooter(regular, page: 1, klientName: klientName),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Seite 2 — Allgemeine Informationen
  // ────────────────────────────────────────────────────────────────────

  static pw.MultiPage _pageAllgemeineInformationen({
    required pw.Font regular,
    required pw.Font bold,
    required Map<String, dynamic>? data,
    required String klientName,
  }) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 40),
      header: (ctx) => _topBanner(regular, klientName),
      footer: (ctx) => _pageFooter(regular,
          page: ctx.pageNumber + 1, klientName: klientName, hideName: true),
      build: (ctx) => [
        pw.Text(
          'Ab diesem Punkt handelt es sich ausschließlich um die '
          'Einschätzung des Leistungserbringers',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          '2. Allgemeine Informationen zu Ausbildung, Arbeit und sonstige '
          'Tagesstruktur, bedeutsame Kontakte und weitere relevante '
          'Informationen',
          style: _sectionTitle(bold),
        ),
        pw.SizedBox(height: 12),
        if (data != null) ...[
          _subsection(
            regular, bold,
            title: 'Ausbildung, Arbeit und sonstige Tagesstruktur',
            hint: 'Angaben zu Ausbildungs-/Beschäftigungsverhältnissen, '
                'Voll-/Teilzeit, sonstige Alltagsgestaltung (Ehrenamt, '
                'Hobbys, Treffpunkte u.a.)',
            body: data['ausbildung_arbeit_tagesstruktur']?.toString(),
          ),
          _subsection(
            regular, bold,
            title: 'Bedeutsame Kontakte',
            hint: 'Regelmäßige/wichtige Kontakte der leistungsberechtigten '
                'Person (z.B. Verwandte / Freunde).',
            body: data['bedeutsame_kontakte']?.toString(),
          ),
          _subsection(
            regular, bold,
            title: 'Einschätzungen zum Sozialraum',
            hint: '',
            body: data['sozialraum_und_weiteres']?.toString(),
          ),
        ],
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Seite 3a/b/c/... — Teilhabeziele (eine pro Ziel)
  // ────────────────────────────────────────────────────────────────────

  static pw.MultiPage _pageTeilhabeziel({
    required pw.Font regular,
    required pw.Font bold,
    required Map<String, dynamic> goal,
    required int goalIndex,
    required int totalGoals,
    required String klientName,
  }) {
    final zg = goal['zielerreichungsgrad']?.toString() ?? '';
    final abw =
        goal['abweichende_einschaetzung_klient']?.toString().trim() ?? '';
    final hatAbw = abw.isNotEmpty;
    final erlaeuterung = (goal['erlaeuterung_zielerreichung'] ??
            goal['sicht_leistungserbringer'])
        ?.toString();

    final slot = String.fromCharCode('a'.codeUnitAt(0) + (goalIndex - 1));

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 40),
      header: (ctx) => _topBanner(regular, klientName),
      footer: (ctx) => _pageFooterCustom(
        regular,
        leftText: 'Informationsbericht — Teilhabeziel $goalIndex / $totalGoals',
        rightText: '3$slot',
      ),
      build: (ctx) => [
        pw.Text(
          '3. Bericht zu vereinbarten Teilhabezielen aus der Ziel- und '
          'Leistungsplanung (ZLP)',
          style: _sectionTitle(bold),
        ),
        pw.SizedBox(height: 12),
        _kvTable(regular, bold, [
          ('field_goal${goalIndex}_leitziel', 'Leitziel $goalIndex',
              goal['leitziel']?.toString()),
          ('field_goal${goalIndex}_zlp',
              'Teilhabeziel $goalIndex aus ZLP',
              goal['teilhabeziel_zlp']?.toString()),
          ('field_goal${goalIndex}_indikator', 'Indikator',
              goal['indikator']?.toString()),
        ]),
        pw.SizedBox(height: 14),
        pw.Text('Ziel erreicht?', style: _sectionTitle(bold)),
        pw.SizedBox(height: 6),
        _checkboxRow(regular, [
          ('Das Ziel wurde voll erreicht.', zg == 'voll_erreicht'),
          ('Das Ziel wurde teilweise erreicht.', zg == 'teilweise_erreicht'),
          ('Das Ziel wurde nicht erreicht.', zg == 'nicht_erreicht'),
          ('Die Zielerreichung kann nicht beurteilt werden.',
              zg == 'nicht_beurteilbar'),
        ]),
        pw.SizedBox(height: 14),
        pw.Text(
          'Gibt es eine abweichende Einschätzung der leistungsberechtigten '
          'Person?',
          style: _body(regular).copyWith(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '(Die Einschätzung der leistungsberechtigten Person erfolgt '
          'gegebenenfalls unter 6.)',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            _checkbox(regular, 'Nein', !hatAbw),
            pw.SizedBox(width: 24),
            _checkbox(regular, 'Ja', hatAbw),
          ],
        ),
        if (hatAbw) ...[
          pw.SizedBox(height: 6),
          pw.Text(abw, style: _body(regular)),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          'Erläuterung zur Zielerreichung aus der Sicht des Leistungserbringers',
          style: _sectionTitle(bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Hinweise: Was wurde erreicht/nicht erreicht? Welche Methoden/'
          'Methodik wurden eingesetzt? Warum kann ggf. keine Beurteilung '
          'erfolgen? Erläuterungen zur evtl. abweichenden Einschätzung der '
          'leistungsberechtigten Person.',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 8),
        _textBox(regular, erlaeuterung ?? ''),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Seite 4 — Weitere Anmerkungen + Erreichbarkeit Nacht
  // ────────────────────────────────────────────────────────────────────

  static pw.MultiPage _pageAnmerkungen({
    required pw.Font regular,
    required pw.Font bold,
    required Map<String, dynamic>? assistenz,
    required String klientName,
  }) {
    final nacht = assistenz?['erreichbarkeit_nacht'] == true;
    final fls = assistenz?['fachleistungsstunden_uebersicht']?.toString() ?? '';
    final vorkommnisse =
        assistenz?['besondere_vorkommnisse']?.toString() ?? '';

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 40),
      header: (ctx) => _topBanner(regular, klientName),
      footer: (ctx) => _pageFooterCustom(
        regular,
        leftText: 'Informationsbericht — Assistenzleistungen',
        rightText: '4',
      ),
      build: (ctx) => [
        pw.Text('Weitere Anmerkungen zu den Zielen', style: _sectionTitle(bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Priorisierung der Zielbearbeitung; Abgleich mit den Indikatoren; '
          'Eignung der Teilhabeziele zur Erreichung der Leitziele; '
          'Sichtweise von leistungsberechtigter Person und Leistungserbringer; '
          'fördernde und hindernde Kontextfaktoren u.ä.',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 8),
        _textBox(regular, _combine([
          if (fls.isNotEmpty) 'Übersicht der Fachleistungsstunden:\n$fls',
          if (vorkommnisse.isNotEmpty) 'Besondere Vorkommnisse:\n$vorkommnisse',
        ])),
        pw.SizedBox(height: 18),
        pw.Text(
          'Wurden im Rahmen der Assistenzleistungen auch Leistungen zur '
          'Erreichbarkeit in der Nacht in Anspruch genommen?',
          style: _body(regular).copyWith(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            _checkbox(regular, 'Nein', !nacht),
            pw.SizedBox(width: 24),
            _checkbox(regular, 'Ja', nacht),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Seite 5 — Zusammenfassung + Unterschriften + Eintragungen Klient
  // ────────────────────────────────────────────────────────────────────

  static pw.MultiPage _pageZusammenfassung({
    required pw.Font regular,
    required pw.Font bold,
    required Map<String, dynamic>? zus,
    required Map<String, String> metadata,
    required String klientName,
  }) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 40),
      header: (ctx) => _topBanner(regular, klientName),
      footer: (ctx) => _pageFooterCustom(
        regular,
        leftText: 'Informationsbericht — Zusammenfassung & Unterschriften',
        rightText: '5',
      ),
      build: (ctx) => [
        pw.Text('4. Zusammenfassung / Ausblick', style: _sectionTitle(bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Aussagen zu Umfang und Art der Unterstützung aus beiden '
          'Perspektiven berücksichtigen; Veränderung der Zielstellung; '
          'Hinweise für die neue Ziel- und Leistungsplanung.',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 8),
        if (zus != null) ...[
          _subsection(
            regular, bold,
            title: 'Gesamteinschätzung der Teilhabesituation',
            body: zus['gesamteinschaetzung']?.toString(),
          ),
          _subsection(
            regular, bold,
            title: 'Empfehlung für den kommenden Leistungszeitraum',
            body: zus['empfehlung_kommender_zeitraum']?.toString(),
          ),
          _subsection(
            regular, bold,
            title: 'Anpassung der Fachleistungsstunden',
            body: '${_flsLabel(zus['fls_empfehlung'])} — '
                '${zus['fls_begruendung'] ?? ''}',
          ),
        ],
        pw.SizedBox(height: 28),
        pw.Text('5. Unterschriften', style: _sectionTitle(bold)),
        pw.SizedBox(height: 12),
        _signatureRow(regular, metadata),
        pw.SizedBox(height: 28),
        pw.Text(
          '6. Eintragungen der leistungsberechtigten Person',
          style: _sectionTitle(bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '(zum Beispiel zur Kenntnis / Einverständnis / andere Sichtweise)',
          style: _hint(regular),
        ),
        pw.SizedBox(height: 8),
        _emptyTextBox(regular, minHeight: 120),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Bausteine
  // ────────────────────────────────────────────────────────────────────

  static pw.Widget _topBanner(pw.Font regular, String klientName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      child: pw.Text(
        'Informationsbericht zu den Leistungen für: '
        '${klientName.isEmpty ? '_______________' : klientName}',
        style: pw.TextStyle(font: regular, fontSize: 9, color: _grey),
      ),
    );
  }

  static pw.Widget _pageFooter(
    pw.Font regular, {
    required int page,
    required String klientName,
    bool hideName = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Informationsbericht', style: _footer(regular)),
          pw.Text('Version 1.01', style: _footer(regular)),
          pw.Text('$page', style: _footer(regular)),
        ],
      ),
    );
  }

  static pw.Widget _pageFooterCustom(
    pw.Font regular, {
    required String leftText,
    required String rightText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(leftText, style: _footer(regular)),
          pw.Text('Version 1.01', style: _footer(regular)),
          pw.Text(rightText, style: _footer(regular)),
        ],
      ),
    );
  }

  /// Tabellarisches Label-Value-Layout im Stil des Original-PDF:
  /// linker Spaltenanteil ~35% in hellgrau hinterlegt, fett; rechts ein
  /// **editierbares** AcroForm-Textfeld mit dem Wert als Default.
  static pw.Widget _kvTable(
    pw.Font regular,
    pw.Font bold,
    List<(String, String, String?)> rows, // (fieldName, label, value)
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderGrey, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(3),
      },
      children: [
        for (final r in rows)
          pw.TableRow(
            children: [
              pw.Container(
                color: _lightGrey,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: pw.Text(r.$2,
                    style: pw.TextStyle(
                        font: bold, fontSize: 9, color: _black)),
              ),
              pw.Container(
                height: 18,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                child: pw.TextField(
                  name: r.$1,
                  value: (r.$3 ?? '').trim(),
                  defaultValue: (r.$3 ?? '').trim(),
                  textStyle: pw.TextStyle(font: regular, fontSize: 10),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _subsection(
    pw.Font regular,
    pw.Font bold, {
    required String title,
    String hint = '',
    String? body,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: bold, fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
          if (hint.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(hint, style: _hint(regular)),
          ],
          pw.SizedBox(height: 4),
          _textBox(regular, body ?? ''),
        ],
      ),
    );
  }

  /// Editierbares Multi-Line-Textfeld. Beim Öffnen im PDF-Reader kann die
  /// Fachkraft den Text anpassen, ohne das Layout zu verlassen.
  static int _fieldCounter = 0;
  static pw.Widget _textBox(pw.Font regular, String text, {String? name}) {
    final t = text.trim();
    final fieldName = name ?? 'field_body_${++_fieldCounter}';
    // Höhe nach Text-Länge bemessen, mindestens 60, maximal ~330
    final lines = (t.length / 90).ceil().clamp(3, 28);
    final height = (lines * 12.0).clamp(60.0, 330.0);
    return pw.Container(
      width: double.infinity,
      height: height,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.4),
      ),
      child: pw.TextField(
        name: fieldName,
        value: t,
        defaultValue: t,
        fieldFlags: const {pdf.PdfFieldFlags.multiline},
        textStyle: pw.TextStyle(font: regular, fontSize: 10),
      ),
    );
  }

  static pw.Widget _emptyTextBox(pw.Font regular,
      {double minHeight = 80, String? name}) {
    return pw.Container(
      width: double.infinity,
      height: minHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.4),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.TextField(
        name: name ?? 'field_empty_${++_fieldCounter}',
        defaultValue: '',
        fieldFlags: const {pdf.PdfFieldFlags.multiline},
        textStyle: pw.TextStyle(font: regular, fontSize: 10),
      ),
    );
  }

  static pw.Widget _checkboxRow(
      pw.Font regular, List<(String, bool)> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: _checkbox(regular, item.$1, item.$2),
          ),
      ],
    );
  }

  static pw.Widget _checkbox(pw.Font regular, String label, bool checked) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 11,
          height: 11,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _black, width: 0.6),
          ),
          alignment: pw.Alignment.center,
          child: checked
              ? pw.Text('×',
                  style: pw.TextStyle(
                      font: regular,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold))
              : null,
        ),
        pw.SizedBox(width: 6),
        pw.Text(label, style: _body(regular)),
      ],
    );
  }

  static pw.Widget _signatureRow(pw.Font regular, Map<String, String> meta) {
    pw.Widget column(String label) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 32,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _black, width: 0.6)),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(label, style: _label(regular)),
            ],
          ),
        );

    return pw.Row(
      children: [
        column('Ort, Datum'),
        pw.SizedBox(width: 24),
        column('Leistungserbringer (Ansprechperson / Bezugsbetreuung / '
            'Kontakt beim Leistungserbringer)'),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //   Helpers
  // ────────────────────────────────────────────────────────────────────

  static String _klientName(Map<String, String> meta) {
    final v = (meta['vorname'] ?? '').trim();
    final f = (meta['familienname'] ?? '').trim();
    if (v.isEmpty && f.isEmpty) return '';
    return '$f, $v'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
  }

  static String _combineDates(String? a, String? b) {
    final ta = (a ?? '').trim();
    final tb = (b ?? '').trim();
    if (ta.isEmpty && tb.isEmpty) return '';
    return '$ta — $tb';
  }

  static String _flsLabel(dynamic v) {
    return switch (v?.toString()) {
      'erhoehung' => 'Erhöhung empfohlen',
      'beibehaltung' => 'Beibehaltung empfohlen',
      'reduktion' => 'Reduktion empfohlen',
      'keine_aussage' => 'Keine Aussage möglich',
      _ => (v ?? '').toString(),
    };
  }

  static String _combine(List<String> parts) =>
      parts.where((s) => s.trim().isNotEmpty).join('\n\n');
}
