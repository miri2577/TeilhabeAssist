import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/report_module.dart';

/// Import des Berichts-Rohpakets aus der FEGH-Leistungsnachweis-Webapp
/// (Format `fegh-berichtspaket`, Version 1 — JSON-Download am Bericht).
///
/// Das Paket bringt Klartext-Stammdaten, die Ziele der Ziel- und
/// Leistungsplanung (ZLP) und die Verlaufsdokumentation des Berichtszeitraums
/// mit. Die Pseudonymisierung passiert wie bei manueller Eingabe erst in der
/// Generierung — importierte Namen gehen exakt denselben Weg.
class RawPackageResult {
  RawPackageResult({
    required this.fileName,
    required this.stammdaten,
    required this.notes,
    required this.goalModules,
    required this.zielAnzahl,
    required this.dokuAnzahl,
  });

  final String fileName;
  final Map<String, String> stammdaten;
  final String notes;
  final List<ReportModule> goalModules;
  final int zielAnzahl;
  final int dokuAnzahl;
}

class RawPackageImporter {
  /// Öffnet den Datei-Dialog und parst das gewählte Rohpaket.
  /// Liefert `null` bei Abbruch; wirft [FormatException] bei fremdem JSON.
  static Future<RawPackageResult?> pickAndParse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'FEGH-Bericht Rohpaket (JSON) wählen',
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    final raw = await File(path).readAsString();
    return parse(raw, fileName: picked!.files.single.name);
  }

  static RawPackageResult parse(String jsonString, {String fileName = ''}) {
    final data = jsonDecode(jsonString);
    if (data is! Map<String, dynamic> ||
        data['format'] != 'fegh-berichtspaket') {
      throw const FormatException(
          'Keine gültige Rohpaket-Datei (erwartet: format "fegh-berichtspaket").');
    }

    final klient = _map(data['klient']);
    final zeitraum = _map(data['zeitraum']);
    final bewilligung = _map(data['bewilligung']);
    final ziele = (data['ziele'] as List? ?? const []);
    final dokus = (data['verlaufsdokumentation'] as List? ?? const []);

    // --- Stammdaten (Webapp-Felder -> Formularfelder der Vorlage 1.01) ---
    final stammdaten = <String, String>{
      'vorname': _s(klient['vorname']),
      'familienname': _s(klient['nachname']),
      'geburtsdatum': _deDatum(_s(klient['geburtsdatum'])),
      'berichtszeitraum_von': _deDatum(_s(zeitraum['von'])),
      'berichtszeitraum_bis': _deDatum(_s(zeitraum['bis'])),
      'id_kostenuebernahme': _s(bewilligung['aktenzeichen']).isNotEmpty
          ? _s(bewilligung['aktenzeichen'])
          : _s(klient['person_id']),
      'teilhabefachdienst': _bezirk(_s(bewilligung['kostentraeger'])),
    }..removeWhere((_, v) => v.trim().isEmpty);

    // --- Ziele -> Teilhabeziel-Module (je Richtungsziel eines, inkl. Kinder) ---
    final goalModules = <ReportModule>[];
    final richtungsziele = <String, StringBuffer>{};
    final freie = StringBuffer();
    for (final z in ziele.whereType<Map<String, dynamic>>()) {
      final zeile = _zielZeile(z);
      final rz = _s(z['richtungsziel']);
      if (_s(z['art']).startsWith('Richtungsziel')) {
        richtungsziele.putIfAbsent(_s(z['titel']), StringBuffer.new)
          ..writeln('Richtungsziel: ${_s(z['titel'])}'
              '${_s(z['status']).isNotEmpty ? ' [${_s(z['status'])}]' : ''}');
      } else if (rz.isNotEmpty) {
        richtungsziele.putIfAbsent(rz, StringBuffer.new).writeln(zeile);
      } else {
        freie.writeln(zeile);
      }
    }
    var nr = 1;
    for (final entry in richtungsziele.entries) {
      goalModules.add(ReportModule(
        type: ModuleType.teilhabeziel,
        goalNumber: nr++,
        notes: entry.value.toString().trimRight(),
      ));
    }
    if (freie.isNotEmpty) {
      goalModules.add(ReportModule(
        type: ModuleType.teilhabeziel,
        goalNumber: nr,
        notes: freie.toString().trimRight(),
      ));
    }

    // --- Verlaufsdoku + Rahmendaten -> zentrale Notizen ---
    final notes = StringBuffer();
    notes.writeln('=== Import aus FEGH-Leistungsnachweis'
        '${fileName.isNotEmpty ? ' ($fileName)' : ''} ===');
    if (bewilligung.isNotEmpty) {
      final teile = <String>[
        if (_s(bewilligung['hbg']).isNotEmpty) 'HBG ${_s(bewilligung['hbg'])}',
        if (_s(bewilligung['fls_woche']).isNotEmpty)
          '${_s(bewilligung['fls_woche'])} FLS/Woche',
        if (_s(bewilligung['gueltig_bis']).isNotEmpty)
          'Bewilligung bis ${_deDatum(_s(bewilligung['gueltig_bis']))}',
      ];
      if (teile.isNotEmpty) notes.writeln('Rahmendaten: ${teile.join(' · ')}');
    }
    final statistik = _map(data['statistik']);
    if (statistik.isNotEmpty) {
      notes.writeln('Im Zeitraum: ${statistik['kontakte_im_zeitraum'] ?? '?'} '
          'Kontakte, ${statistik['doku_eintraege'] ?? '?'} Doku-Einträge');
    }
    if (dokus.isNotEmpty) {
      notes
        ..writeln()
        ..writeln('--- Verlaufsdokumentation ---');
      for (final e in dokus.whereType<Map<String, dynamic>>()) {
        final kopf = [
          _deDatum(_s(e['datum'])),
          _s(e['leistungsart']),
          if (_s(e['taetigkeit']).isNotEmpty) _s(e['taetigkeit']),
        ].join(' · ');
        notes.writeln('\n$kopf');
        if (_s(e['text']).isNotEmpty) notes.writeln(_s(e['text']));
        final bezug = (e['zielbezug'] as List? ?? const []).join(', ');
        if (bezug.isNotEmpty) notes.writeln('(Zielbezug: $bezug)');
      }
    }

    return RawPackageResult(
      fileName: fileName,
      stammdaten: stammdaten,
      notes: notes.toString().trimRight(),
      goalModules: goalModules,
      zielAnzahl: ziele.length,
      dokuAnzahl: dokus.length,
    );
  }

  static String _zielZeile(Map<String, dynamic> z) {
    final b = StringBuffer('- ${_s(z['titel'])}');
    if (_s(z['status']).isNotEmpty) b.write(' [${_s(z['status'])}]');
    if (_s(z['indikator']).isNotEmpty) {
      b.write('\n  Indikator: ${_s(z['indikator'])}');
    }
    if (_s(z['beschreibung']).isNotEmpty) {
      b.write('\n  ${_s(z['beschreibung'])}');
    }
    return b.toString();
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map<String, dynamic> ? v : const {};

  static String _s(dynamic v) => v?.toString() ?? '';

  /// ISO-Datum (2026-07-14) -> deutsches Formularformat (14.07.2026).
  static String _deDatum(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  }

  /// "Bezirksamt Mitte von Berlin" -> "Mitte" (Feld Teilhabefachdienst/Bezirk).
  static String _bezirk(String kostentraeger) {
    final m = RegExp(r'^Bezirksamt (.+?)( von Berlin)?$')
        .firstMatch(kostentraeger.trim());
    return m?.group(1) ?? '';
  }
}
