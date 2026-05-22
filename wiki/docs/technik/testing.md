# Testing

## Aktuelle Test-Suite

```
test/
├── features/
│   ├── pseudonymization/
│   │   ├── brp_page4_detector_test.dart
│   │   └── pseudonym_engine_test.dart    ← 48 Tests, Hauptlast
│   └── report_editor/
│       ├── fls_data_test.dart            ← Berechnung Auslastungsquote
│       └── quality_checker_test.dart
└── widget_test.dart
```

Stand Mai 2026: **49 Tests, alle grün** (`flutter test`).

## Was getestet ist

| Bereich | Coverage | Lücken |
| --- | --- | --- |
| Pseudonymisierungs-Engine | Hoch | Performance auf großen Texten |
| ICD-10-Whitelist | Mittel | Edge-Cases mit B12-Vitaminen etc. |
| QualityChecker | Mittel | Trägerspezifische Regeln |
| FLS-Berechnung | Mittel | Grenzwerte |
| Storage (Hive) | **Keine** | Migration, Reset, Backup-Restore |
| AuthService | **Keine** | KDF, Rate-Limiting, Constant-Time |
| Audit-Log Hash-Chain | **Keine** | Manipulationserkennung, Genesis-Hash |
| LLM-Adapter | **Keine** | Mock-Server, Streaming-Decoder |
| UI / Generate-Flow | **Keine** | Pflicht-Preview, Zwei-Häkchen, Timer |

Die zentralen Lücken sind Storage und Auth — beides ist
sicherheitsrelevant und sollte mit Tests abgedeckt werden.

## Tests ausführen

```bash
flutter test                           # alle
flutter test --reporter expanded       # verbose
flutter test --name "Datumsformate"    # Filter über Beschreibung
flutter test --coverage                # mit Coverage
```

## Beispiel: einen neuen Pseudonymisierungs-Test schreiben

```dart
// test/features/pseudonymization/pseudonym_engine_test.dart

group('Datum mit Monatsname', () {
  test('erkennt "15. März 2024"', () {
    final engine = PseudonymEngine();
    final result = engine.pseudonymize('Geboren am 15. März 2024.');
    expect(result.cleanText, contains('[DATUM_'));
    expect(result.cleanText, isNot(contains('März 2024')));
  });

  test('erkennt nur Monat + Jahr', () {
    final engine = PseudonymEngine();
    final result = engine.pseudonymize('Beginn im März 2024.');
    expect(result.cleanText, contains('[DATUM_'));
  });

  test('matcht nicht "Mar 2024" (ohne deutsche Schreibung)', () {
    // Sollte FN sein — wir matchen nur deutsche Monatsnamen
    final engine = PseudonymEngine();
    final result = engine.pseudonymize('Start in Mar 2024.');
    expect(result.cleanText, contains('Mar 2024'));
  });
});
```

## AuthService testen (Vorschlag)

Aktuell nicht im Repo — sollte hinzugefügt werden:

