import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart' as pdf show PdfFieldFlags;
import 'package:pdf/widgets.dart' as pw;

String _two(int n) => n.toString().padLeft(2, '0');

String _formatNow() {
  final n = DateTime.now();
  return '${_two(n.day)}.${_two(n.month)}.${n.year} '
      '${_two(n.hour)}:${_two(n.minute)}';
}

/// Design-System für PDF-Berichte.
/// Übernommen aus der FEGH-Dokumentations-App (hybrider Stil: behördlicher
/// Header/Footer, moderne Hero-Sektion und KPI-Bausteine).
class PdfDesignTokens {
  PdfDesignTokens._();

  static const PdfColor primaer = PdfColor.fromInt(0xFF1E3A5F);    // dunkles Behörden-Blau
  static const PdfColor text = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor divider = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor accent = PdfColor.fromInt(0xFF0F766E);     // Teal für Positiv
  static const PdfColor warn = PdfColor.fromInt(0xFFB91C1C);       // Rot
  static const PdfColor tableHeader = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor heroBackground = PdfColor.fromInt(0xFFF9FAFB);
}

class PdfKpi {
  const PdfKpi({
    required this.label,
    required this.value,
    this.color = PdfDesignTokens.text,
    this.hero = false,
  });

  final String label;
  final String value;
  final PdfColor color;
  final bool hero;
}

/// Behördlicher Kopf: Träger-/Appname links, Berichtstyp + Aktenzeichen rechts,
/// abgeschlossen durch eine 2 pt Trennlinie in `primaer`.
///
/// Wenn `logo` gesetzt ist (PNG/JPG-Bytes), wird es links vor dem Text
/// angezeigt — damit hat jeder Träger sein eigenes Logo im PDF.
pw.Widget buildHeader({
  required String title,
  String appName = 'TeilhabeAssist',
  String appTagline = 'Eingliederungshilfe nach SGB IX',
  String? aktenzeichen,
  pw.ImageProvider? logo,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfDesignTokens.primaer, width: 2),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.SizedBox(
                height: 36,
                width: 42,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  appName,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfDesignTokens.primaer,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  appTagline,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfDesignTokens.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfDesignTokens.muted,
                letterSpacing: 2,
              ),
            ),
            if (aktenzeichen != null && aktenzeichen.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'AZ: $aktenzeichen',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfDesignTokens.muted,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

pw.Widget buildFooter(pw.Context ctx, {String appName = 'TeilhabeAssist'}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfDesignTokens.divider, width: 0.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Erstellt ${_formatNow()}',
          style: const pw.TextStyle(fontSize: 8, color: PdfDesignTokens.muted),
        ),
        pw.Text(
          appName,
          style: const pw.TextStyle(fontSize: 8, color: PdfDesignTokens.muted),
        ),
        pw.Text(
          'Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfDesignTokens.muted),
        ),
      ],
    ),
  );
}

/// Moderne Hero-Sektion: kleines Label, großer Titel, Subtitle.
pw.Widget buildHero({
  required String label,
  required String title,
  String? subtitle,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: const pw.TextStyle(
          fontSize: 9,
          color: PdfDesignTokens.muted,
          letterSpacing: 2,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 28,
          fontWeight: pw.FontWeight.bold,
          color: PdfDesignTokens.primaer,
        ),
      ),
      if (subtitle != null && subtitle.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfDesignTokens.muted,
          ),
        ),
      ],
    ],
  );
}

/// KPI-Reihe in einer abgerundeten Karte mit dünnen Trennern.
pw.Widget buildKpiRow(List<PdfKpi> kpis) {
  if (kpis.isEmpty) return pw.SizedBox.shrink();

  final widgets = <pw.Widget>[];
  for (var i = 0; i < kpis.length; i++) {
    widgets.add(_buildKpi(kpis[i]));
    if (i < kpis.length - 1) widgets.add(_buildKpiDivider());
  }

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    decoration: pw.BoxDecoration(
      color: PdfDesignTokens.tableHeader,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfDesignTokens.divider),
    ),
    child: pw.Row(children: widgets),
  );
}

pw.Widget _buildKpi(PdfKpi kpi) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          kpi.label,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfDesignTokens.muted,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          kpi.value,
          style: pw.TextStyle(
            fontSize: kpi.hero ? 18 : 14,
            fontWeight: pw.FontWeight.bold,
            color: kpi.color,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildKpiDivider() => pw.Container(
      height: 32,
      width: 0.5,
      color: PdfDesignTokens.divider,
      margin: const pw.EdgeInsets.symmetric(horizontal: 16),
    );

/// Abschnitts-Überschrift im FEGH-Stil: Nummer in Blau-Box + Titel.
pw.Widget buildSectionHeading(String number, String title) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: PdfDesignTokens.primaer,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          number,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
    ],
  );
}

