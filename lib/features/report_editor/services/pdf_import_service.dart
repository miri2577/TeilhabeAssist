import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

    return extractText(file.bytes!, file.name);
  }

  /// Extrahiert relevanten Text aus PDF-Bytes.
  /// Bei Berliner Vorlagen (BRP, Informationsbericht) werden die
  /// Formularfeld-Inhalte von Seite 5-11 extrahiert.
  /// Bei normalen PDFs wird der Seitentext extrahiert.
  static PdfImportResult extractText(Uint8List bytes, String fileName) {
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;

    // Formularfelder von Seite 5-11 extrahieren (nur Textinhalte)
    final formText = _extractFormFieldContents(document);

    // Fallback: Seitentext wenn keine Formularfelder
    final text = formText.isNotEmpty
        ? formText
        : _extractPageText(document);

    document.dispose();

    return PdfImportResult(
      text: text.trim(),
      fileName: fileName,
      pageCount: pageCount,
      hasFormFields: formText.isNotEmpty,
    );
  }

  /// Extrahiert nur die Textinhalte der Formularfelder von Seite 5-11.
  /// Gibt den reinen Inhalt zurück, ohne Feldnamen.
  static String _extractFormFieldContents(PdfDocument document) {
    try {
      final form = document.form;
      if (form.fields.count == 0) return '';

      // Seitenindex → PdfPage Mapping aufbauen
      final pageMap = <PdfPage, int>{};
      for (var p = 0; p < document.pages.count; p++) {
        pageMap[document.pages[p]] = p;
      }

      // Felder nach Seite gruppiert sammeln (nur Seite 5-11 = Index 4-10)
      final pageFields = <int, List<String>>{};

      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (field is! PdfTextBoxField) continue;
        if (field.text.trim().isEmpty) continue;

        // Seitenzuordnung ermitteln
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

        // Reine Nummerierungen und Kurzkürzel überspringen
        final text = field.text.trim();
        if (text.length <= 3 && RegExp(r'^[\d\s\./ ]+$').hasMatch(text)) continue;

        pageFields.putIfAbsent(pageIndex, () => []);
        pageFields[pageIndex]!.add(text);
      }

      if (pageFields.isEmpty) return '';

      // Inhalte seitenweise zusammenfügen
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

  /// Extrahiert statischen Seitentext (Fallback).
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
