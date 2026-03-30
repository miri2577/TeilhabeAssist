import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/report_editor/models/fls_data.dart';

void main() {
  group('FLS-Daten Berechnung', () {
    test('berechnet bewilligte FLS gesamt korrekt', () {
      final fls = FlsData(bewilligtProWoche: 10, berichtszeitraumWochen: 26);
      expect(fls.bewilligtGesamt, 260);
    });

    test('berechnet Auslastungsquote korrekt', () {
      final fls = FlsData(
        bewilligtProWoche: 10,
        berichtszeitraumWochen: 26,
        erbracht: 234,
      );
      expect(fls.auslastung, closeTo(90, 0.1));
    });

    test('erkennt signifikante Abweichung über 10%', () {
      final fls = FlsData(
        bewilligtProWoche: 10,
        berichtszeitraumWochen: 26,
        erbracht: 200, // ~77%
      );
      expect(fls.hatAbweichung, isTrue);
    });

    test('erkennt keine Abweichung bei ~100%', () {
      final fls = FlsData(
        bewilligtProWoche: 10,
        berichtszeitraumWochen: 26,
        erbracht: 258, // ~99.2%
      );
      expect(fls.hatAbweichung, isFalse);
    });

    test('berechnet Fachkraftquote korrekt', () {
      final fls = FlsData(
        erbracht: 200,
        erbrachtQualifiziert: 160,
        erbrachtEinfach: 40,
      );
      expect(fls.fachkraftquote, closeTo(80, 0.1));
    });

    test('warnt bei Fachkraftquote unter 75%', () {
      final fls = FlsData(
        erbracht: 200,
        erbrachtQualifiziert: 140, // 70%
        erbrachtEinfach: 60,
      );
      expect(fls.fachkraftquoteUnter75, isTrue);
    });

    test('berechnet indirekte Assistenz nach 5:1-Regel', () {
      final fls = FlsData(erbracht: 250);
      expect(fls.indirekteAssistenz, 50);
    });

    test('generiert Prompt-Text', () {
      final fls = FlsData(
        bewilligtProWoche: 8,
        qualifiziertProWoche: 6,
        einfachProWoche: 2,
        berichtszeitraumWochen: 26,
        erbracht: 200,
        erbrachtQualifiziert: 155,
        erbrachtEinfach: 45,
      );
      final text = fls.toPromptText();
      expect(text, contains('Bewilligte FLS'));
      expect(text, contains('Erbrachte FLS'));
      expect(text, contains('Auslastung'));
      expect(text, contains('Fachkraftquote'));
    });
  });
}
