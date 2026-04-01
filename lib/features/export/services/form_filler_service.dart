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
    final ByteData templateBytes;
    try {
      templateBytes = await rootBundle.load(
        'assets/templates/informationsbericht_101.pdf',
      );
    } catch (e) {
      throw Exception(
          'PDF-Vorlage "informationsbericht_101.pdf" konnte nicht geladen werden. '
          'Bitte prüfen Sie, ob die Datei unter assets/templates/ vorhanden ist.');
    }

    final doc = PdfDocument(inputBytes: templateBytes.buffer.asUint8List());

    // Formularfelder befüllen (falls vorhanden)
    _tryFillForm(doc, {
      'ID Kostenübernahme': metadata['id_kostenuebernahme'],
      'Berichtszeitraum von': metadata['berichtszeitraum_von'],
      'Berichtszeitraum bis': metadata['berichtszeitraum_bis'],
      'Leistungstyp': metadata['leistungstyp'],
      'Leistungserbringer': metadata['leistungserbringer'],
      'Familienname': metadata['familienname'],
      'Vorname': metadata['vorname'],
      'Geburtsdatum': metadata['geburtsdatum'],
    });

    // Fließtext in die Freitextbereiche schreiben
    final sections = _parseSections(generatedText);

    _tryDrawSection(doc, 1, sections['allgemeine'],
        left: 35, top: 280, width: 525, height: 400);
    _tryDrawSection(doc, 2, sections['ziele'],
        left: 35, top: 310, width: 525, height: 350);
    _tryDrawSection(doc, 3, sections['anmerkungen'],
        left: 35, top: 120, width: 525, height: 450);
    _tryDrawSection(doc, 4, sections['zusammenfassung'],
        left: 35, top: 100, width: 525, height: 300);

    _tryFlattenForm(doc);

    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  /// Befüllt den BRP (Ges 100) mit den Berichtsdaten.
  static Future<Uint8List> fillBrp({
    required String generatedText,
    required Map<String, String> metadata,
  }) async {
    final ByteData templateBytes;
    try {
      templateBytes = await rootBundle.load(
        'assets/templates/mdb-ges_100_11_v12sp.pdf',
      );
    } catch (e) {
      throw Exception(
          'PDF-Vorlage "mdb-ges_100_11_v12sp.pdf" konnte nicht geladen werden. '
          'Bitte prüfen Sie, ob die Datei unter assets/templates/ vorhanden ist.');
    }

    final doc = PdfDocument(inputBytes: templateBytes.buffer.asUint8List());

    final name = [metadata['familienname'], metadata['vorname']]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    _tryFillForm(doc, {
      'Name, Vorname': name.isNotEmpty ? name : null,
      'Straße': metadata['strasse'],
      'Postleitzahl': metadata['plz'],
      'Ort': metadata['ort'],
      'Telefon': metadata['telefon'],
    });

    final sections = _parseSections(generatedText);

    _tryDrawSection(doc, 5, sections['entwicklung'],
        left: 35, top: 130, width: 525, height: 550);
    _tryDrawSection(doc, 7, sections['faehigkeiten'],
        left: 300, top: 80, width: 260, height: 600);
    _tryDrawSection(doc, 8, sections['ziele_wohnen'],
        left: 60, top: 80, width: 500, height: 200);

    _tryFlattenForm(doc);

    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();
    return bytes;
  }

  // --- Hilfsmethoden ---

  /// Versucht Formularfelder zu befüllen. Ignoriert Fehler komplett,
  /// da viele PDFs keine AcroForm-Felder haben.
  static void _tryFillForm(PdfDocument doc, Map<String, String?> fields) {
    try {
      final form = doc.form;
      for (final entry in fields.entries) {
        _trySetField(form, entry.key, entry.value);
      }
    } catch (_) {
      // PDF hat keine AcroForm-Felder – nur Freitext einfügen
    }
  }

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
    } catch (_) {}
  }

  /// Versucht Text auf eine bestimmte Seite zu schreiben.
  /// Prüft Seitenzahl und ob Text vorhanden ist.
  static void _tryDrawSection(
    PdfDocument doc,
    int pageIndex,
    String? text, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    if (text == null || text.trim().isEmpty) return;
    if (doc.pages.count <= pageIndex) return;

    try {
      _drawTextOnPage(doc.pages[pageIndex], text,
          left: left, top: top, width: width, height: height);
    } catch (_) {
      // Zeichenfehler auf Seite ignorieren – besser leere Seite als Crash
    }
  }

  static void _tryFlattenForm(PdfDocument doc) {
    try {
      doc.form.flattenAllFields();
    } catch (_) {}
  }

  static void _drawTextOnPage(
    PdfPage page,
    String text, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    // Markdown-Syntax entfernen für saubere PDF-Ausgabe
    final cleanText = text
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');

    final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final format = PdfStringFormat(lineSpacing: 2);

    final measured = font.measureString(cleanText,
        layoutArea: Size(width, 0), format: format);

    final displayText = measured.height > height
        ? _truncateToFit(cleanText, font, format, width, height)
        : cleanText;

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