```dart
// test/features/auth/auth_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:teilhabe_assist/features/auth/auth_service.dart';

void main() {
  setUpAll(() {
    Hive.init('./.test_data');
  });

  setUp(() async {
    await Hive.deleteBoxFromDisk('auth_data');
  });

  test('Erststart: hasPassword == false', () async {
    final svc = AuthService();
    await svc.init();
    expect(svc.hasPassword, isFalse);
  });

  test('setPassword + validatePassword grün', () async {
    final svc = AuthService();
    await svc.init();
    await svc.setPassword('CorrectHorseBattery!');
    expect(svc.validatePassword('CorrectHorseBattery!'), isTrue);
    expect(svc.validatePassword('falsch'), isFalse);
  });

  test('Rate-Limit nach 5 Fehlversuchen', () async {
    final svc = AuthService();
    await svc.init();
    await svc.setPassword('ok');
    for (var i = 0; i < 5; i++) {
      svc.validatePassword('falsch');
    }
    expect(svc.isLockedOut, isTrue);
    expect(svc.lockoutSeconds, greaterThan(0));
  });

  test('Rate-Limit überlebt Re-init (Persistenz)', () async {
    final svc = AuthService();
    await svc.init();
    await svc.setPassword('ok');
    for (var i = 0; i < 5; i++) {
      svc.validatePassword('falsch');
    }
    await svc.close();

    final svc2 = AuthService();
    await svc2.init();
    expect(svc2.isLockedOut, isTrue);
  });

  test('Legacy 100k-Hash wird auf 600k migriert', () async {
    // Hand-roll a legacy hash in box
    final box = await Hive.openBox<String>('auth_data');
    // ... salt + pbkdf2 mit 100k vorbereiten und in Box schreiben
    await box.put('password_iterations', '100000');

    final svc = AuthService();
    await svc.init();
    expect(svc.validatePassword('legacy-pw'), isTrue);
    expect(box.get('password_iterations'), '600000');
  });
}
```

## Audit-Log-Chain testen (Vorschlag)

```dart
test('verifyChain meldet Manipulation', () async {
  final log = AuditLog();
  await log.init();
  await log.log(AuditEvent.passwordSet());
  await log.log(AuditEvent.loginSuccess());

  expect(log.verifyChain(), isNull);   // OK

  // Manipulation: ersten Eintrag in der Hive-Box editieren
  final box = Hive.box<String>('audit_log');
  final tampered = jsonDecode(box.getAt(0)!) as Map<String, dynamic>;
  tampered['details'] = {'oh': 'no'};
  await box.putAt(0, jsonEncode(tampered));

  expect(log.verifyChain(), contains('Hash stimmt nicht'));
});
```

## LLM-Adapter testen (Vorschlag)

Mit `package:dio_mock_adapter`:

```dart
test('AnthropicAdapter parst Response korrekt', () async {
  final dio = Dio();
  final mock = DioAdapter(dio: dio);
  mock.onPost('/v1/messages', (req) {
    req.reply(200, {
      'id': 'msg_123',
      'model': 'claude-sonnet-4-6',
      'stop_reason': 'end_turn',
      'usage': {'input_tokens': 100, 'output_tokens': 50},
      'content': [
        {'type': 'text', 'text': 'Hallo Welt'}
      ],
    });
  });

  final adapter = AnthropicAdapter.withDio(dio);
  final response = await adapter.generateReport(ReportRequest(...));
  expect(response.text, 'Hallo Welt');
  expect(response.inputTokens, 100);
});
```

## Widget-Tests

`test/widget_test.dart` ist aktuell der Default-Stub. Für sinnvolle
Widget-Tests:

- `LockScreen` — Setup-Modus, Login-Modus, Strength-Indicator
- `GenerateScreen` — Pseudonymize → Review → Pflicht-Confirms → Generate
- `PreviewWidget` — Hervorhebung, Warning-Anzeige

Beispiel:

```dart
testWidgets('LockScreen Setup zeigt Stärke-Indikator', (tester) async {
  final authService = MockAuthService();
  when(authService.hasPassword).thenReturn(false);

  await tester.pumpWidget(
    MaterialApp(
      home: LockScreen(
        authService: authService,
        onAuthenticated: () {},
      ),
    ),
  );

  await tester.enterText(find.byType(TextField).first, 'CorrectHorse42!');
  await tester.pump();
  expect(find.text('Stark'), findsOneWidget);
});
```

## Integration Tests

Aktuell **keine**. Geplant: `integration_test` für den
End-to-End-Flow:
1. Erststart → Passwort vergeben
2. Datenschutz unterzeichnen
3. API-Key hinterlegen (Mock-Backend)
4. Bericht erfassen
5. Generieren
6. Vorschau bestätigen
7. PDF exportieren

## CI

Aktuell **kein CI**. Vorschlag GitHub Actions:

```yaml
# .github/workflows/test.yml
name: test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
```
