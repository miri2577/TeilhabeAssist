import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'privacy_policy_text.dart';
import 'signature_store.dart';

final signatureStoreProvider = Provider<SignatureStore>((ref) {
  return SignatureStore();
});

class PrivacySignatureScreen extends ConsumerStatefulWidget {
  const PrivacySignatureScreen({super.key});

  @override
  ConsumerState<PrivacySignatureScreen> createState() =>
      _PrivacySignatureScreenState();
}

class _PrivacySignatureScreenState
    extends ConsumerState<PrivacySignatureScreen> {
  final _nameController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _hasReadPolicy = false;
  bool _hasSigned = false;
  bool _saving = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _signatureController.addListener(_onSignatureChanged);
  }

  void _onSignatureChanged() {
    if (mounted) setState(() => _hasSigned = _signatureController.isNotEmpty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canSign =>
      _hasReadPolicy &&
      _nameController.text.trim().length >= 3 &&
      _hasSigned;

  Future<void> _sign() async {
    if (!_canSign) return;
    setState(() => _saving = true);

    try {
      final signatureImage = await _signatureController.toPngBytes();
      if (signatureImage == null) return;

      final store = ref.read(signatureStoreProvider);
      await store.saveSignature(
        fullName: _nameController.text.trim(),
        signaturePng: signatureImage,
        policyText: kPrivacyPolicyText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datenschutzerklärung unterschrieben und gespeichert'),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ref.watch(signatureStoreProvider);
    final existingSignature = store.currentSignature;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Datenschutzerklärung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Als PDF drucken / exportieren',
            onPressed: () => _printPolicy(context, store),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              // Bestehende Signatur anzeigen
              if (existingSignature != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Unterzeichnet von ${existingSignature.fullName} '
                          'am ${_formatDate(existingSignature.signedAt)}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Policy Text (scrollbar)
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      kPrivacyPolicyText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

              // Signatur-Bereich
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bestätigung gelesen
                    CheckboxListTile(
                      value: _hasReadPolicy,
                      onChanged: (v) =>
                          setState(() => _hasReadPolicy = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Ich habe die Datenschutzerklärung vollständig '
                        'gelesen und verstanden.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      tileColor: _hasReadPolicy
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vollständiger Name (Vor- und Nachname)',
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Signatur-Pad
                    Text('Unterschrift:', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Listener(
                          onPointerUp: (_) {
                            // Signature-Package feuert Listener nicht bei Zeichnen,
                            // daher manuell nach Pointer-Up prüfen
                            Future.delayed(const Duration(milliseconds: 50), () {
                              if (mounted) {
                                setState(() => _hasSigned = _signatureController.isNotEmpty);
                              }
                            });
                          },
                          child: Signature(
                            controller: _signatureController,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _signatureController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Unterschrift löschen'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _canSign && !_saving ? _sign : null,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.draw),
                          label: const Text('Rechtsverbindlich unterschreiben'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} um '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} Uhr';
  }

  void _printPolicy(BuildContext context, SignatureStore store) {
    final signature = store.currentSignature;

    Printing.layoutPdf(
      name: 'Datenschutzerklaerung_TeilhabeAssist.pdf',
      onLayout: (format) async {
        final pdf = pw.Document();
        final lines = kPrivacyPolicyText.split('\n');

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(50),
            footer: (ctx) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TeilhabeAssist – Datenschutzerklärung',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
                pw.Text(
                    'Seite ${ctx.pageNumber} / ${ctx.pagesCount}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
              ],
            ),
            build: (ctx) => [
              for (final line in lines)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    line,
                    style: pw.TextStyle(
                      fontSize: line.startsWith('═') ? 6 : 10,
                      fontWeight: line.startsWith(RegExp(r'\d+\.'))
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      lineSpacing: 3,
                    ),
                  ),
                ),

              // Signatur falls vorhanden
              if (signature != null) ...[
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Unterzeichnet von: ${signature.fullName}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Datum: ${_formatDate(signature.signedAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Policy-Hash: ${signature.policyTextHash.substring(0, 16)}...',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 80,
                  width: 250,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(signature.signatureBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        );

        return pdf.save();
      },
    );
  }
}
