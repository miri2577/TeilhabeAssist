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
  ///
  /// Zusätzlich werden, falls vorhanden, die Kopf-/Personendaten-Felder
  /// des Berliner Informationsberichts (`IB_S1_*`) ausgelesen und als
  /// `metadata` zurückgegeben — damit der Editor sie direkt in den Draft
  /// übernehmen kann.
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

    // Kopf-/Personendaten extrahieren — zwei Quellen kombinieren:
    // 1. AcroForm-Felder mit bekannten Namen (Berliner Informationsbericht
    //    `IB_S1_*` → genau, deckt aber nur diese Vorlage ab)
    // 2. Text-Pattern-Matching auf den extrahierten Fließtext
    //    (funktioniert vorlagenunabhängig: BRP Ges 100, alte TIP/TIB-Bögen,
    //    eigene Berichte etc.)
    final fieldMeta = _extractBerlinHeaderMetadata(document);
    final pageText = _extractPageText(document);
    final textMeta = _extractMetadataFromText(pageText);

    // Merge: Feld-basiert hat Vorrang (genauer), Text füllt Lücken.
    final metadata = <String, String>{...textMeta, ...fieldMeta};

    document.dispose();

    return PdfImportResult(
      text: text.trim(),
      fileName: fileName,
      pageCount: pageCount,
      hasFormFields: formText.isNotEmpty,
      metadata: metadata,
    );
  }

  /// Heuristisches Pattern-Matching auf Fließtext einer Bericht-PDF.
  /// Funktioniert mit beliebigen Berliner Vorlagen (BRP Ges 100,
  /// TIB-Bogen, Informationsbericht), weil es nach den Label-Texten
  /// sucht — nicht nach Feld-Namen.
  static Map<String, String> _extractMetadataFromText(String text) {
    final out = <String, String>{};
    if (text.trim().isEmpty) return out;

    // Patterns: (key, Regex). Erste Match-Gruppe = Wert.
    // Mehrzeilige Werte werden bewusst auf eine Zeile beschränkt, damit
    // wir nicht versehentlich Folge-Inhalte mit aufnehmen.
    final patterns = <(String, RegExp)>[
      // BRP Ges 100 schreibt "Name, Vorname" als eine Zelle
      ('_name_vorname', RegExp(
        r'(?:^|\n)\s*Name,\s*Vorname[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('familienname', RegExp(
        r'(?:^|\n)\s*(?:Familienname|Nachname)[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('vorname', RegExp(
        r'(?:^|\n)\s*Vorname(?:\(n\))?[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('anrede', RegExp(
        r'(?:^|\n)\s*Anrede[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('titel', RegExp(
        r'(?:^|\n)\s*Titel[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('geburtsname', RegExp(
        r'(?:^|\n)\s*Geburtsname[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('geburtsdatum', RegExp(
        r'(?:^|\n)\s*(?:Geburtsdatum|geboren\s+am)[\s:]*'
        r'(\d{1,2}\.\d{1,2}\.\d{2,4})',
        caseSensitive: false,
      )),
      ('geburtsort', RegExp(
        r'(?:^|\n)\s*Geburtsort[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('geschlecht', RegExp(
        r'(?:^|\n)\s*Geschlecht[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('familienstand', RegExp(
        r'(?:^|\n)\s*Familienstand[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('strasse', RegExp(
        r'(?:^|\n)\s*(?:Stra(?:ß|ss)e|Anschrift)[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('hausnummer', RegExp(
        r'(?:^|\n)\s*Hausnummer[\s\(von\):]*([^\n]+)',
        caseSensitive: false,
      )),
      ('plz', RegExp(
        r'(?:^|\n)\s*(?:Postleitzahl|PLZ)[\s:]*(\d{4,5})',
        caseSensitive: false,
      )),
      ('ort', RegExp(
        r'(?:^|\n)\s*Ort[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('telefon_festnetz', RegExp(
        r'(?:^|\n)\s*Telefon(?:\s*\(Festnetz\))?[\s:]*'
        r'([+\d][\d\s\(\)\/\-]{5,})',
        caseSensitive: false,
      )),
      ('telefon_mobil', RegExp(
        r'(?:^|\n)\s*Telefon\s*\(Mobil\)[\s:]*'
        r'([+\d][\d\s\(\)\/\-]{5,})',
        caseSensitive: false,
      )),
      ('email', RegExp(
        r'(?:^|\n)\s*E-?Mail[\s:]*'
        r'([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})',
        caseSensitive: false,
      )),
      ('id_kostenuebernahme', RegExp(
        r'(?:^|\n)\s*(?:ID\s+Kosten(?:ü|ue)bernahme|Aktenzeichen|AZ|'
        r'Bescheid-?Nr\.?|Bescheidnr)[\s:]*([A-Z0-9][A-Z0-9\-/]{2,})',
        caseSensitive: false,
      )),
      ('berichtszeitraum_von', RegExp(
        r'(?:^|\n)\s*Berichtszeitraum[\s:]*(\d{1,2}\.\d{1,2}\.\d{2,4})',
        caseSensitive: false,
      )),
      ('berichtszeitraum_bis', RegExp(
        r'Berichtszeitraum.*?bis[\s:]*(\d{1,2}\.\d{1,2}\.\d{2,4})',
        caseSensitive: false,
      )),
      ('leistungstyp', RegExp(
        r'(?:^|\n)\s*Leistungstyp[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('leistungserbringer', RegExp(
        r'(?:^|\n)\s*Leistungserbringer[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('kontakt_le', RegExp(
        r'(?:^|\n)\s*E-?Mail/Tel\s*Nr[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      // BRP-spezifisch
      ('krankenkasse', RegExp(
        r'(?:^|\n)\s*Krankenkasse[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('rechtl_betreuer', RegExp(
        r'(?:^|\n)\s*rechtl\.?\s*Betreuer[\s:]*([^\n]+)',
        caseSensitive: false,
      )),
      ('behandelnde_aerztin', RegExp(
        r'(?:^|\n)\s*behandelnde[/]?r?\s+(?:Ä|Ae)rztin[/]?\s*Arzt[\s:]*'
        r'([^\n]+)',
        caseSensitive: false,
      )),
    ];

    for (final p in patterns) {
      final match = p.$2.firstMatch(text);
      if (match == null) continue;
      final value = match.group(1)?.trim() ?? '';
      if (value.isEmpty) continue;
      // Sicherheits-Schwellen: extrem lange Treffer ablehnen (vermutlich
      // hat das Pattern in Fließtext reingegriffen).
      if (value.length > 80) continue;
      out[p.$1] = value;
    }

    // BRP Ges 100 — Layout schreibt den Wert OBERHALB des Labels.
    // Wir suchen daher "<Wert>\n<Label>"-Muster.
    _matchValueBeforeLabel(text, out);

    // BRP-Sonderfall: "Plan vom DD.MM.YY bis DD.MM.YY"
    final planRange = RegExp(
      r'Plan\s+vom\s+(\d{1,2}\.\d{1,2}\.\d{2,4})\s+bis\s+'
      r'(\d{1,2}\.\d{1,2}\.\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (planRange != null) {
      out.putIfAbsent('berichtszeitraum_von', () => planRange.group(1)!);
      out.putIfAbsent('berichtszeitraum_bis', () => planRange.group(2)!);
    }

    // BRP-Sonderfall: "DD.MM.YYYY Geburtsort" als eine Zeile, gefolgt
    // von "geboren am Geburtsort"-Label
    final birthLine = RegExp(
      r'(?:^|\n)\s*(\d{1,2}\.\d{1,2}\.\d{2,4})\s+([A-ZÄÖÜ][^\n]{0,40})\s*\n'
      r'\s*geboren\s+am\s+Geburtsort',
      caseSensitive: false,
    ).firstMatch(text);
    if (birthLine != null) {
      out.putIfAbsent('geburtsdatum', () => birthLine.group(1)!.trim());
      out.putIfAbsent('geburtsort', () => birthLine.group(2)!.trim());
    }

    // Spezialfall "Name, Vorname" — wenn vorhanden und Familienname/
    // Vorname nicht separat erkannt, aufsplitten.
    final nameVorname = out.remove('_name_vorname');
    if (nameVorname != null) {
      final parts = nameVorname.split(RegExp(r',\s*'));
      if (parts.length >= 2) {
        out.putIfAbsent('familienname', () => parts[0].trim());
        out.putIfAbsent('vorname', () => parts.sublist(1).join(', ').trim());
      } else {
        // Kein Komma — als Familienname übernehmen
        out.putIfAbsent('familienname', () => nameVorname.trim());
      }
    }

    return out;
  }

  /// BRP-Layout: Wert steht in der Zeile ÜBER dem Label.
  /// Beispiel-Block:
  ///   `Wilhelmienenhofstr. 33`
  ///   `Straße`
  /// → strasse = "Wilhelmienenhofstr. 33"
  ///
  /// Plus PLZ+Ort als kombinierte Zeile vor "Postleitzahl Ort"-Label,
  /// und "Name, Vorname" als Zeile vor dem gleichnamigen Label.
  static void _matchValueBeforeLabel(String text, Map<String, String> out) {
    // (Editor-Key, Label-Regex, Wert-Validator)
    final rules = <(String, RegExp, bool Function(String))>[
      ('strasse', RegExp(r'^\s*Stra(?:ß|ss)e\s*$', multiLine: true, caseSensitive: false),
        (v) => v.length <= 80 && !v.contains(RegExp(r'^Stra(?:ß|ss)e', caseSensitive: false))),
      ('telefon_festnetz', RegExp(r'^\s*Telefon\s*$', multiLine: true, caseSensitive: false),
        (v) => RegExp(r'^[+\d][\d\s\(\)\/\-]{5,}$').hasMatch(v.trim())),
      ('krankenkasse', RegExp(r'^\s*Krankenkasse(\s+Gesch(?:ä|ae)ftsstelle)?\s*$',
          multiLine: true, caseSensitive: false),
        (v) => v.length <= 60 && !v.toLowerCase().contains('krankenkasse')),
      ('beruf', RegExp(r'^\s*Beruf\s*$', multiLine: true, caseSensitive: false),
        (v) => v.length <= 80 && !v.toLowerCase().startsWith('beruf')),
    ];

    final lines = text.split('\n');
    for (var i = 1; i < lines.length; i++) {
      final candidateLabel = lines[i];
      for (final r in rules) {
        if (r.$2.hasMatch(candidateLabel)) {
          // Suche den nächsten nicht-leeren Wert in den vorhergehenden 3 Zeilen
          for (var j = i - 1; j >= 0 && j >= i - 6; j--) {
            final v = lines[j].trim();
            if (v.isEmpty) continue;
            if (r.$3(v)) {
              out.putIfAbsent(r.$1, () => v);
            }
            break;
          }
        }
      }
    }

    // Spezial: "PLZ Ort"-Zeile vor "Postleitzahl Ort"-Label
    final plzOrtLabelIdx = lines.indexWhere((l) =>
        RegExp(r'^\s*Postleitzahl\s+Ort\s*$', caseSensitive: false).hasMatch(l));
    if (plzOrtLabelIdx > 0) {
      for (var j = plzOrtLabelIdx - 1; j >= 0 && j >= plzOrtLabelIdx - 6; j--) {
        final v = lines[j].trim();
        if (v.isEmpty) continue;
        final m = RegExp(r'^(\d{4,5})\s+(.+)$').firstMatch(v);
        if (m != null) {
          out.putIfAbsent('plz', () => m.group(1)!.trim());
          out.putIfAbsent('ort', () => m.group(2)!.trim());
        }
        break;
      }
    }

    // Spezial: "Name, Vorname"-Zeile als Wert vor dem gleichnamigen Label
    final nameVornameLabelIdx = lines.indexWhere((l) =>
        RegExp(r'^\s*Name,\s*Vorname\s*$', caseSensitive: false).hasMatch(l));
    if (nameVornameLabelIdx > 0) {
      for (var j = nameVornameLabelIdx - 1; j >= 0 && j >= nameVornameLabelIdx - 8; j--) {
        final v = lines[j].trim();
        if (v.isEmpty) continue;
        // Plausibilität: Komma-getrennt oder einzelner Name
        if (v.length > 80) break;
        out.putIfAbsent('_name_vorname', () => v);
        break;
      }
    }
  }

  /// Liest die ausgefüllten `IB_S1_*`-Felder der Berliner Vorlage 1.01 aus
  /// und mappt sie auf das Metadaten-Schema, das im Editor verwendet wird.
  /// Liefert eine leere Map, wenn keines der erwarteten Felder gesetzt ist.
  static Map<String, String> _extractBerlinHeaderMetadata(
      PdfDocument document) {
    final result = <String, String>{};

    /// Zuordnung Field-Name → Editor-Key. ComboBox-Werte werden wie
    /// TextBox behandelt — Syncfusion liefert beim ausgefüllten Feld den
    /// gewählten Text.
    const mapping = <String, String>{
      'IB_S1_02_02': 'teilhabefachdienst',
      'IB_S1_06_02': 'id_kostenuebernahme',
      'IB_S1_07_02': 'berichtszeitraum_von',
      'IB_S1_07_04': 'berichtszeitraum_bis',
      'IB_S1_08_02': 'leistungstyp',
      'IB_S1_09_02': 'leistungserbringer',
      'IB_S1_10_02': 'kontakt_le',
      'IB_S1_12_02': 'strasse',
      'IB_S1_13_02': 'hausnummer',
      'IB_S1_14_02': 'weitere_adresse',
      'IB_S1_15_02': 'plz',
      'IB_S1_16_02': 'ort',
      'IB_S1_18_02': 'anrede',
      'IB_S1_19_02': 'titel',
      'IB_S1_20_02': 'familienname',
      'IB_S1_21_02': 'vorname',
      'IB_S1_22_02': 'geburtsname',
      'IB_S1_23_02': 'geburtsdatum',
      'IB_S1_24_02': 'geburtsort',
      'IB_S1_25_02': 'geschlecht',
      'IB_S1_26_02': 'familienstand',
      'IB_S1_28_02': 'telefon_festnetz',
      'IB_S1_29_02': 'telefon_mobil',
      'IB_S1_30_02': 'email',
    };

    try {
      final form = document.form;
      for (var i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        final name = field.name;
        if (name == null) continue;
        final key = mapping[name];
        if (key == null) continue;

        String? value;
        if (field is PdfTextBoxField) {
          // Bevorzugt Appearance-Stream (sauber), fallback field.text.
          value = _extractFromAppearanceStream(field) ??
              _cleanFieldText(field.text.trim());
        } else if (field is PdfComboBoxField) {
          try {
            value = field.selectedValue.trim();
          } catch (_) {
            value = null;
          }
        }
        if (value != null && value.trim().isNotEmpty) {
          result[key] = value.trim();
        }
      }
    } catch (_) {
      // Falls Vorlage nicht erkennbar / keine AcroForm — leere Map.
    }
    return result;
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

      // PDF-Typ erkennen: BRP (Ges 100) oder Informationsbericht
      final isBrp = document.pages.count > 15; // BRP hat 22 Seiten, InfoBericht 5
      // BRP: Nur Seite 5-11 (Index 4-10), Seite 4 = Krankengeschichte überspringen
      // Informationsbericht: Alle Seiten (Seite 2-5, Index 1-4)
      final minPage = isBrp ? 4 : 1;
      final maxPage = isBrp ? 10 : document.pages.count - 1;

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

        // Seitenfilter je nach PDF-Typ
        if (pageIndex < minPage || pageIndex > maxPage) continue;

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

  /// Kopf-/Personendaten aus dem Berliner Formular (Seite 1).
  /// Keys: `id_kostenuebernahme`, `berichtszeitraum_von/bis`, `leistungstyp`,
  /// `leistungserbringer`, `kontakt_le`, `strasse`, `hausnummer`,
  /// `weitere_adresse`, `plz`, `ort`, `anrede`, `titel`, `familienname`,
  /// `vorname`, `geburtsname`, `geburtsdatum`, `geburtsort`, `geschlecht`,
  /// `familienstand`, `telefon_festnetz`, `telefon_mobil`, `email`.
  /// Leer, wenn die importierte PDF nicht der Berliner Vorlage entspricht.
  final Map<String, String> metadata;

  const PdfImportResult({
    required this.text,
    required this.fileName,
    required this.pageCount,
    this.hasFormFields = false,
    this.metadata = const {},
  });
}
