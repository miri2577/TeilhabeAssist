import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Professioneller PDF-Generator für Informationsberichte und BRP.
/// Erstellt eigenständige, druckfertige PDFs im A4-Format
/// nach der Struktur der offiziellen Berliner Vorlagen.
class PdfGenerator {
  PdfGenerator._();

  // --- Farben & Styles ---
  static final _headerColor = PdfColor(21, 101, 192); // Blau
  static final _lightBg = PdfColor(245, 247, 250);
  static final _borderColor = PdfColor(200, 200, 200);
  static final _black = PdfColor(30, 30, 30);
  static final _grey = PdfColor(120, 120, 120);

  static PdfFont get _titleFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
  static PdfFont get _subtitleFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
  static PdfFont get _sectionFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
  static PdfFont get _bodyFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 10);
  static PdfFont get _smallFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 8);
  static PdfFont get _labelFont =>
      PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);

  /// Generiert einen Informationsbericht als PDF.
  static Future<Uint8List> generateInformationsbericht({
    required String generatedText,
    required Map<String, String> metadata,
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.size = PdfPageSize.a4;
    doc.pageSettings.margins.all = 50;

    final sections = _parseGeneratedText(generatedText);

    // --- Seite 1: Deckblatt mit Kopfdaten ---
    var page = doc.pages.add();
    var y = _drawHeader(page, 'Informationsbericht für Leistungen der Eingliederungshilfe');
    y += 10;

    // Kopfdaten-Tabelle
    y = _drawMetadataTable(page, y, metadata);
    y += 20;

    // Personendaten
    y = _drawSectionTitle(page, y, '1. Angaben zur leistungsberechtigten Person');
    y = _drawPersonTable(page, y, metadata);

    // --- Seite 2+: Inhalt ---
    page = doc.pages.add();
    y = _drawPageHeader(page, metadata);
    y += 5;

    y = _drawSectionTitle(page, y,
        '2. Allgemeine Informationen zu Ausbildung, Arbeit und sonstiger '
        'Tagesstruktur, bedeutsame Kontakte und weitere relevante Informationen');
    y += 5;

    final allgemeineInfos = sections['allgemeine_informationen'] ??
        sections.values.firstOrNull ?? generatedText;
    y = _drawWrappedText(page, y, allgemeineInfos, doc);

    // Teilhabeziele
    y = _ensureSpace(page, y, 100, doc, metadata);
    y = _drawSectionTitle(page, y,
        '3. Bericht zu vereinbarten Teilhabezielen aus der Ziel- und Leistungsplanung');
    y += 5;

    final ziele = sections['teilhabeziele'] ?? '';
    if (ziele.isNotEmpty) {
      y = _drawWrappedText(page, y, ziele, doc, metadata: metadata);
    }

    // Weitere Anmerkungen
    y = _ensureSpace(page, y, 80, doc, metadata);
    y = _drawSectionTitle(page, y, 'Weitere Anmerkungen zu den Zielen');
    y += 5;
    final anmerkungen = sections['anmerkungen'] ?? '';
    if (anmerkungen.isNotEmpty) {
      y = _drawWrappedText(page, y, anmerkungen, doc, metadata: metadata);
    }

    // Zusammenfassung
    y = _ensureSpace(page, y, 100, doc, metadata);
    y = _drawSectionTitle(page, y, '4. Zusammenfassung/Ausblick');
    y += 5;
    final zusammenfassung = sections['zusammenfassung'] ?? '';
    if (zusammenfassung.isNotEmpty) {
      y = _drawWrappedText(page, y, zusammenfassung, doc, metadata: metadata);
    }

    // Falls kein Parsing möglich war → Volltext
    if (sections.isEmpty || sections.length <= 1) {
      y = _drawWrappedText(page, y, generatedText, doc, metadata: metadata);
    }

    // Unterschriften-Bereich
    y = _ensureSpace(page, y, 120, doc, metadata);
    y += 20;
    y = _drawSectionTitle(page, y, '5. Unterschriften');
    y += 15;
    _drawSignatureFields(page, y);

    // Footer auf allen Seiten
    for (var i = 0; i < doc.pages.count; i++) {
      _drawFooter(doc.pages[i], i + 1, doc.pages.count);
    }

    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  // --- Drawing Methods ---

  static double _drawHeader(PdfPage page, String title) {
    final bounds = page.getClientSize();

    // Blauer Balken
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_headerColor),
      bounds: Rect.fromLTWH(0, 0, bounds.width, 50),
    );

    // Titel (weiß auf blau)
    page.graphics.drawString(
      'Land Berlin – Teilhabefachdienst Soziales',
      _smallFont,
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(15, 8, bounds.width - 30, 15),
    );

    page.graphics.drawString(
      title,
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(15, 24, bounds.width - 30, 20),
    );

    return 60;
  }

  static double _drawPageHeader(PdfPage page, Map<String, String> metadata) {
    final bounds = page.getClientSize();
    final name = metadata['name'] ?? '';

    page.graphics.drawLine(
      PdfPen(_headerColor, width: 2),
      Offset(0, 0),
      Offset(bounds.width, 0),
    );

    page.graphics.drawString(
      'Informationsbericht zu den Leistungen für: $name',
      _smallFont,
      brush: PdfSolidBrush(_grey),
      bounds: Rect.fromLTWH(0, 5, bounds.width, 15),
    );

    return 25;
  }

  static double _drawMetadataTable(
      PdfPage page, double y, Map<String, String> metadata) {
    final bounds = page.getClientSize();
    final w = bounds.width;
    final fields = [
      ['ID Kostenübernahme', metadata['id_kostenuebernahme'] ?? ''],
      ['Berichtszeitraum', metadata['berichtszeitraum'] ?? ''],
      ['Leistungstyp', metadata['leistungstyp'] ?? ''],
      ['Leistungserbringer', metadata['leistungserbringer'] ?? ''],
      ['E-Mail/Tel Nr', metadata['kontakt_le'] ?? ''],
    ];

    for (final field in fields) {
      // Label
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(_lightBg),
        bounds: Rect.fromLTWH(0, y, 160, 22),
      );
      page.graphics.drawRectangle(
        pen: PdfPen(_borderColor),
        bounds: Rect.fromLTWH(0, y, w, 22),
      );
      page.graphics.drawString(field[0], _labelFont,
          brush: PdfSolidBrush(_black),
          bounds: Rect.fromLTWH(8, y + 5, 150, 15));
      page.graphics.drawString(field[1], _bodyFont,
          brush: PdfSolidBrush(_black),
          bounds: Rect.fromLTWH(168, y + 5, w - 175, 15));
      y += 22;
    }

    return y;
  }

  static double _drawPersonTable(
      PdfPage page, double y, Map<String, String> metadata) {
    final bounds = page.getClientSize();
    final w = bounds.width;
    final half = w / 2;

    final leftFields = [
      ['Familienname', metadata['familienname'] ?? ''],
      ['Vorname(n)', metadata['vorname'] ?? ''],
      ['Geburtsdatum', metadata['geburtsdatum'] ?? ''],
    ];

    final rightFields = [
      ['Straße / Nr.', metadata['strasse'] ?? ''],
      ['PLZ / Ort', metadata['plz_ort'] ?? ''],
      ['Telefon', metadata['telefon'] ?? ''],
    ];

    y += 10;
    for (var i = 0; i < leftFields.length; i++) {
      // Links
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(_lightBg),
        bounds: Rect.fromLTWH(0, y, 100, 22),
      );
      page.graphics.drawRectangle(
        pen: PdfPen(_borderColor),
        bounds: Rect.fromLTWH(0, y, half - 5, 22),
      );
      page.graphics.drawString(leftFields[i][0], _labelFont,
          brush: PdfSolidBrush(_black),
          bounds: Rect.fromLTWH(5, y + 5, 95, 15));
      page.graphics.drawString(leftFields[i][1], _bodyFont,
          brush: PdfSolidBrush(_black),
          bounds: Rect.fromLTWH(105, y + 5, half - 115, 15));

      // Rechts
      if (i < rightFields.length) {
        page.graphics.drawRectangle(
          brush: PdfSolidBrush(_lightBg),
          bounds: Rect.fromLTWH(half + 5, y, 80, 22),
        );
        page.graphics.drawRectangle(
          pen: PdfPen(_borderColor),
          bounds: Rect.fromLTWH(half + 5, y, half - 5, 22),
        );
        page.graphics.drawString(rightFields[i][0], _labelFont,
            brush: PdfSolidBrush(_black),
            bounds: Rect.fromLTWH(half + 10, y + 5, 75, 15));
        page.graphics.drawString(rightFields[i][1], _bodyFont,
            brush: PdfSolidBrush(_black),
            bounds: Rect.fromLTWH(half + 90, y + 5, half - 100, 15));
      }

      y += 22;
    }

    return y;
  }

  static double _drawSectionTitle(PdfPage page, double y, String title) {
    final bounds = page.getClientSize();

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(230, 237, 248)),
      bounds: Rect.fromLTWH(0, y, bounds.width, 24),
    );
    page.graphics.drawRectangle(
      pen: PdfPen(_headerColor),
      bounds: Rect.fromLTWH(0, y, bounds.width, 24),
    );

    page.graphics.drawString(title, _sectionFont,
        brush: PdfSolidBrush(_headerColor),
        bounds: Rect.fromLTWH(8, y + 5, bounds.width - 16, 18));

    return y + 30;
  }

  static double _drawWrappedText(
    PdfPage page,
    double startY,
    String text,
    PdfDocument doc, {
    Map<String, String>? metadata,
  }) {
    final bounds = page.getClientSize();
    final maxHeight = bounds.height - 40; // Reserve für Footer
    var y = startY;
    var currentPage = page;

    // Text in Absätze splitten
    final paragraphs = text.split('\n');

    for (final para in paragraphs) {
      if (para.trim().isEmpty) {
        y += 8;
        continue;
      }

      // Prüfe ob Überschrift
      PdfFont font;
      PdfBrush brush;
      if (para.startsWith('##')) {
        font = _subtitleFont;
        brush = PdfSolidBrush(_headerColor);
        y += 8;
      } else if (para.startsWith('#')) {
        font = _sectionFont;
        brush = PdfSolidBrush(_headerColor);
        y += 12;
      } else {
        font = _bodyFont;
        brush = PdfSolidBrush(_black);
      }

      final cleanPara = para.replaceAll(RegExp(r'^#+\s*'), '');

      // Textgröße messen
      final size = font.measureString(cleanPara,
          layoutArea: Size(bounds.width, 0));

      // Seitenumbruch wenn nötig
      if (y + size.height > maxHeight) {
        currentPage = doc.pages.add();
        if (metadata != null) {
          y = _drawPageHeader(currentPage, metadata);
        } else {
          y = 10;
        }
      }

      // Text zeichnen
      currentPage.graphics.drawString(
        cleanPara,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(0, y, bounds.width, size.height + 5),
        format: PdfStringFormat(lineSpacing: 3),
      );

      y += size.height + 6;
    }

    return y;
  }

  static double _ensureSpace(PdfPage page, double y, double needed,
      PdfDocument doc, Map<String, String> metadata) {
    final bounds = page.getClientSize();
    if (y + needed > bounds.height - 40) {
      final newPage = doc.pages.add();
      return _drawPageHeader(newPage, metadata);
    }
    return y;
  }

  static void _drawSignatureFields(PdfPage page, double y) {
    final bounds = page.getClientSize();
    final half = bounds.width / 2;

    page.graphics.drawString('Ort, Datum', _labelFont,
        brush: PdfSolidBrush(_grey),
        bounds: Rect.fromLTWH(0, y, half - 20, 15));
    page.graphics.drawString(
        'Leistungserbringer (Ansprechperson)', _labelFont,
        brush: PdfSolidBrush(_grey),
        bounds: Rect.fromLTWH(half + 10, y, half - 10, 15));

    y += 18;
    page.graphics.drawLine(
        PdfPen(_black), Offset(0, y), Offset(half - 20, y));
    page.graphics.drawLine(
        PdfPen(_black), Offset(half + 10, y), Offset(bounds.width, y));
  }

  static void _drawFooter(PdfPage page, int pageNum, int totalPages) {
    final bounds = page.getClientSize();
    final y = bounds.height - 15;

    page.graphics.drawLine(
      PdfPen(_borderColor),
      Offset(0, y - 5),
      Offset(bounds.width, y - 5),
    );

    page.graphics.drawString(
      'Informationsbericht – Version 1.01',
      _smallFont,
      brush: PdfSolidBrush(_grey),
      bounds: Rect.fromLTWH(0, y, 200, 12),
    );

    page.graphics.drawString(
      'Erstellt mit TeilhabeAssist',
      _smallFont,
      brush: PdfSolidBrush(_grey),
      bounds: Rect.fromLTWH(bounds.width / 2 - 50, y, 100, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    page.graphics.drawString(
      'Seite $pageNum / $totalPages',
      _smallFont,
      brush: PdfSolidBrush(_grey),
      bounds: Rect.fromLTWH(bounds.width - 80, y, 80, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
  }

  /// Parst den generierten Text in Abschnitte
  static Map<String, String> _parseGeneratedText(String text) {
    final sections = <String, String>{};
    final lines = text.split('\n');
    var currentSection = 'allgemeine_informationen';
    final buffer = StringBuffer();

    for (final line in lines) {
      final lower = line.toLowerCase();

      if (lower.contains('allgemeine information') ||
          lower.contains('ausbildung, arbeit')) {
        if (buffer.isNotEmpty) sections[currentSection] = buffer.toString();
        currentSection = 'allgemeine_informationen';
        buffer.clear();
      } else if (lower.contains('teilhabeziel') ||
          lower.contains('zielerreichung')) {
        if (buffer.isNotEmpty) sections[currentSection] = buffer.toString();
        currentSection = 'teilhabeziele';
        buffer.clear();
      } else if (lower.contains('anmerkung') && lower.contains('ziel')) {
        if (buffer.isNotEmpty) sections[currentSection] = buffer.toString();
        currentSection = 'anmerkungen';
        buffer.clear();
      } else if (lower.contains('zusammenfassung') ||
          lower.contains('ausblick') ||
          lower.contains('empfehlung')) {
        if (buffer.isNotEmpty) sections[currentSection] = buffer.toString();
        currentSection = 'zusammenfassung';
        buffer.clear();
      }

      buffer.writeln(line);
    }

    if (buffer.isNotEmpty) sections[currentSection] = buffer.toString();
    return sections;
  }
}
