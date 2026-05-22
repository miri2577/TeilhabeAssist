# Migration & Versionen

Wenn sich Datenbank-Schema, KDF-Parameter oder Verschlüsselungs-Logik
zwischen Releases ändern, läuft beim ersten Start nach dem Update eine
**Migrationsroutine**. Dieser Abschnitt dokumentiert alle Migrationen,
damit Updates verlustfrei bleiben.

## Versions-Schema

`pubspec.yaml` hält die Version im Format `<major>.<minor>.<patch>+<build>`:

```yaml
version: 0.2.0+2
```

- **Major** — Breaking Changes oder grobe Konzept-Updates.
- **Minor** — Neue Features, KDF-Parameter, neue Boxen, neue Pflicht-Migrationen.
- **Patch** — Bugfixes, kleinere Verbesserungen, keine Migration.
- **Build** — Inkrementeller Counter für Store-Distribution.

## Migrationsmechanismen

### 1. Hash-Migration im AuthService

Beim Login mit einem alten Hash (< 600 000 PBKDF2-Iterationen):

```dart
if (valid && iterations < _currentIterations) {
  _upgradeHash(password);
}
```

- Salt wird neu generiert (frische 32 Byte aus OS-Entropie).
- Hash mit 600 000 Iterationen neu berechnet.
- `password_iterations` in der Box auf 600 000 gesetzt.

**Transparent für den User** — er meldet sich normal an, die App
upgradet im Hintergrund.

### 2. Keystore-Migration aus Legacy-Box

`SettingsStorage._migrateLegacyKey()`:

```dart
if (existing == null && Hive.boxExists('app_settings_key')) {
  final legacy = await loadFromLegacyBox();
  await secure.write(key: keychainKey, value: legacy);
  await Hive.deleteBoxFromDisk('app_settings_key');
}
```

Bei Versionen vor 0.2.0 lag der AES-Box-Schlüssel in einer
unverschlüsselten Hive-Box `app_settings_key`. Nach dem Update:

1. App startet, prüft den OS-Keystore — leer.
2. Prüft die Legacy-Box — findet den Schlüssel.
3. Schreibt ihn in den OS-Keystore (DPAPI / Keychain).
4. Löscht die Legacy-Box vom Disk.

### 3. Audit-Log-Format (Hash-Chain)

Vor 0.2.0: Einträge **ohne** `hash`/`prev_hash`. `verifyChain()` würde
diese Einträge als "Legacy-Format" markieren.

**Strategie:** Bestehende Einträge werden **nicht** retroaktiv gehasht
(das wäre ohnehin nicht verifizierbar). Neue Einträge starten eine
neue Hash-Chain ab dem ersten Eintrag nach dem Update.

`verifyChain()` meldet beim ersten Legacy-Eintrag den entsprechenden
Fehlertext. Der DSB sieht in der exportierten JSON-Datei:

```jsonc
{
  "chainValid": false,
  "entries": [
    { "action": "report_generated", "timestamp": "…" },   ← Legacy
    { "action": "report_generated", "timestamp": "…", "hash": "..." },
    …
  ]
}
```

Empfohlene Aktion vom DSB: Manueller Import der Legacy-Einträge als
"vor Migration" und Vertrauen auf Träger-interne Audit-Quellen.

## Release-Historie

### 0.2.x (Mai 2026) — laufende Beta

**Branding:**
- App umbenannt: `TeilhabeAssist` → **FEGH-Bericht** (Teil der FEGH-Suite
  neben FEGH-Verwaltung und FEGH-Dokumentation).
- Neues Burgunder-Icon, abgestimmt auf die Farben der Suite-Geschwister
  (Lila / Petrol / Cyan).
- Bundle-ID auf `de.miri2577.feghBericht`, Window-Title und PDF-Header
  durchgehend „FEGH-Bericht".

**Output-Pipeline:**
- Strukturierte JSON-Schemas pro Berichts-Variante (Informationsbericht
  Kompakt v1.01 und TIB ausführlich) via Tool-use (Anthropic) bzw.
  `response_format` (OpenAI). Kein Markdown-Parsing mehr.
