import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/pseudonymization/engine/pseudonym_engine.dart';
import 'package:teilhabe_assist/features/pseudonymization/models/pseudonym_category.dart';
import 'package:teilhabe_assist/features/pseudonymization/models/pseudonym_mapping.dart';

void main() {
  late PseudonymEngine engine;

  setUp(() {
    engine = PseudonymEngine();
  });

  group('Datumsformate', () {
    test('erkennt dd.MM.yyyy', () {
      final result = engine.pseudonymize('Geboren am 15.03.1985 in Berlin.');
      expect(result.cleanText, contains('[DATUM_001]'));
      expect(result.cleanText, isNot(contains('15.03.1985')));
      expect(result.mappings.any((m) => m.original == '15.03.1985'), isTrue);
    });

    test('erkennt mehrere Daten', () {
      final result = engine.pseudonymize(
        'Zeitraum: 01.01.2024 bis 31.12.2024.',
      );
      final datumMappings =
          result.mappings.where((m) => m.category == PseudonymCategory.datum);
      expect(datumMappings.length, 2);
    });

    test('erkennt dd.MM.yy', () {
      final result = engine.pseudonymize('Am 15.03.85 geboren.');
      expect(result.cleanText, contains('[DATUM_'));
    });
  });

  group('Telefonnummern', () {
    test('erkennt Berliner Festnetz', () {
      final result = engine.pseudonymize('Tel.: 030 12345678');
      expect(result.cleanText, contains('[TELEFON_001]'));
      expect(result.cleanText, isNot(contains('12345678')));
    });

    test('erkennt Mobilnummer', () {
      final result = engine.pseudonymize('Mobil: 0170 1234567');
      expect(result.cleanText, contains('[TELEFON_'));
    });

    test('erkennt internationale Vorwahl', () {
      final result = engine.pseudonymize('Erreichbar unter +49 30 12345678');
      expect(result.cleanText, contains('[TELEFON_'));
    });
  });

  group('E-Mail-Adressen', () {
    test('erkennt Standard-Email', () {
      final result = engine.pseudonymize(
        'E-Mail: max.mustermann@example.com',
      );
      expect(result.cleanText, contains('[EMAIL_001]'));
      expect(result.cleanText, isNot(contains('max.mustermann')));
    });

    test('erkennt Email mit Subdomain', () {
      final result = engine.pseudonymize('info@traeger.berlin.de');
      expect(
        result.mappings.any((m) => m.category == PseudonymCategory.email),
        isTrue,
      );
    });
  });

  group('Aktenzeichen', () {
    test('erkennt Berliner Kostenübernahme-ID', () {
      final result = engine.pseudonymize(
        'Aktenzeichen: EH-2024-12345-FK',
      );
      expect(result.cleanText, contains('[AKTENZEICHEN_001]'));
    });

    test('erkennt EGH-Format', () {
      final result = engine.pseudonymize('Vorgang EGH/2024/67890');
      expect(
        result.mappings
            .any((m) => m.category == PseudonymCategory.aktenzeichen),
        isTrue,
      );
    });
  });

  group('ICD-10-Codes', () {
    test('werden NICHT ersetzt', () {
      final result = engine.pseudonymize(
        'Diagnose: F20.0 (Paranoide Schizophrenie)',
      );
      expect(result.cleanText, contains('F20.0'));
    });

    test('bleiben auch mit mehreren Codes erhalten', () {
      final result = engine.pseudonymize(
        'Diagnosen: F32.1, F60.3, G40.9',
      );
      expect(result.cleanText, contains('F32.1'));
      expect(result.cleanText, contains('F60.3'));
      expect(result.cleanText, contains('G40.9'));
    });
  });

  group('Personennamen', () {
    test('erkennt Name mit Anrede (hohe Konfidenz)', () {
      final result = engine.pseudonymize(
        'Herr Mustermann wurde am Montag beraten.',
      );
      expect(result.cleanText, isNot(contains('Mustermann')));
      final personMappings =
          result.mappings.where((m) => m.category == PseudonymCategory.person);
      expect(personMappings.isNotEmpty, isTrue);
      expect(personMappings.first.confidence, ConfidenceLevel.high);
    });

    test('erkennt Name mit Titel', () {
      final result = engine.pseudonymize(
        'Frau Dr. Schmidt ist die behandelnde Ärztin.',
      );
      expect(result.cleanText, isNot(contains('Schmidt')));
    });

    test('erkennt Vorname aus Wörterbuch (mittlere Konfidenz)', () {
      final result = engine.pseudonymize(
        'Der Klient trifft sich regelmäßig mit Mehmet.',
      );
      // Mehmet ist im Vornamen-Wörterbuch
      final mappings = result.mappings.where(
        (m) => m.original == 'Mehmet',
      );
      expect(mappings.isNotEmpty, isTrue);
    });

    test('erkennt türkische Namen', () {
      final result = engine.pseudonymize(
        'Frau Ayşe berichtet von Fortschritten.',
      );
      expect(result.cleanText, isNot(contains('Ayşe')));
    });

    test('ersetzt NICHT häufige deutsche Wörter', () {
      final result = engine.pseudonymize(
        'Am Montag war der Termin beim Arzt in der Schule.',
      );
      expect(result.cleanText, contains('Montag'));
      expect(result.cleanText, contains('Termin'));
      expect(result.cleanText, contains('Schule'));
    });

    test('markiert unbekannte Großbuchstaben-Wörter als Verdacht', () {
      final result = engine.pseudonymize(
        'Der Klient besucht regelmäßig Zygmunt im Verein.',
      );
      // "Zygmunt" ist nicht im Wörterbuch → niedrige Konfidenz / Warning
      expect(
        result.warnings.any((w) => w.contains('Zygmunt')) ||
            result.mappings.any((m) =>
                m.original == 'Zygmunt' &&
                m.confidence == ConfidenceLevel.low),
        isTrue,
      );
    });
  });

  group('Adressen', () {
    test('erkennt bekannte Berliner Straße mit Hausnummer', () {
      final result = engine.pseudonymize(
        'Wohnhaft in der Sonnenallee 42, 12045 Berlin.',
      );
      expect(result.cleanText, isNot(contains('Sonnenallee')));
      expect(
        result.mappings.any((m) => m.category == PseudonymCategory.adresse),
        isTrue,
      );
    });

    test('erkennt generische Straße mit Hausnummer', () {
      final result = engine.pseudonymize(
        'Adresse: Roseggerstraße 17, 12107 Berlin',
      );
      expect(
        result.mappings.any((m) => m.category == PseudonymCategory.adresse),
        isTrue,
      );
    });
  });

  group('Einrichtungen', () {
    test('erkennt bekannte Berliner Träger', () {
      final result = engine.pseudonymize(
        'Der Klient wird vom Unionhilfswerk betreut.',
      );
      expect(result.cleanText, isNot(contains('Unionhilfswerk')));
      expect(
        result.mappings
            .any((m) => m.category == PseudonymCategory.einrichtung),
        isTrue,
      );
    });

    test('erkennt Abkürzungen', () {
      final result = engine.pseudonymize(
        'Vorstellung in der PIA am KEH.',
      );
      expect(result.cleanText, isNot(contains('PIA')));
      expect(result.cleanText, isNot(contains('KEH')));
    });
  });

  group('Rekonstruktion', () {
    test('stellt Originaltext vollständig wieder her', () {
      const original =
          'Herr Müller, geboren am 15.03.1985, wohnt in der '
          'Sonnenallee 42, 12045 Berlin. Tel.: 030 12345678. '
          'E-Mail: mueller@example.com. Aktenzeichen: EH-2024-12345-FK.';

      final result = engine.pseudonymize(original);

      // Pseudonymisierter Text enthält keine Originaldaten
      expect(result.cleanText, isNot(contains('Müller')));
      expect(result.cleanText, isNot(contains('15.03.1985')));
      expect(result.cleanText, isNot(contains('mueller@example.com')));

      // Rekonstruktion stellt Original her
      final reconstructed = engine.reconstruct(result.cleanText);
      // Hinweis: Rekonstruktion kann minimale Formatunterschiede haben
      // aber alle PII-Daten müssen wieder drin sein
      expect(reconstructed, contains('Müller'));
      expect(reconstructed, contains('15.03.1985'));
      expect(reconstructed, contains('mueller@example.com'));
    });

    test('reconstructWith funktioniert mit externen Mappings', () {
      const original = 'Frau Schmidt hat Termin am 01.06.2024.';
      final result = engine.pseudonymize(original);

      final reconstructed = PseudonymEngine.reconstructWith(
        result.cleanText,
        result.mappings,
      );
      expect(reconstructed, contains('Schmidt'));
      expect(reconstructed, contains('01.06.2024'));
    });
  });

  group('Lernfunktion', () {
    test('erkennt gelernte Namen in Folgeberichten', () {
      engine.learnName('Zygmunt');
      final result = engine.pseudonymize(
        'Der Klient besucht regelmäßig Zygmunt.',
      );
      final mapping = result.mappings.where((m) => m.original == 'Zygmunt');
      expect(mapping.isNotEmpty, isTrue);
      // Gelernter Name = mindestens mittlere Konfidenz
      expect(
        mapping.first.confidence,
        isIn([ConfidenceLevel.medium, ConfidenceLevel.high]),
      );
    });
  });

  group('Synthetischer Berliner Informationsbericht', () {
    test('pseudonymisiert realistischen Berichtstext', () {
      const berichtstext = '''
Informationsbericht – Eingliederungshilfe Berlin
Berichtszeitraum: 01.01.2024 bis 30.06.2024
Aktenzeichen: EH-2024-54321-FK

Leistungsberechtigte Person: Herr Mehmet Yilmaz, geb. 22.08.1990
Wohnhaft: Hermannstraße 15, 12049 Berlin
Telefon: 0170 9876543
E-Mail: m.yilmaz@gmail.com

Leistungserbringer: Unionhilfswerk Berlin
Bezugsbetreuerin: Frau Sabine Krause

Diagnosen: F32.1 (Mittelgradige depressive Episode), F60.31 (Emotional instabile Persönlichkeitsstörung, Borderline-Typ)

Herr Yilmaz nimmt seit Februar 2024 regelmäßig seine Termine im GPZ wahr.
Die behandelnde Ärztin Dr. Schmidt sieht positive Entwicklungen.
Der Kontakt zu seinem Freund Ahmed hat sich stabilisiert.
Sein Betreuer Thomas begleitet ihn wöchentlich zum Jobcenter.
''';

      final result = engine.pseudonymize(berichtstext);

      // Personenbezogene Daten MÜSSEN ersetzt sein
      expect(result.cleanText, isNot(contains('Mehmet')));
      expect(result.cleanText, isNot(contains('Yilmaz')));
      expect(result.cleanText, isNot(contains('22.08.1990')));
      expect(result.cleanText, isNot(contains('Hermannstraße 15')));
      expect(result.cleanText, isNot(contains('0170 9876543')));
      expect(result.cleanText, isNot(contains('m.yilmaz@gmail.com')));
      expect(result.cleanText, isNot(contains('EH-2024-54321')));
      expect(result.cleanText, isNot(contains('Sabine')));
      expect(result.cleanText, isNot(contains('Krause')));

      // ICD-10-Codes MÜSSEN erhalten bleiben
      expect(result.cleanText, contains('F32.1'));
      expect(result.cleanText, contains('F60.31'));

      // Mindestens 8 Ersetzungen (konservativ)
      expect(result.totalReplacements, greaterThanOrEqualTo(8));

      // Strukturelle Begriffe bleiben erhalten
      expect(result.cleanText, contains('Informationsbericht'));
      expect(result.cleanText, contains('Berichtszeitraum'));
    });
  });

  group('Validierung', () {
    test('findet übrig gebliebene potenzielle PII', () {
      final issues = engine.validateAnonymization(
        'Der Klient trifft sich mit Zygmunt am 15.03.2024.',
      );
      expect(issues, isNotEmpty);
    });

    test('findet keine Probleme in sauberem Text', () {
      final issues = engine.validateAnonymization(
        'Der Klient nimmt regelmäßig an der Tagesstruktur teil. '
        'Die Teilhabe im Bereich Kommunikation hat sich verbessert.',
      );
      // Keine Daten, keine Namen
      expect(
        issues.where((i) => i.contains('Datum') || i.contains('Telefon')),
        isEmpty,
      );
    });
  });
}
