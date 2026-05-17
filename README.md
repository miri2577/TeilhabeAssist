# TeilhabeAssist

KI-gestützte Berichterstellung für die Eingliederungshilfe (Berlin).

TeilhabeAssist unterstützt Fachkräfte bei der Erstellung von
**Informationsberichten** und **Behandlungs- und Rehabilitationsplänen (BRP,
4. Berliner Fassung)**. Stichpunkte und Vorberichte werden lokal
pseudonymisiert, an ein LLM gesendet und nach Rückkehr re-identifiziert —
**die Zuordnungstabelle verlässt nie das Gerät**.

## Sicherheits- und Datenschutzmodell

| Schicht | Schutz |
| --- | --- |
| App-Start | Lock-Screen mit Passwort, PBKDF2-HMAC-SHA256 (600.000 Iterationen, 256-Bit Salt aus OS-Entropie), persistentes Rate-Limiting |
| API-Keys | Hive-Box AES-256-CBC, Schlüssel im OS-Keystore (Windows DPAPI / macOS Keychain / Android Keystore) |
| Pseudonymisierungs-Mappings | Hive-Box AES-256-CBC, Schlüssel im OS-Keystore |
| Audit-Log | SHA-256-Hash-Chain, Manipulation einzelner Einträge ist beim Export detektierbar |
| API-Versand | Pflicht-Bestätigung in der UI; bei Engine-Warnungen zusätzlich ein zweites Häkchen |
| Übertragung | TLS 1.3 zum API-Provider, ausschließlich pseudonymisierter Text |

Detaillierte Risikoinformation siehe Datenschutzerklärung in der App
(Einstellungen → Datenschutz & Recht), insbesondere § 4.3 zur Grenze der
automatischen Pseudonymisierung.

## Unterstützte LLM-Provider

- **Anthropic Claude** — Opus 4.7, Sonnet 4.6, Haiku 4.5
- **OpenAI** — GPT-5.5, GPT-5.4 (sowie -mini / -nano), o3, GPT-4o

Die Provider-Auswahl, das Modell und der API-Key werden lokal pro
Installation hinterlegt.

## Entwicklung

```bash
flutter pub get
flutter run -d windows   # oder macos / linux
flutter test
```

Build-Targets: Windows, macOS, Linux Desktop (siehe `pubspec.yaml`).

## Lizenz

[AGPL-3.0-or-later](LICENSE) — Netzwerk-Nutzungsschutz: wer die App
modifiziert oder als Dienst bereitstellt, muss seine Änderungen unter
derselben Lizenz veröffentlichen.