/// Schlüssel-Wert-Liste, z.B. für Personendaten oder Berichts-Kopfdaten.
pw.Widget buildKeyValueTable(List<({String label, String value})> entries) {
  final rows = <pw.TableRow>[];
  for (final e in entries) {
    rows.add(pw.TableRow(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: PdfDesignTokens.tableHeader,
        child: pw.Text(
          e.label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          e.value.isEmpty ? '—' : e.value,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
    ]));
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfDesignTokens.divider, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(3),
    },
    children: rows,
  );
}

/// Unterschriften-Bereich mit zwei oder drei Spalten.
pw.Widget buildSignatureRow({
  String? authorName,
  bool includeTeamLead = false,
}) {
  pw.Widget column(String label) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 40,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfDesignTokens.text,
                  width: 0.8,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfDesignTokens.muted,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Row(
    children: [
      column('Ort, Datum'),
      pw.SizedBox(width: 32),
      column(authorName != null && authorName.isNotEmpty
          ? 'Unterschrift $authorName'
          : 'Unterschrift Fachkraft'),
      if (includeTeamLead) ...[
        pw.SizedBox(width: 32),
        column('Unterschrift Teamleitung'),
      ],
    ],
  );
}

/// Leerzustand-Hinweis (zeitarme oder leere Sektionen).
pw.Widget buildEmptyState(String message) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: PdfDesignTokens.heroBackground,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: PdfDesignTokens.divider),
    ),
    alignment: pw.Alignment.center,
    child: pw.Text(
      message,
      style: pw.TextStyle(
        fontSize: 10,
        color: PdfDesignTokens.muted,
        fontStyle: pw.FontStyle.italic,
      ),
    ),
  );
}

/// Editierbares Multi-Line-Textfeld im FEGH-Layout-Stil.
/// Im PDF erscheint ein AcroForm-Feld; die Fachkraft kann den Inhalt im
/// PDF-Reader anpassen, bevor sie unterschreibt.
///
/// Wichtig: Sowohl `value` als auch `defaultValue` werden gesetzt. Manche
/// PDF-Reader (insbesondere Adobe Acrobat) zeigen nur `value` beim Öffnen
/// an. `defaultValue` allein bleibt sonst unsichtbar bis der User klickt.
pw.Widget buildEditableBlock({
  required String name,
  required String defaultValue,
  double minHeight = 60,
  double? maxHeight,
}) {
  final t = defaultValue.trim();
  // Höhe eng an Inhalt anpassen, damit kein Leerraum im PDF entsteht.
  //   • Zeile bei 10.5 pt + lineSpacing 3 ≈ 14.5 pt
  //   • bei A4-Seitenbreite minus Margins passen ~70 Zeichen pro Zeile.
  //   • explizite `\n` als feste Zeilenumbrüche zählen.
  //   • Kein zusätzlicher Sicherheits-Multiplier — der Acrobat Reader
  //     scrollt das TextField intern, falls der Inhalt minimal überlauft.
  final explicitBreaks = '\n'.allMatches(t).length;
  final wrappedLines = (t.length / 70).ceil();
  final rawLines = wrappedLines + explicitBreaks;
  final lines = rawLines.clamp(t.isEmpty ? 2 : 3, 200);
  final height = (lines * 14.5 + 10).clamp(minHeight, maxHeight ?? 680.0);
  return pw.Container(
    width: double.infinity,
    height: height,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfDesignTokens.divider, width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.TextField(
      name: name,
      value: t,
      defaultValue: t,
      fieldFlags: const {pdf.PdfFieldFlags.multiline},
      textStyle: pw.TextStyle(
        fontSize: 10.5,
        lineSpacing: 3,
        color: PdfDesignTokens.text,
      ),
    ),
  );
}

/// Editierbares Single-Line-Feld für die Personendaten-Tabelle.
pw.Widget buildEditableInline({
  required String name,
  required String defaultValue,
}) {
  final t = defaultValue.trim();
  return pw.Container(
    height: 18,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: pw.TextField(
      name: name,
      value: t,
      defaultValue: t,
      textStyle: pw.TextStyle(fontSize: 10, color: PdfDesignTokens.text),
    ),
  );
}

