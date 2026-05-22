# FEGH-Bericht

KI-gestützte Berichterstellung für die **Eingliederungshilfe (Berlin)** — Teil
der **FEGH-Suite**.

FEGH-Bericht unterstützt Fachkräfte bei der Erstellung des Berliner
**Informationsberichts (Vorlage 1.01)**. Stichpunkte und Vorberichte werden
**lokal pseudonymisiert**, an ein LLM (Anthropic Claude oder OpenAI GPT)
gesendet und nach Rückkehr re-identifiziert — die Zuordnungstabelle
**verlässt nie das Gerät**.

!!! info "Aktuelle Version"
    Stand: Mai 2026 · v0.2.x · Branch `master`

## Was ist neu

- **Strukturierte JSON-Schemas** für Informationsbericht (Kompakt v1.01
  und TIB ausführlich) — kein Markdown-Parsing mehr, sondern Tool-use bei
  Anthropic und JSON-Schema bei OpenAI.
- **Editierbare AcroForm-PDFs** mit Träger-Logo im Header. Jedes
  Teilhabeziel auf einer eigenen Seite, Sub-Sektionen pro Schema-Key.
- **Audit-Log mit Ed25519-Signatur** — Träger-Schlüsselpaar (Setup-Wizard,
  Generierung oder Import), signierter JSON-Export für Aufsichtsbehörde
  oder DSB. Externer Python-Verifier in `tools/`.
- **Stammdaten als Pflichtfelder** mit Autocomplete (Leistungstyp /
  Leistungserbringer aus Liste, DatePicker in Deutsch).
- **In-App-Audit-Log-Viewer** mit Filtern und Kettenprüfung.
- Behandlungs- und Rehabilitationsplan entfernt — diese Vorlage ist
  nicht mehr zulässig. Der Fokus liegt vollständig auf dem Informationsbericht.

## Schnellzugriff

### Anleitung
- [Quickstart](anleitung/quickstart.md) — In zehn Minuten zum ersten Bericht
- [Benutzerhandbuch](anleitung/benutzerhandbuch.md) — Funktionsübersicht aller Screens
- [Berichterstellungs-Flow](anleitung/berichterstellung.md) — Was passiert bei der Generierung
- [PDF-Export](anleitung/pdf-export.md) — Editierbares PDF mit Träger-Logo
- [Troubleshooting](anleitung/troubleshooting.md) — Häufige Probleme

### Datenschutz und Sicherheit
- [Datenschutzmodell](datenschutz/datenschutz.md) — DSGVO-konforme Architektur
- [Pseudonymisierung](datenschutz/pseudonymisierung.md) — Wie personenbezogene Daten ersetzt werden
- [Sicherheitsmodell](datenschutz/sicherheitsmodell.md) — AES-256, PBKDF2, OS-Keystore
- [Audit-Log](datenschutz/audit-log.md) — SHA-256-Hash-Chain, Viewer, Export
- [Audit-Log Signatur](datenschutz/audit-log-signing.md) — Ed25519-Signaturschlüssel
  (auch für andere FEGH-Apps wiederverwendbar)

### Technik
- [Architektur](technik/architektur.md) — App-Aufbau und Modulgrenzen
- [Datenspeicherung](technik/datenspeicherung.md) — Hive-Boxen, OS-Keystore
- [LLM-Provider](technik/llm-provider.md) — Anthropic + OpenAI mit Tool-use
- [Region-Konfiguration](technik/region-konfiguration.md) — Berlin-spezifische Defaults
- [Migration](technik/migration.md) — Versionsstand und Breaking Changes
- [Testing](technik/testing.md) — Test-Suite und Coverage
- [Entwicklungs-Setup](technik/entwicklungs-setup.md) — Lokales Setup

## FEGH-Suite

| App                                                                    | Zweck                                                | Status |
|------------------------------------------------------------------------|------------------------------------------------------|--------|
| **FEGH-Bericht** (diese App)                                           | KI-gestützte Informationsberichte                    | Beta   |
| **[FEGH-Verwaltung](https://miri2577.github.io/FEGH-Verwaltung/)**     | Personalverwaltung, Dienstplanung, Kapazitätsplanung | Beta   |
| **[FEGH-Dokumentation](https://miri2577.github.io/FEGH-Dokumentation/)** | Klientenverwaltung, Termine, Fachleistungsstunden    | Beta   |

## Technische Eckdaten

| Aspekt           | Wert                                                                       |
|------------------|----------------------------------------------------------------------------|
| Framework        | Flutter (Stable Channel)                                                   |
| Sprache          | Dart 3.9+                                                                  |
| State Management | Riverpod 2.x                                                               |
| Routing          | go_router                                                                  |
| Storage          | Hive (AES-256-CBC)                                                         |
| Keystore         | flutter_secure_storage (DPAPI / Keychain / AndroidKeystore)                |
| KDF              | PBKDF2-HMAC-SHA256, 600 000 Iterationen (OWASP 2023)                       |
| Audit-Signatur   | Ed25519 (RFC 8032) — Träger-Schlüsselpaar im OS-Keystore                   |
| Plattformen      | Windows · macOS · Linux Desktop                                            |
| LLM-Provider     | Anthropic Claude (Opus 4.7 / Sonnet 4.6 / Haiku 4.5), OpenAI GPT-5.x / 4o  |
| Lizenz           | AGPL-3.0-or-later                                                          |
