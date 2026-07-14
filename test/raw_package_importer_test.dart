import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/report_editor/models/report_module.dart';
import 'package:teilhabe_assist/features/report_editor/services/raw_package_importer.dart';

const _beispiel = '''
{
  "format": "fegh-berichtspaket",
  "version": 1,
  "vorlage": {"name": "Informationsbericht (Vorlage 1.01)",
              "abschnitte": ["Anlass des Berichts", "Aktuelle Situation"]},
  "klient": {"name": "Muster, Erika", "vorname": "Erika", "nachname": "Muster",
             "geburtsdatum": "1984-05-12", "person_id": "BE-100001",
             "bezugsbetreuer": "N. N."},
  "zeitraum": {"von": "2025-07-15", "bis": "2026-07-14", "faellig_am": "2026-08-03"},
  "bewilligung": {"hbg": 3, "fls_woche": "3.8100", "gueltig_von": "2026-01-01",
                  "gueltig_bis": "2026-12-31",
                  "kostentraeger": "Bezirksamt Mitte von Berlin",
                  "aktenzeichen": "EGH-Mi-20631"},
  "ziele": [
    {"art": "Richtungsziel", "titel": "Selbstständige Haushaltsführung",
     "richtungsziel": null, "indikator": "", "beschreibung": "", "status": "aktiv"},
    {"art": "Handlungsziel", "titel": "Wocheneinkauf eigenständig",
     "richtungsziel": "Selbstständige Haushaltsführung",
     "indikator": "4 Wochen ohne Begleitung", "beschreibung": "", "status": "aktiv"},
    {"art": "Handlungsziel", "titel": "Freies Ziel ohne Richtungsziel",
     "richtungsziel": null, "indikator": "", "beschreibung": "", "status": "erreicht"}
  ],
  "statistik": {"kontakte_im_zeitraum": 42, "doku_eintraege": 2},
  "verlaufsdokumentation": [
    {"datum": "2026-03-05", "leistungsart": "FS", "taetigkeit": "Hausbesuch",
     "betreuer": "N. N.", "text": "Einkauf gemeinsam geplant.",
     "zielbezug": ["Wocheneinkauf eigenständig"]},
    {"datum": "2026-04-12", "leistungsart": "FS", "taetigkeit": "Begleitung",
     "betreuer": "N. N.", "text": "Amtstermin begleitet.", "zielbezug": []}
  ]
}
''';

void main() {
  group('RawPackageImporter.parse', () {
    test('mappt Stammdaten in die Formularfelder der Vorlage 1.01', () {
      final r = RawPackageImporter.parse(_beispiel, fileName: 'test.json');
      expect(r.stammdaten['vorname'], 'Erika');
      expect(r.stammdaten['familienname'], 'Muster');
      expect(r.stammdaten['geburtsdatum'], '12.05.1984'); // ISO -> deutsch
      expect(r.stammdaten['berichtszeitraum_von'], '15.07.2025');
      expect(r.stammdaten['berichtszeitraum_bis'], '14.07.2026');
      expect(r.stammdaten['id_kostenuebernahme'], 'EGH-Mi-20631');
      expect(r.stammdaten['teilhabefachdienst'], 'Mitte'); // aus "Bezirksamt … von Berlin"
    });

    test('baut Teilhabeziel-Module aus der ZLP', () {
      final r = RawPackageImporter.parse(_beispiel);
      expect(r.goalModules.length, 2); // 1 Richtungsziel-Gruppe + freie Ziele
      expect(r.goalModules.first.type, ModuleType.teilhabeziel);
      expect(r.goalModules.first.notes, contains('Selbstständige Haushaltsführung'));
      expect(r.goalModules.first.notes, contains('Wocheneinkauf eigenständig'));
      expect(r.goalModules.first.notes, contains('Indikator: 4 Wochen'));
      expect(r.goalModules.last.notes, contains('Freies Ziel'));
      expect(r.goalModules.last.notes, contains('[erreicht]'));
    });

    test('formatiert die Verlaufsdoku chronologisch in die Notizen', () {
      final r = RawPackageImporter.parse(_beispiel);
      expect(r.notes, contains('Verlaufsdokumentation'));
      expect(r.notes, contains('05.03.2026 · FS · Hausbesuch'));
      expect(r.notes, contains('Einkauf gemeinsam geplant.'));
      expect(r.notes, contains('(Zielbezug: Wocheneinkauf eigenständig)'));
      expect(r.notes, contains('HBG 3'));
      expect(r.notes, contains('42 Kontakte'));
      expect(r.dokuAnzahl, 2);
      expect(r.zielAnzahl, 3);
    });

    test('lehnt fremdes JSON ab', () {
      expect(() => RawPackageImporter.parse('{"foo": 1}'),
          throwsA(isA<FormatException>()));
      expect(() => RawPackageImporter.parse('[1,2,3]'),
          throwsA(isA<FormatException>()));
    });
  });
}