/// Variante von `buildEditableKeyValueTable`, deren Wert-Zellen multiline
/// sind und ihre Höhe an die Textlänge anpassen.
///
/// Die Werte-Spalte ist ca. 70 % der Seitenbreite. Bei 10.5 pt Schrift
/// passen dort ungefähr 40 Zeichen pro Zeile — diese Schätzung wird zur
/// Zellenhöhe verrechnet. So werden lange Leitziele oder Indikatoren
/// nicht mehr nach der ersten Zeile abgeschnitten.
pw.Widget buildEditableMultilineKeyValueTable(
  List<({String label, String fieldName, String value, double minHeight})>
      entries,
) {
  final rows = <pw.TableRow>[];
  for (final e in entries) {
    final value = e.value.trim();
    final explicitBreaks = '\n'.allMatches(value).length;
    final wrapped = (value.length / 50).ceil();
    final lines = (wrapped + explicitBreaks).clamp(value.isEmpty ? 1 : 1, 30);
    final h = (lines * 14.5 + 8).clamp(e.minHeight, 360.0);

    rows.add(pw.TableRow(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: PdfDesignTokens.tableHeader,
        child: pw.Text(
          e.label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
      pw.Container(
        height: h,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.TextField(
          name: e.fieldName,
          value: value,
          defaultValue: value,
          fieldFlags: const {pdf.PdfFieldFlags.multiline},
          textStyle: pw.TextStyle(
            fontSize: 10,
            lineSpacing: 3,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
    ]));
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfDesignTokens.divider, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(3),
    },
    children: rows,
  );
}

/// Variante von `buildKeyValueTable`, deren Werte editierbar sind.
pw.Widget buildEditableKeyValueTable(
  List<({String label, String fieldName, String value})> entries,
) {
  final rows = <pw.TableRow>[];
  for (final e in entries) {
    rows.add(pw.TableRow(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: PdfDesignTokens.tableHeader,
        child: pw.Text(
          e.label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfDesignTokens.text,
          ),
        ),
      ),
      buildEditableInline(name: e.fieldName, defaultValue: e.value),
    ]));
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfDesignTokens.divider, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(3),
    },
    children: rows,
  );
}

/// Sicheres Rendern langer Fließtexte mit Markdown-light:
/// - `## Heading` und `# Heading` werden als Section-Titel gerendert
/// - `**bold**` wird zu fettem Inline-Text
/// - Aufzählungspunkte mit `- ` oder `• ` werden mit Bullet gerendert
List<pw.Widget> buildBody(String text) {
  final widgets = <pw.Widget>[];
  final paragraphs = text.split(RegExp(r'\n\s*\n'));

  for (final para in paragraphs) {
    final trimmed = para.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('## ')) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        trimmed.substring(3).trim(),
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfDesignTokens.primaer,
        ),
      ));
      widgets.add(pw.SizedBox(height: 6));
      continue;
    }
    if (trimmed.startsWith('# ')) {
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(pw.Text(
        trimmed.substring(2).trim(),
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfDesignTokens.primaer,
        ),
      ));
      widgets.add(pw.SizedBox(height: 8));
      continue;
    }

    // Aufzählungs-Block?
    final lines = trimmed.split('\n');
    final allBulleted = lines.every(
      (l) => l.trimLeft().startsWith('- ') || l.trimLeft().startsWith('• '),
    );

    if (lines.length > 1 && allBulleted) {
      for (final line in lines) {
        widgets.add(_buildBulletLine(line.trimLeft().substring(2)));
      }
      widgets.add(pw.SizedBox(height: 6));
      continue;
    }

    widgets.add(_buildRichText(trimmed));
    widgets.add(pw.SizedBox(height: 6));
  }

  return widgets;
}

pw.Widget _buildBulletLine(String line) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 4, bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '•  ',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfDesignTokens.primaer,
          ),
        ),
        pw.Expanded(child: _buildRichText(line)),
      ],
    ),
  );
}

pw.Widget _buildRichText(String text) {
  // **bold** wird zu fettem Inline-Text
  final spans = <pw.InlineSpan>[];
  final regex = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(pw.TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(pw.TextSpan(
      text: match.group(1),
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(pw.TextSpan(text: text.substring(cursor)));
  }

  return pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(
        fontSize: 10.5,
        lineSpacing: 3,
        color: PdfDesignTokens.text,
      ),
      children: spans,
    ),
  );
}
