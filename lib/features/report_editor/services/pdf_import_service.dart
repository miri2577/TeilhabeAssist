import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/forms/pdf_field.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_name.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_reference_holder.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_stream.dart';

class PdfImportService {
  /// Öffnet einen Datei-Dialog und extrahiert Text aus einer PDF-Datei.
  static Future<PdfImportResult?> pickAndExtract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;

    return extractText(file.bytes!, file.name, filePath: file.path);
  }

  /// Extrahiert relevanten Text aus PDF-Bytes.
  /// Nutzt den Appearance-Stream der Formularfelder (plattformübergreifend),
  /// mit Syncfusion field.text und pdftotext als Fallbacks.
  static Future<PdfImportResult> extractText(
    Uint8List bytes,
    String fileName, {
    String? filePath,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;

    // Formularfelder von Seite 5-11 extrahieren
    final formText = _extractFormFieldContents(document);

    // Fallback: Seitentext wenn keine Formularfelder
    final text = formText.isNotEmpty ? formText : _extractPageText(document);

    document.dispose();

    return PdfImportResult(
      text: text.trim(),
      fileName: fileName,
      pageCount: pageCount,
      hasFormFields: formText.isNotEmpty,
    );
  }

  /// Extrahiert Textinhalte der Formularfelder von Seite 5-11.
  /// Nutzt den Appearance-Stream (/AP/N) als primäre Quelle,
  /// field.text als Fallback.
  static String _extractFormFieldContents(PdfDocument document) {
    try {
      final form = document.form;
      if (form.fields.count == 0) return '';

      final pageMap = <PdfPage, int>{};
      for (var p = 0; p < document.pages.count; p++) {
        pageMap[document.pages[p]] = p;
      }

      final pageFields = <int, List<String>>{};

      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (field is! PdfTextBoxField) continue;
        if (field.text.trim().isEmpty) continue;

        // Seitenzuordnung
        int pageIndex = -1;
        try {
          final page = field.page;
          if (page != null && pageMap.containsKey(page)) {
            pageIndex = pageMap[page]!;
          }
        } catch (_) {
          continue;
        }

        // Nur Seite 5-11 (Index 4-10)
        if (pageIndex < 4 || pageIndex > 10) continue;

        // Text extrahieren: zuerst Appearance-Stream, dann field.text
        var text = _extractFromAppearanceStream(field);
        text ??= _cleanFieldText(field.text.trim());
        if (text.isEmpty) continue;

        // Kurze Nummerierungen überspringen
        if (text.length <= 3 && RegExp(r'^[\d\s\./ ]+$').hasMatch(text)) continue;

        pageFields.putIfAbsent(pageIndex, () => []);
        pageFields[pageIndex]!.add(text);
      }

      if (pageFields.isEmpty) return '';

      final buffer = StringBuffer();
      final sortedPages = pageFields.keys.toList()..sort();
      for (final page in sortedPages) {
        for (final content in pageFields[page]!) {
          buffer.writeln(content);
          buffer.writeln();
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Extrahiert Text aus dem Appearance-Stream (/AP/N) eines Feldes.
  /// Parst PDF-Textoperatoren (text) Tj aus dem dekomprimierten Stream.
  /// Gibt null zurück wenn kein AP-Stream vorhanden.
  static String? _extractFromAppearanceStream(PdfTextBoxField field) {
    try {
      final helper = PdfFieldHelper.getHelper(field);
      final dict = helper.dictionary;
      if (dict == null) return null;

      final ap = dict[PdfName('AP')];
      if (ap is! PdfDictionary) return null;

      var n = ap[PdfName('N')];
      if (n is PdfReferenceHolder) n = n.object;
      if (n is! PdfStream) return null;

      n.decompress();
      final data = n.dataStream;
      if (data == null || data.isEmpty) return null;

      final streamText = latin1.decode(Uint8List.fromList(data));

      // PDF-Textoperatoren parsen: (text) Tj
      final buffer = StringBuffer();
      final tjPattern = RegExp(r'\(([^)]*)\)\s*Tj');
      // Td-Operatoren für Zeilenumbrüche tracken
      final lines = streamText.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();

        // Td-Operator: x y Td (Textposition)
        final tdMatch = RegExp(r'([-\d.]+)\s+([-\d.]+)\s+Td').firstMatch(trimmed);
        if (tdMatch != null) {
          final y = double.tryParse(tdMatch.group(2)!) ?? 0;
          // Negativer Y-Wert = neue Zeile
          if (y < -1) {
            buffer.write('\n');
          }
        }

        // Tj-Operator: (text) Tj
        final matches = tjPattern.allMatches(trimmed);
        for (final match in matches) {
          var text = match.group(1)!;
          // PDF-Escapes dekodieren
          text = _decodePdfString(text);
          buffer.write(text);
        }
      }

      final result = buffer.toString().trim();
      return result.length > 5 ? result : null;
    } catch (_) {
      return null;
    }
  }

  /// Dekodiert PDF-String-Escapes wie \374 (oktal) → ü
  static String _decodePdfString(String raw) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < raw.length) {
      if (raw[i] == '\\' && i + 1 < raw.length) {
        final next = raw[i + 1];
        if (next == 'n') {
          buffer.write('\n');
          i += 2;
        } else if (next == 'r') {
          buffer.write('\r');
          i += 2;
        } else if (next == 't') {
          buffer.write('\t');
          i += 2;
        } else if (next == '(' || next == ')' || next == '\\') {
          buffer.write(next);
          i += 2;
        } else if (next.codeUnitAt(0) >= 0x30 && next.codeUnitAt(0) <= 0x37) {
          // Oktal-Escape: \NNN
          var octal = '';
          var j = i + 1;
          while (j < raw.length &&
              j < i + 4 &&
              raw[j].codeUnitAt(0) >= 0x30 &&
              raw[j].codeUnitAt(0) <= 0x37) {
            octal += raw[j];
            j++;
          }
          final charCode = int.parse(octal, radix: 8);
          buffer.writeCharCode(charCode);
          i = j;
        } else {
          buffer.write(next);
          i += 2;
        }
      } else {
        buffer.write(raw[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// Bereinigt field.text von Binärdaten (Fallback).
  static String _cleanFieldText(String raw) {
    final allowed = RegExp(
      r'[a-zA-ZäöüÄÖÜß0-9\s\.,;:!\?\-\(\)\[\]/&%€@\+\*#"' "'" r'°§–—…]',
    );

    int cutPoint = raw.length;
    for (var i = 0; i < raw.length - 10; i++) {
      var badCount = 0;
      for (var j = i; j < i + 10 && j < raw.length; j++) {
        if (!allowed.hasMatch(raw[j])) badCount++;
      }
      if (badCount > 5) {
        cutPoint = i;
        break;
      }
    }

    final clean = raw
        .substring(0, cutPoint)
        .replaceAll(RegExp(r'[^\x20-\x7EäöüÄÖÜß\n\r\t–—…€§°]'), ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (raw.length > 20 && clean.length < 10) return '';
    return clean;
  }

  /// Extrahiert statischen Seitentext (Fallback für PDFs ohne Formularfelder).
  static String _extractPageText(PdfDocument document) {
    try {
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText.trim());
          buffer.writeln();
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }
}

class PdfImportResult {
  final String text;
  final String fileName;
  final int pageCount;
  final bool hasFormFields;

  const PdfImportResult({
    required this.text,
    required this.fileName,
    required this.pageCount,
    this.hasFormFields = false,
  });
}
