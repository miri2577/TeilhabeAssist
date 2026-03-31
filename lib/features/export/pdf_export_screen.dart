import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../report_editor/providers/report_providers.dart';
import 'feedback_dialog.dart';

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key});

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
  bool _feedbackShown = false;

  void _showFeedback() {
    if (_feedbackShown) return;
    _feedbackShown = true;
    // Zeige Feedback-Dialog nach kurzem Delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => const FeedbackDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final draft = ref.watch(reportDraftNotifierProvider);
    _showFeedback();

    if (draft == null || draft.generatedText == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/editor'),
          ),
          title: const Text('PDF Export'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Kein generierter Bericht vorhanden.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/editor'),
                child: const Text('Zurück zum Editor'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/editor'),
        ),
        title: const Text('PDF Export'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/editor'),
            tooltip: 'Zurück zum Editor',
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(draft.generatedText!, draft.type.label),
        pdfFileName:
            'Informationsbericht_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
      ),
    );
  }

  Future<Uint8List> _buildPdf(String text, String reportType) async {
    final pdf = pw.Document();

    final paragraphs = text.split('\n\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              reportType,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Erstellt mit TeilhabeAssist',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.Text(
              'Seite ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
        build: (context) => [
          for (final paragraph in paragraphs)
            if (paragraph.trim().isNotEmpty)
              _buildParagraph(paragraph.trim()),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildParagraph(String text) {
    // Überschriften erkennen
    if (text.startsWith('# ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
        child: pw.Text(
          text.substring(2),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      );
    }
    if (text.startsWith('## ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(
          text.substring(3),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );
    }
    if (text.startsWith('### ')) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(
          text.substring(4),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    // Normaler Text
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
      ),
    );
  }
}
