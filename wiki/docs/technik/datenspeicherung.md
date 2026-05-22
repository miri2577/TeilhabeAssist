# Datenspeicherung

Alle App-Daten leben in **Hive-Boxen**, einer Key-Value-Datenbank im
Application-Support-Verzeichnis des jeweiligen OS. Sensible Boxen sind
mit AES-256-CBC verschlüsselt; der jeweilige Schlüssel liegt im
OS-Keystore.

## Speicherorte je OS

| OS | Hive-Pfad |
| --- | --- |
| Windows | `%APPDATA%\teilhabe_assist\` |
| macOS | `~/Library/Containers/de.mirkorichter.teilhabe-assist/Data/Documents/` |
| Linux | `~/.local/share/teilhabe_assist/` |
| Android | `<app>/files/` |
| iOS | `<app>/Documents/` |

Pro Box wird eine Datei `<boxName>.hive` (Daten) und `<boxName>.lock`
(Concurrency) angelegt.

## Liste aller Hive-Boxen

| Box | Verschlüsselt | Inhalt | Code-Stelle |
| --- | --- | --- | --- |
| `auth_data` | Nein (enthält Hash + Salt, kein Klartext-Passwort) | Passwort-Hash, Salt, Iterationen, Failed-Attempts-Counter, Lockout-Ende | `lib/features/auth/auth_service.dart` |
| `app_settings_encrypted` | **Ja** (AES) | API-Keys (Anthropic, OpenAI), Provider, Modell, Custom-Prompts | `lib/core/storage/settings_storage.dart` |
| `pseudonym_mappings` | **Ja** (AES) | `reportId → List<PseudonymMapping>` | `lib/core/storage/secure_storage.dart` |
| `audit_log` | Nein (Hash-Chain schützt vor Manipulation) | Log-Events mit prev_hash/hash | `lib/core/storage/audit_log.dart` |
| `user_dictionary` | **Ja** | gelernte Namen + excluded Words | `lib/features/pseudonymization/engine/user_dictionary.dart` |
| `report_drafts` | **Ja** | in-Bearbeitung-Berichte | `lib/features/report_editor/services/draft_storage.dart` |
| `signature_store` | **Ja** | Datenschutz-Signaturen | `lib/features/privacy/signature_store.dart` |
| `report_templates` | **Ja** | Träger-/Fachkraft-spezifische Templates | `lib/features/report_editor/services/template_storage.dart` |
| `app_display_settings` | Nein | Theme, Schriftgröße | `lib/core/theme/app_settings_provider.dart` |
| `app_settings_key` (Legacy) | Nein | Alter Box-Key — wird beim Update gelöscht | wird automatisch migriert |

**Faustregel:** Alles, was Sozialdaten oder geheime Identifikatoren
(API-Keys, Mappings) enthält, ist AES-verschlüsselt. Konfigurations- und
Authentifizierungs-Daten ohne PII liegen unverschlüsselt, sind aber
durch die OS-User-Sandbox geschützt.

## Encryption-Key-Lebenszyklus

```
┌──────────────────────────────────────────────────────┐
│ Erststart                                            │
│                                                      │
│ Random.secure() → 256-Bit Box-Key                    │
│ flutter_secure_storage.write(keychain_key, key)      │
│ HiveAesCipher(key) → openBox(...)                    │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ Folgestart                                           │
│                                                      │
│ flutter_secure_storage.read(keychain_key) → key      │
│ HiveAesCipher(key) → openBox(...)                    │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ Migration aus Legacy-Format (< 0.2.0)                │
│                                                      │
│ Wenn Keystore leer aber app_settings_key.box exists: │
│   key = base64Decode(legacyBox.get('enc_key'))       │
│   flutter_secure_storage.write(keychain_key, key)    │
│   Hive.deleteBoxFromDisk('app_settings_key')         │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ Reset (Settings → "Alle Daten löschen")              │
│                                                      │
│ flutter_secure_storage.delete(keychain_key)          │
│ Hive.deleteFromDisk(...)                             │
└──────────────────────────────────────────────────────┘
```

Pro Box (Settings, Pseudonym-Mappings, …) gibt es einen **eigenen**
Keystore-Eintrag, damit ein versehentlicher Settings-Reset nicht die
Pseudonym-Mappings unlesbar macht (und umgekehrt).

## Größenordnungen

| Daten | Typische Größe |
| --- | --- |
| Audit-Log-Eintrag | ~250 B |
| Pseudonym-Mapping je Bericht | 0,5 – 5 KB |
| Report-Draft | 2 – 20 KB |
| User-Dictionary-Eintrag | ~50 B |

Eine Fachkraft mit 200 Berichten/Jahr nutzt nach 5 Jahren typischerweise
2–10 MB Disk.

## Backup

> ⚠️ **Wichtig:** Wenn der OS-Keystore-Eintrag verloren geht (z.B. neue
> Windows-Installation, Profil-Wiederherstellung), sind die
> verschlüsselten Boxen **unwiderruflich nicht mehr lesbar**.

### Empfohlene Strategie

1. **Disk-Backup** über das Betriebssystem (Windows-Sicherung, Time
   Machine, restic) — sichert die Hive-Files.
2. **Keystore-Export** ist OS-abhängig:
   - Windows: DPAPI ist an die User-SID + Maschine gebunden — Backup
     bringt nur etwas, wenn die Wiederherstellung auf demselben User
     auf demselben Gerät passiert. Cross-Device-Recovery: manuell die
     Keys aus der App exportieren (Future-Feature, siehe Roadmap).
   - macOS: Keychain kann als `.keychain-db`-File mitgesichert werden.
   - Linux: `~/.local/share/keyrings/` lässt sich kopieren.

### Was NICHT in ein Backup gehört

| Datei | Begründung |
| --- | --- |
| Roher `.hive`-File ohne Keystore | Unbrauchbar — wirkt wie verschlüsselter Müll |
| API-Keys als Klartext | Verstoß gegen Provider-AGB, Risiko bei Backup-Diebstahl |

### Reine Mapping-Exports

Für besondere Fälle (z.B. wenn ein Bericht in einem anderen
FEGH-Bericht-Profil weiterbearbeitet werden soll) gibt es
`SecureStorage.exportToJson(reportId)` und `importFromJson` — als
JSON-Datei, die manuell übertragen werden kann. Diese Exporte sind
**unverschlüsselt** und sollten nur über sichere Kanäle transportiert
werden.

## Auf Disk löschen

`DataResetService.resetAll()` löscht:

- Alle Hive-Boxen vom Disk
- Alle Einträge im OS-Keystore
- Die `learned_names`-Lerndaten
- Die Datenschutz-Signatur
- Die Berichts-Drafts
- Die Custom-Prompts

Nach dem Reset startet die App so, als wäre sie frisch installiert —
inklusive Lock-Screen-Setup-Modus.

> Achtung: Audit-Log-Reset ist Teil dieser Operation. Wenn der DSB
> einen Audit-Track braucht, **vorher exportieren**.

## Hive-Limitierungen

- **Keine Transaktionen** — Hive ist nicht ACID. Bei einem Crash mitten
  in einem Multi-Box-Write kann Inkonsistenz entstehen. Die App
  minimiert das, indem zusammenhängende Writes pro Box gebündelt sind.
- **Box-Size-Limit** — Praktisch keine Obergrenze, aber große Boxen
  (>50 MB) verlangsamen Start.
- **Keine Volltextsuche** — Suchanfragen laufen im Memory über
  `box.values`.

## Tools für Power-User

Für Debugging (nur in lokalen Builds):

```bash
# Listet alle Boxen mit Pfaden und Größen
flutter run -d windows
> Einstellungen → Über → Box-Info anzeigen   (DEBUG-Builds)
```

Plus: Drittanbieter-Tools wie [hive_inspector] können in Release-Builds
**nicht** verwendet werden — die Encryption verhindert das.

[hive_inspector]: https://pub.dev/packages/hive_flutter
