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

  /// Extrahiert Text aus PDF-Bytes.
  /// Kombiniert Formularfeld-Werte UND statischen Seitentext.
  /// Formularfelder haben Priorität, da dort die eigentlichen Daten stehen.
  static PdfImportResult extractText(Uint8List bytes, String fileName) {
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;

    // 1) Formularfelder auslesen (Hauptdatenquelle bei Berliner Vorlagen)
    final formFields = _extractFormFields(document);

    // 2) Statischen Seitentext als Fallback extrahieren
    final pageText = _extractPageText(document);

    // 3) Kombinierten Text erstellen
    final combined = StringBuffer();

    if (formFields.isNotEmpty) {
      combined.writeln(formFields);
      if (pageText.isNotEmpty) {
        combined.writeln('\n--- Seitentext ---\n');
        combined.writeln(pageText);
      }
    } else {
      combined.writeln(pageText);
    }

    document.dispose();

    return PdfImportResult(
      text: combined.toString().trim(),
      fileName: fileName,
      pageCount: pageCount,
      hasFormFields: formFields.isNotEmpty,
    );
  }

  /// Extrahiert alle Formularfeld-Werte als strukturierten Text.
  /// Gruppiert nach inhaltlichen Bereichen des BRP / Informationsberichts.
  static String _extractFormFields(PdfDocument document) {
    try {
      final form = document.form;
      if (form.fields.count == 0) return '';

      final fields = <String, String>{};
      final checkboxes = <String, bool>{};

      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        final name = field.name;
        if (name == null || name.isEmpty) continue;

        if (field is PdfTextBoxField && field.text.isNotEmpty) {
          fields[name] = field.text;
        } else if (field is PdfCheckBoxField && field.isChecked) {
          checkboxes[name] = true;
        }
      }

      if (fields.isEmpty && checkboxes.isEmpty) return '';

      // Strukturierten Text aus den Feldern aufbauen
      final buffer = StringBuffer();

      // Persondaten
      _appendSection(buffer, 'Persondaten', {
        if (fields.containsKey('NameVorname'))
          'Name, Vorname': fields['NameVorname']!,
        if (fields.containsKey('KopieNameVorname') && !fields.containsKey('NameVorname'))
          'Name, Vorname': fields['KopieNameVorname']!,
        if (fields.containsKey('Straße'))
          'Straße': fields['Straße']!,
        if (fields.containsKey('Postleitzahl'))
          'PLZ': fields['Postleitzahl']!,
        if (fields.containsKey('Ort'))
          'Ort': fields['Ort']!,
        if (fields.containsKey('Telefon'))
          'Telefon': fields['Telefon']!,
        if (fields.containsKey('geboren am'))
          'Geburtsdatum': fields['geboren am']!,
        if (fields.containsKey('Geburtsort'))
          'Geburtsort': fields['Geburtsort']!,
        if (fields.containsKey('Krankenkasse'))
          'Krankenkasse': fields['Krankenkasse']!,
        if (fields.containsKey('Mitgliedsnummer'))
          'Mitgliedsnummer': fields['Mitgliedsnummer']!,
        if (fields.containsKey('rechtl Betreuer'))
          'Rechtl. Betreuer': fields['rechtl Betreuer']!,
        if (fields.containsKey('Wirkungskreis'))
          'Wirkungskreis': fields['Wirkungskreis']!,
      });

      // Plandaten
      _appendSection(buffer, 'Plandaten', {
        if (fields.containsKey('Planvom'))
          'Plan vom': fields['Planvom']!,
        if (fields.containsKey('Planvombis'))
          'Plan bis': fields['Planvombis']!,
        if (fields.containsKey('EinrichtungDienst'))
          'Einrichtung/Dienst': fields['EinrichtungDienst']!,
        if (fields.containsKey('Bezirksamt 1'))
          'Bezirksamt': fields['Bezirksamt 1']!,
        if (fields.containsKey('ICD-10-Schluessel'))
          'ICD-10': fields['ICD-10-Schluessel']!,
        if (fields.containsKey('BeantragteMaßnahme'))
          'Beantragte Maßnahme': fields['BeantragteMaßnahme']!,
      });

      // Diagnosen / Medikamente
      _appendSection(buffer, 'Diagnosen und Behandlung', {
        if (fields.containsKey('D5Text1'))
          'Diagnosen': fields['D5Text1']!,
        if (fields.containsKey('DText2'))
          'ICD-10 Diagnose': fields['DText2']!,
        if (fields.containsKey('D3Text2'))
          'Medikation': fields['D3Text2']!,
      });

      // Ausbildung / Beruf
      _appendSection(buffer, 'Ausbildung und Beruf', {
        if (fields.containsKey('B1Text1'))
          'Schulabschluss': fields['B1Text1']!,
        if (fields.containsKey('B2Text1'))
          'Berufsausbildung': fields['B2Text1']!,
        if (fields.containsKey('B5Text'))
          'GdB': '${fields['B5Text']}%',
        if (fields.containsKey('B6Text'))
          'Berufliche Maßnahmen': fields['B6Text']!,
      });

      // Soziale Kontakte / Interessen
      _appendSection(buffer, 'Soziale Kontakte und Interessen', {
        if (fields.containsKey('E1Text'))
          'Interessen/Hobbys': fields['E1Text']!,
        if (fields.containsKey('E2Text'))
          'Betreuungssetting': fields['E2Text']!,
        if (fields.containsKey('Religionsgem'))
          'Soziale Kontakte': fields['Religionsgem']!,
        if (fields.containsKey('Falls ja in welcher Form'))
          'Kontaktform': fields['Falls ja in welcher Form']!,
      });

      // Lebenssituation
      _appendSection(buffer, 'Lebenssituation', {
        if (fields.containsKey('TextA71'))
          'Lebenssituation': fields['TextA71']!,
      });

      // Bericht / Entwicklung (Freitextfelder)
      _appendSection(buffer, 'Bericht über bisherige Entwicklung', {
        if (fields.containsKey('BerichtText1'))
          'Entwicklungsbericht': fields['BerichtText1']!,
        if (fields.containsKey('Freier Text_2'))
          'Weitere Informationen': fields['Freier Text_2']!,
      });

      // Fähigkeiten und Ressourcen
      _appendSection(buffer, 'Fähigkeiten und Ressourcen', {
        if (fields.containsKey('HText'))
          'Fähigkeiten': fields['HText']!,
      });

      // Ziele und Maßnahmen
      final zieleBuffer = StringBuffer();
      for (var i = 1; i <= 4; i++) {
        final zielKey = 'Ziele$i';
        final indKey = 'Indikatoren$i';
        final vorKey = 'Vorgehen$i';
        if (fields.containsKey(zielKey)) {
          zieleBuffer.writeln('Ziel $i: ${fields[zielKey]}');
          if (fields.containsKey(indKey)) {
            zieleBuffer.writeln('Indikatoren: ${fields[indKey]}');
          }
          if (fields.containsKey(vorKey)) {
            zieleBuffer.writeln('Vorgehen: ${fields[vorKey]}');
          }
          zieleBuffer.writeln();
        }
      }

      // Ziele aus anderen Feldnamen
      _appendFieldIfExists(zieleBuffer, fields, 'Fortsetzung_2', 'Weiteres Ziel');
      _appendFieldIfExists(zieleBuffer, fields, 'Indikatoren zu III', 'Indikatoren III');
      _appendFieldIfExists(zieleBuffer, fields, 'Vorgehen zu III', 'Vorgehen III');
      _appendFieldIfExists(zieleBuffer, fields, 'nicht eindeutig den Lebensfeldern IIII zuzuordnen sind', 'Übergreifende Ziele');
      _appendFieldIfExists(zieleBuffer, fields, 'Indikatoren zu IV', 'Indikatoren IV');
      _appendFieldIfExists(zieleBuffer, fields, 'Vorgehen zu IV', 'Vorgehen IV');

      if (zieleBuffer.isNotEmpty) {
        buffer.writeln('## Ziele und Maßnahmen');
        buffer.write(zieleBuffer);
        buffer.writeln();
      }

      // FLS-Stunden
      _appendSection(buffer, 'Fachleistungsstunden', {
        if (fields.containsKey('Gesamtergebnis'))
          'Gesamt FLS/Jahr': fields['Gesamtergebnis']!,
        if (fields.containsKey('1AbrEndsumme'))
          'Abrechnung Endsumme': fields['1AbrEndsumme']!,
        if (fields.containsKey('1AbrAnwesenheitsbereitsch'))
          'Anwesenheitsbereitschaft': fields['1AbrAnwesenheitsbereitsch']!,
        if (fields.containsKey('1AbrBehandlungsplanung'))
          'Behandlungsplanung': fields['1AbrBehandlungsplanung']!,
        if (fields.containsKey('Zeitaufteilung'))
          'Zeitaufteilung': fields['Zeitaufteilung']!,
      });

      // Checkboxen als Zusammenfassung
      final checkedItems = checkboxes.keys.toList();
      if (checkedItems.isNotEmpty) {
        buffer.writeln('## Ausgewählte Optionen');
        for (final item in checkedItems) {
          // Nur aussagekräftige Checkbox-Namen anzeigen
          if (!item.startsWith('Kontroll') && !item.startsWith('undefined')) {
            buffer.writeln('- $item: Ja');
          }
        }
        buffer.writeln();
      }

      // Alle verbleibenden Textfelder die noch nicht zugeordnet wurden
      final usedKeys = <String>{
        'NameVorname', 'KopieNameVorname', 'Straße', 'Postleitzahl', 'Ort',
        'Telefon', 'Telefon_2', 'geboren am', 'Geburtsort', 'Krankenkasse',
        'Mitgliedsnummer', 'rechtl Betreuer', 'Wirkungskreis', 'Planvom',
        'Planvombis', 'EinrichtungDienst', 'Bezirksamt 1', 'ICD-10-Schluessel',
        'BeantragteMaßnahme', 'BeantragteMaßnahme2', 'BeantragteMaßnahme3',
        'BeantragteMaßnahme4', 'BeantragteMaßnahme5', 'BeantragteMaßnahme6',
        'D5Text1', 'DText2', 'D3Text2', 'B1Text1', 'B2Text1', 'B5Text',
        'B6Text', 'E1Text', 'E2Text', 'Religionsgem', 'Falls ja in welcher Form',
        'TextA71', 'BerichtText1', 'Freier Text_2', 'HText',
        'Ziele1', 'Ziele2', 'Indikatoren1', 'Indikatoren2',
        'Vorgehen1', 'Vorgehen2', 'NrZiele1', 'NrZiele2', 'NrZiele3',
        'Fortsetzung_2', 'Indikatoren zu III', 'Vorgehen zu III',
        'Indikatoren zu IV', 'Vorgehen zu IV', 'Gesamtergebnis',
        '1AbrEndsumme', '1AbrAnwesenheitsbereitsch', '1AbrBehandlungsplanung',
        'Zeitaufteilung', 'Zeitaufteilung_2', 'Summe1', 'Summe2', 'Summe3',
        'Summe4', 'ZwiErgebnis1', 'ZwiErgebnis2', 'Familienstand5',
        'nicht eindeutig den Lebensfeldern IIII zuzuordnen sind',
      };

      final remaining = fields.entries
          .where((e) => !usedKeys.contains(e.key))
          .where((e) => e.value.trim().length > 2) // Nur sinnvolle Werte
          .toList();

      if (remaining.isNotEmpty) {
        buffer.writeln('## Weitere Angaben');
        for (final entry in remaining) {
          buffer.writeln('${entry.key}: ${entry.value}');
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static void _appendSection(
      StringBuffer buffer, String title, Map<String, String> fields) {
    final nonEmpty = fields.entries.where((e) => e.value.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return;
    buffer.writeln('## $title');
    for (final entry in nonEmpty) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    buffer.writeln();
  }

  static void _appendFieldIfExists(
      StringBuffer buffer, Map<String, String> fields, String key, String label) {
    if (fields.containsKey(key) && fields[key]!.isNotEmpty) {
      buffer.writeln('$label: ${fields[key]}');
    }
  }

  /// Extrahiert statischen Seitentext (Fallback wenn keine Formularfelder).
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