- PDF-Generator rendert jetzt aus der strukturierten Map: jedes
  Teilhabeziel als eigener atomarer Block, KV-Tabelle multiline, Enum-
  Werte lesbar (`teilweise_erreicht` → „teilweise erreicht").
- AcroForm-editierbare TextFields mit dynamischer Höhe.
- Pro Hauptsektion eine eigene Seite (Hard-Pagebreaks), kein Orphan-
  Heading mehr.
- Träger-Logo-Upload in den Einstellungen.

**Editor:**
- Strukturierte Stammdaten als Pflichtfelder (Kopfdaten + Persondaten),
  Autocomplete für Leistungstyp und Leistungserbringer mit Berliner
  Trägerliste, DatePicker in Deutsch.
- PDF-Import erkennt Berliner Informationsbericht 1.01 und liest
  Metadaten in die Stammdaten ein.
- Editor-Overflow und Draft-Persistenz behoben.

**Audit-Log Forensik-Paket:**
- In-App-Viewer unter *Einstellungen → Datenschutz → Audit-Log ansehen*
  mit Filter-Chips, Datums-Filter, Kettenprüfung und Export-Button.
- Kontextfelder `userName`, `deviceId`, `appVersion`, `hostname` in
  jedem Eintrag.
- `signature_created` enthält jetzt einen `policyHash` der unterzeichneten
  Datenschutzerklärung.
- **Ed25519-Träger-Signaturschlüssel** mit Setup-Wizard (Generieren oder
  Importieren), Public-Key-Export, Schlüssel-Rotation. Signierter
  JSON-Export für den DSB; externer Python-Verifier in `tools/`.
- `DataResetService` schützt `audit_log`, `audit_context` und `audit_keys`
  ausdrücklich vor Löschung; das Reset selbst wird als
  `data_reset`-Event protokolliert.

**Entfernt:**
- BRP (Behandlungs- und Rehabilitationsplan, 4. Berliner Fassung) ist
  nicht mehr zulässig. Code, Schemas, Prompts, Wiki-Seiten und Tests
  vollständig entfernt. `ReportType.brp`, `ModuleType.brp*`,
  `generateBrp()`, `fillBrp()`, `BrpPage4Detector` weg.

**Sicherheits-Hardening (aus 0.1 → 0.2.0):**
- KDF-Parameter von 100 000 auf 600 000 Iterationen (OWASP 2023).
- API-Box-Key umgezogen in OS-Keystore (DPAPI/Keychain).
- Audit-Log-Format um SHA-256-Hash-Chain erweitert.
- Pflicht-Preview mit Mindest-Lesezeit (5 s) und Zwei-Häkchen-
  Bestätigung bei Warnungen.

**Migrationen:**
- AuthService rehasht beim ersten Login automatisch.
- SettingsStorage migriert den Legacy-Key transparent.
- AuditLog beginnt neue Chain ab erstem neuen Eintrag.
- `AuditContext.deviceId` wird beim ersten Start nach Update generiert.

**Bekannte Probleme:**
- Bei extrem alten Installationen (< 0.0.1) kann der Migrationspfad
  fehlschlagen, weil keine Legacy-Box existiert. Lösung: Reset.

### 0.1.x (April 2026)

Initiale öffentliche Version. Pseudonymisierungs-Engine, LLM-Adapter
(Anthropic, OpenAI), Hive-Speicherung, Lock-Screen.

## Migration testen

```dart
// test/migration/v0_1_to_v0_2_test.dart  (Vorschlag)

test('legacy auth box wird auf 600k upgegradet', () async {
  // 1. Setup: schreibe Legacy-Hash mit 100k Iterationen
  final box = await Hive.openBox<String>('auth_data');
  await box.put('password_salt', '...');
  await box.put('password_hash', '...');
  // password_iterations bewusst NICHT setzen

  // 2. Init AuthService (Version 0.2.0)
  final svc = AuthService();
  await svc.init();

  // 3. Login mit korrektem Passwort
  expect(svc.validatePassword('legacy-passwort'), isTrue);

  // 4. Verifiziere: Box enthält jetzt 600k
  expect(box.get('password_iterations'), '600000');
});

test('legacy settings_key wird in Keystore migriert', () async {
  // ...
});

test('audit_log alt + neu mischbar', () async {
  // ...
});
```

## Was passiert bei einem fehlgeschlagenen Update?

Symptome:
- App startet, aber Lock-Screen akzeptiert das Passwort nicht.
- Settings sind weg.
- Berichte sind weg.

Mögliche Ursachen und Maßnahmen:

| Symptom | Ursache | Aktion |
| --- | --- | --- |
| Lock-Screen akzeptiert kein Passwort | `password_iterations` korrupt | Reset → Datenverlust, neuer Setup |
| Settings fehlen | Keystore-Migration fehlgeschlagen | Hive-File auf Disk prüfen, ggf. Legacy-Box manuell wiederherstellen |
| Berichte fehlen | `pseudonym_mappings`-Box-Schlüssel verloren | Kein Recovery — wenn Keystore weg, sind Mappings verloren |
| Audit-Log unsignaturiert | Erwartetes Verhalten nach Migration | DSB informieren, neue Chain ab jetzt |

## Vor einem Major-Update

Empfehlung:

1. **App-Reset durchführen** auf einem Test-Gerät, sicherstellen dass
   Migration funktioniert.
2. **Audit-Log exportieren** und sichern.
3. **API-Key separat notieren** für den Fall, dass Settings nicht
   migrieren.
4. **Berichte ausdrucken oder als PDF exportieren** — sind dann
   plattformunabhängig sicher.

## Schema-Versionierung (geplant)

Aktuell ist das Schema implizit (jede Box hat ihre eigene Migration).
Geplant für 0.3.0: Eine zentrale `schema_version`-Box mit Marker für
jede angewandte Migration. Dann läuft beim Start ein Migrator-Dispatch.
