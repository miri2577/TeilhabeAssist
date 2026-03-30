import 'package:flutter_test/flutter_test.dart';
import 'package:teilhabe_assist/features/pseudonymization/engine/brp_page4_detector.dart';

void main() {
  group('BRP Seite 4 Erkennung', () {
    test('blockiert Text mit expliziter Seite-4-Referenz', () {
      const text = 'Aus Seite 4 des BRP: Die Krankengeschichte zeigt...';
      expect(BrpPage4Detector.shouldBlock(text), isTrue);
    });

    test('blockiert Text mit mehreren Anamnese-Keywords im BRP-Kontext', () {
      const text = '''
BRP - Behandlungs- und Rehabilitationsplan
Psychiatrische Anamnese:
Ersterkrankung im Jahr 2015. Mehrere stationäre Aufenthalte.
Krankheitsverlauf zeigt rezidivierende Episoden.
''';
      expect(BrpPage4Detector.shouldBlock(text), isTrue);
    });

    test('warnt bei einzelnen Keywords im BRP-Kontext', () {
      const text = 'Im BRP wurde die Krankengeschichte dokumentiert.';
      final warnings = BrpPage4Detector.detect(text);
      expect(warnings, isNotEmpty);
    });

    test('blockiert NICHT normalen Berichtstext', () {
      const text = '''
Der Klient nimmt regelmäßig an der Tagesstruktur teil.
Die Teilhabe im Bereich Kommunikation hat sich verbessert.
Empfehlung: Beibehaltung der aktuellen FLS.
''';
      expect(BrpPage4Detector.shouldBlock(text), isFalse);
      expect(BrpPage4Detector.detect(text), isEmpty);
    });

    test('blockiert NICHT Informationsbericht mit Diagnose-Erwähnung', () {
      const text = '''
Diagnosen: F32.1, F60.3
Die Auswirkungen der depressiven Episode auf die Teilhabe zeigen sich
in eingeschränkter Tagesstruktur.
''';
      expect(BrpPage4Detector.shouldBlock(text), isFalse);
    });
  });
}
