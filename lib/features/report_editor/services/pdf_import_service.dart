import 'dart:io';
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

    return extractText(file.bytes!, file.name, filePath: file.path);
  }

  /// Extrahiert relevanten Text aus PDF-Bytes.
  /// Nutzt pdftotext (poppler) als primäre Methode (bessere Encoding-Unterstützung),
  /// Syncfusion-Formularfelder als Fallback.
  static Future<PdfImportResult> extractText(
    Uint8List bytes,
    String fileName, {
    String? filePath,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;
    document.dispose();

    // 1) pdftotext versuchen (liest auch custom Font-Encodings korrekt)
    final pdftextResult = await _extractWithPdftotext(bytes, filePath,
        firstPage: 6, lastPage: 11);

    if (pdftextResult.isNotEmpty) {
      return PdfImportResult(
        text: pdftextResult.trim(),
        fileName: fileName,
        pageCount: pageCount,
        hasFormFields: true,
      );
    }

    // 2) Fallback: Syncfusion Formularfelder
    final doc2 = PdfDocument(inputBytes: bytes);
    final formText = _extractFormFieldContents(doc2);
    final text = formText.isNotEmpty ? formText : _extractPageText(doc2);
    doc2.dispose();

    return PdfImportResult(
      text: text.trim(),
      fileName: fileName,
      pageCount: pageCount,
      hasFormFields: formText.isNotEmpty,
    );
  }

  /// Extrahiert Text mit pdftotext (poppler).
  /// Gibt leeren String zurück wenn pdftotext nicht verfügbar ist.
  static Future<String> _extractWithPdftotext(
    Uint8List bytes,
    String? filePath, {
    int? firstPage,
    int? lastPage,
  }) async {
    try {
      // Dateipfad ermitteln oder Temp-Datei schreiben
      String pdfPath;
      File? tempFile;

      if (filePath != null && await File(filePath).exists()) {
        pdfPath = filePath;
      } else {
        tempFile = File('${Directory.systemTemp.path}/teilhabe_import_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(bytes);
        pdfPath = tempFile.path;
      }

      try {
        final args = <String>['-layout'];
        if (firstPage != null) args.addAll(['-f', '$firstPage']);
        if (lastPage != null) args.addAll(['-l', '$lastPage']);
        args.addAll([pdfPath, '-']);

        final result = await Process.run('pdftotext', args);

        if (result.exitCode == 0) {
          final text = (result.stdout as String).trim();
          if (text.isNotEmpty) return _cleanPdftotextOutput(text);
        }
      } finally {
        try { await tempFile?.delete(); } catch (_) {}
      }
    } catch (_) {
      // pdftotext nicht installiert oder anderer Fehler
    }
    return '';
  }

  /// Bereinigt pdftotext-Ausgabe: übermäßige Leerzeichen und Formular-Labels entfernen.
  static String _cleanPdftotextOutput(String raw) {
    final lines = raw.split('\n');
    final buffer = StringBuffer();
    var emptyLineCount = 0;

    for (final line in lines) {
      final trimmed = line.trimRight();

      // Leere Zeilen begrenzen (max 2 aufeinander)
      if (trimmed.isEmpty) {
        emptyLineCount++;
        if (emptyLineCount <= 2) buffer.writeln();
        continue;
      }
      emptyLineCount = 0;

      // Übermäßige Leerzeichen innerhalb der Zeile zusammenfassen
      final cleaned = trimmed.replaceAll(RegExp(r' {4,}'), '  ').trimLeft();

      // Sehr kurze Zeilen mit nur Formular-Platzhaltern überspringen
      if (cleaned.length < 3) continue;

      // Seitenreferenz-Zeilen überspringen (z.B. "Ges 100 - Berliner...")
      if (cleaned.startsWith('Ges 100')) continue;
      if (RegExp(r'^\d+\s*$').hasMatch(cleaned)) continue; // Seitenzahlen

      buffer.writeln(cleaned);
    }

    return buffer.toString().trim();
  }

  /// Fallback: Syncfusion Formularfelder von Seite 5-11 extrahieren.
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

        int pageIndex = -1;
        try {
          final page = field.page;
          if (page != null && pageMap.containsKey(page)) {
            pageIndex = pageMap[page]!;
          }
        } catch (_) {
          continue;
        }

        if (pageIndex < 4 || pageIndex > 10) continue;

        final clean = _cleanFieldText(field.text.trim());
        if (clean.isEmpty) continue;
        if (clean.length <= 3 && RegExp(r'^[\d\s\./ ]+$').hasMatch(clean)) continue;

        pageFields.putIfAbsent(pageIndex, () => []);
        pageFields[pageIndex]!.add(clean);
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

  /// Bereinigt Feldtext von Binärdaten (Syncfusion-Fallback).
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

    final clean = raw.substring(0, cutPoint)
        .replaceAll(RegExp(r'[^\x20-\x7EäöüÄÖÜß\n\r\t–—…€§°]'), ' ')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (raw.length > 20 && clean.length < 10) return '';
    return clean;
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
