import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfImportService {
  /// Öffnet einen Datei-Dialog und extrahiert Text aus einer PDF-Datei.
  /// Gibt `null` zurück wenn der Nutzer abbricht.
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

  /// Extrahiert Text aus PDF-Bytes
  static PdfImportResult extractText(Uint8List bytes, String fileName) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final buffer = StringBuffer();
    final pageCount = document.pages.count;

    for (var i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(startPageIndex: i);
      if (pageText.trim().isNotEmpty) {
        buffer.writeln(pageText.trim());
        buffer.writeln();
      }
    }

    document.dispose();

    return PdfImportResult(
      text: buffer.toString().trim(),
      fileName: fileName,
      pageCount: pageCount,
    );
  }
}

class PdfImportResult {
  final String text;
  final String fileName;
  final int pageCount;

  const PdfImportResult({
    required this.text,
    required this.fileName,
    required this.pageCount,
  });
}
