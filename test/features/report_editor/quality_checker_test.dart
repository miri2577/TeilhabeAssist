import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/report_editor/models/report_draft.dart';
import 'package:teilhabe_assist/features/report_editor/models/report_module.dart';
import 'package:teilhabe_assist/features/report_editor/services/quality_checker.dart';

void main() {
  group('Qualitätsprüfung Draft', () {
    test('warnt bei leeren Pflichtmodulen', () {
      final draft = ReportDraft(type: ReportType.informationsbericht);
      // Alle Module sind leer
      final issues = QualityChecker.checkDraft(draft);
      final warnings = issues
          .where((i) => i.severity == QualityIssueSeverity.warning)
          .toList();
      expect(warnings, isNotEmpty);
    });

    test('erkennt fehlendes Teilhabeziel', () {
      final draft = ReportDraft(
        type: ReportType.informationsbericht,
        modules: [
          ReportModule(type: ModuleType.kopfdaten, notes: 'Kopfdaten...'),
          ReportModule(type: ModuleType.zusammenfassung, notes: 'Zusammenfassung...'),
        ],
      );
      final issues = QualityChecker.checkDraft(draft);
      expect(
        issues.any(
          (i) =>
              i.severity == QualityIssueSeverity.error &&
              i.message.contains('Teilhabeziel'),
        ),
        isTrue,
      );
    });

    test('keine Fehler bei vollständigem Draft', () {
      final draft = ReportDraft(
        type: ReportType.informationsbericht,
        modules: [
          ReportModule(
              type: ModuleType.kopfdaten, notes: 'EH-2024-12345'),
          ReportModule(type: ModuleType.persondaten, notes: 'Max M.'),
          ReportModule(
              type: ModuleType.allgemeineInfos, notes: 'Tagesstruktur'),
          ReportModule(
            type: ModuleType.teilhabeziel,
            goalNumber: 1,
            notes: 'Ziel: Selbständige Haushaltsführung',
          ),
          ReportModule(type: ModuleType.flsUebersicht, notes: '8 FLS/Woche'),
          ReportModule(
              type: ModuleType.zusammenfassung, notes: 'Empfehlung'),
        ],
      );
      final issues = QualityChecker.checkDraft(draft);
      final errors =
          issues.where((i) => i.severity == QualityIssueSeverity.error);
      expect(errors, isEmpty);
    });
  });

  group('Qualitätsprüfung generierter Text', () {
    test('erkennt defizitorientierte Formulierungen', () {
      const text = 'Der Klient kann nicht selbständig einkaufen. '
          'Er ist unfähig, seine Finanzen zu regeln. '
          'Trotz der Schwäche zeigt er Fortschritte.';
      final issues = QualityChecker.checkGeneratedText(
        text,
        ReportType.informationsbericht,
      );
      final infos =
          issues.where((i) => i.severity == QualityIssueSeverity.info);
      expect(infos.length, greaterThanOrEqualTo(2));
    });

    test('erkennt Platzhalter-Reste', () {
      const text = 'Der Bericht für [PERSON_001] zeigt Fortschritte.';
      final issues = QualityChecker.checkGeneratedText(
        text,
        ReportType.informationsbericht,
      );
      expect(
        issues.any(
          (i) =>
              i.severity == QualityIssueSeverity.error &&
              i.message.contains('Platzhalter'),
        ),
        isTrue,
      );
    });

    test('warnt bei sehr kurzem Text', () {
      const text = 'Der Klient zeigt Fortschritte. Empfehlung: Beibehaltung.';
      final issues = QualityChecker.checkGeneratedText(
        text,
        ReportType.informationsbericht,
      );
      expect(
        issues.any((i) => i.message.contains('sehr kurz')),
        isTrue,
      );
    });

    test('keine Probleme bei gutem Text', () {
      final text = '${List.generate(250, (i) => 'Wort$i').join(' ')}'
          ' Sichtweise der leistungsberechtigten Person: '
              'Förderfaktor: stabiles soziales Umfeld. '
              'Barriere: eingeschränkte Mobilität.';
      final issues = QualityChecker.checkGeneratedText(
        text,
        ReportType.informationsbericht,
      );
      final errors =
          issues.where((i) => i.severity == QualityIssueSeverity.error);
      expect(errors, isEmpty);
    });
  });
}
