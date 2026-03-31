import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Befüllt die Original-Berliner PDF-Formulare mit generierten Daten.
/// Nutzt Syncfusion zum Laden der Templates und Einfügen von Text
/// in die Formularfelder bzw. auf feste Positionen.
class FormFillerService {
  FormFillerService._();

  /// Befüllt den Informationsbericht v1.01 mit den Berichtsdaten.
  static Future<Uint8List> fillInformationsbericht({
    required String generatedText,
    required Map<String, String> metadata,
  }) async {
    // Original-Template laden
    final templateBytes = await rootBundle.load(
      'assets/templates/informationsbericht_101.pdf',
    );
    final doc = PdfDocument(inputBytes: templateBytes.buffer.asUint8List());

    // Formularfelder befüllen (falls vorhanden)
    final form = doc.form;
    _trySetField(form, 'ID Kostenübernahme', metadata['id_kostenuebernahme']);
    _trySetField(form, 'Berichtszeitraum von', metadata['berichtszeitraum_von']);
    _trySetField(form, 'Berichtszeitraum bis', metadata['berichtszeitraum_bis']);
    _trySetField(form, 'Leistungstyp', metadata['leistungstyp']);
    _trySetField(form, 'Leistungserbringer', metadata['leistungserbringer']);
    _trySetField(form, 'Familienname', metadata['familienname']);
    _trySetField(form, 'Vorname', metadata['vorname']);
    _trySetField(form, 'Geburtsdatum', metadata['geburtsdatum']);

    // Fließtext in die Freitextbereiche schreiben
    final sections = _parseSections(generatedText);

    // Seite 2: Allgemeine Informationen (großes Textfeld)
    if (doc.pages.count > 1 && sections.containsKey('allgemeine')) {
      _drawTextOnPage(
        doc.pages[1],
        sections['allgemeine']!,
        left: 35, top: 280, width: 525, height: 400,
      );
    }

    // Seite 3: Teilhabeziele
    if (doc.pages.count > 2 && sections.containsKey('ziele')) {
      _drawTextOnPage(
        doc.pages[2],
        sections['ziele']!,
        left: 35, top: 310, width: 525, height: 350,
      );
    }

    // Seite 4: Weitere Anmerkungen
    if (doc.pages.count > 3 && sections.containsKey('anmerkungen')) {
      _drawTextOnPage(
        doc.pages[3],
        sections['anmerkungen']!,
        left: 35, top: 120, width: 525, height: 450,
      );
    }

    // Seite 5: Zusammenfassung
    if (doc.pages.count > 4 && sections.containsKey('zusammenfassung')) {
      _drawTextOnPage(
        doc.pages[4],
        sections['zusammenfassung']!,
        left: 35, top: 100, width: 525, height: 300,
      );
    }

    // Flatten form fields
    form.flattenAllFields();

    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  /// Befüllt den BRP (Ges 100) mit den Berichtsdaten.
  static Future<Uint8List> fillBrp({
    required String generatedText,
    required Map<String, String> metadata,
  }) async {
    final templateBytes = await rootBundle.load(
      'assets/templates/mdb-ges_100_11_v12sp.pdf',
    );
    final doc = PdfDocument(inputBytes: templateBytes.buffer.asUint8List());

    final form = doc.form;
    _trySetField(form, 'Name, Vorname', '${metadata['familienname']}, ${metadata['vorname']}');
    _trySetField(form, 'Straße', metadata['strasse']);
    _trySetField(form, 'Postleitzahl', metadata['plz']);
    _trySetField(form, 'Ort', metadata['ort']);
    _trySetField(form, 'Telefon', metadata['telefon']);

    // Freitextbereiche
    final sections = _parseSections(generatedText);

    // Seite 5 (F): Bericht über bisherige Entwicklung
    if (doc.pages.count > 5 && sections.containsKey('entwicklung')) {
      _drawTextOnPage(
        doc.pages[5],
        sections['entwicklung']!,
        left: 35, top: 130, width: 525, height: 550,
      );
    }

    // Seite 7 (H): Fähigkeiten und Ressourcen
    if (doc.pages.count > 7 && sections.containsKey('faehigkeiten')) {
      _drawTextOnPage(
        doc.pages[7],
        sections['faehigkeiten']!,
        left: 300, top: 80, width: 260, height: 600,
      );
    }

    // Seite 8 (K.I): Ziele Selbstversorgung/Wohnen
    if (doc.pages.count > 8 && sections.containsKey('ziele_wohnen')) {
      _drawTextOnPage(
        doc.pages[8],
        sections['ziele_wohnen']!,
        left: 60, top: 80, width: 500, height: 200,
      );
    }

    form.flattenAllFields();
    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  // --- Hilfsmethoden ---

  static void _trySetField(PdfForm form, String fieldName, String? value) {
    if (value == null || value.isEmpty) return;
    try {
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (field is PdfTextBoxField && field.name?.contains(fieldName) == true) {
          field.text = value;
          return;
        }
      }
    } catch (_) {
      // Feld nicht gefunden – ignorieren
    }
  }

  static void _drawTextOnPage(
    PdfPage page,
    String text, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final format = PdfStringFormat(lineSpacing: 2);

    // Text kürzen falls er nicht in den Bereich passt
    final measured = font.measureString(text,
        layoutArea: Size(width, 0), format: format);

    final displayText = measured.height > height
        ? _truncateToFit(text, font, format, width, height)
        : text;

    page.graphics.drawString(
      displayText,
      font,
      brush: PdfSolidBrush(PdfColor(30, 30, 30)),
      bounds: Rect.fromLTWH(left, top, width, height),
      format: format,
    );
  }

  static String _truncateToFit(
    String text,
    PdfFont font,
    PdfStringFormat format,
    double width,
    double maxHeight,
  ) {
    final lines = text.split('\n');
    final buffer = StringBuffer();

    for (final line in lines) {
      buffer.writeln(line);
      final measured = font.measureString(
        buffer.toString(),
        layoutArea: Size(width, 0),
        format: format,
      );
      if (measured.height > maxHeight - 15) {
        buffer.write('...(Fortsetzung auf nächster Seite)');
        break;
      }
    }

    return buffer.toString();
  }

  static Map<String, String> _parseSections(String text) {
    final sections = <String, String>{};
    final lines = text.split('\n');
    var currentKey = 'allgemeine';
    final buffer = StringBuffer();

    for (final line in lines) {
      final lower = line.toLowerCase();
      String? newKey;

      if (lower.contains('allgemeine information') ||
          lower.contains('tagesstruktur')) {
        newKey = 'allgemeine';
      } else if (lower.contains('teilhabeziel') ||
          lower.contains('zielerreichung')) {
        newKey = 'ziele';
      } else if (lower.contains('anmerkung')) {
        newKey = 'anmerkungen';
      } else if (lower.contains('zusammenfassung') ||
          lower.contains('ausblick')) {
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
}
