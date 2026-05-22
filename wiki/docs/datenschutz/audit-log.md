# Audit-Log

Das Audit-Log dokumentiert alle sicherheitsrelevanten Aktionen der App
und dient als Nachweis für Datenschutzbeauftragte und Aufsichtsbehörden.
Es ist als **SHA-256-Hash-Chain** implementiert und kann optional mit
einem **Ed25519-Träger-Signaturschlüssel** signiert werden.

Ausführliche Spezifikation inklusive Schlüssel-Setup und Verifikation
siehe **[Audit-Log Signatur](audit-log-signing.md)**.

## Was wird protokolliert?

Alle Events sind in `AuditEvent` als Factory-Methoden definiert
(`lib/core/storage/audit_log.dart`):

| Event                  | Wann                                         | Details (Auszug)                                                                  |
|------------------------|----------------------------------------------|-----------------------------------------------------------------------------------|
| `password_set`         | Erststart oder Passwort-Wechsel              | —                                                                                 |
| `login_success`        | Erfolgreiche Anmeldung                       | —                                                                                 |
| `login_failed`         | Fehleingabe                                  | —                                                                                 |
| `login_locked`         | Rate-Limit erreicht                          | `lockSeconds`                                                                     |
| `signature_created`    | Datenschutzerklärung unterzeichnet           | `userName`, `policyHash`                                                          |
| `report_generated`     | Nach erfolgreichem LLM-Aufruf                | `mappingCount`, `model`, `reportType`, `inputTokens`, `outputTokens`, `costUsd`   |
| `api_key_validated`    | Beim Test eines neuen API-Keys               | `provider`                                                                        |
| `data_reset`           | Voll-Reset über Einstellungen                | `protectedBoxes`                                                                  |
| `dictionary_exported`  | Export des Wörterbuchs                       | `entries`                                                                         |
| `dictionary_imported`  | Import des Wörterbuchs                       | `imported`                                                                        |
| `pseudonymization_run` | Bei jedem Pseudonymizing-Lauf                | `replacements`, `warnings`                                                        |
| `key_generated`        | Neuer Audit-Schlüssel im Setup-Wizard erzeugt | `fingerprint`                                                                     |
| `key_imported`         | Bestehender Audit-Schlüssel als PEM importiert | `fingerprint`                                                                     |
| `key_rotated`          | Audit-Schlüssel ausgetauscht                 | `oldFingerprint`, `newFingerprint`                                                |

**Keine personenbezogenen Daten** landen im Audit-Log — nur Zähler,
Modell-IDs, Provider-Namen, Fingerprints und Zeitstempel.

## Kontextfelder pro Eintrag

Seit der Forensik-Erweiterung trägt jeder Eintrag zusätzlich:

| Feld         | Quelle                                         | Zweck                                                          |
|--------------|------------------------------------------------|----------------------------------------------------------------|
| `userName`   | Aus der Datenschutz-Signatur                   | Wer hat die Aktion ausgeführt                                  |
| `deviceId`   | UUID v4, beim ersten Start persistent erzeugt  | Welches Gerät                                                  |
| `appVersion` | `package_info_plus` (z.B. `0.2.0+2`)           | Welcher Build                                                  |
| `hostname`   | `Platform.localHostname`                       | Welcher Rechner (bei mehreren Mitarbeitern an mehreren Geräten) |

Die Felder kommen aus `AuditContext` (siehe `lib/core/audit/audit_context.dart`)
und werden in `AuditLog.log()` automatisch in jeden Eintrag eingesetzt.

## Eintrags-Format

```jsonc
{
  "timestamp": "2026-05-22T07:25:13.221Z",
  "action": "report_generated",
  "details": {
    "mappingCount": 18,
    "model": "claude-sonnet-4-6",
    "reportType": "informationsbericht",
    "inputTokens": 2845,
    "outputTokens": 1612,
    "costUsd": 0.018
  },
  "userName": "Mirko Richter",
  "deviceId": "8f29a3c1-1b4c-4d0a-9d3e-5b6e7f8a9c0d",
  "appVersion": "0.2.0+2",
  "hostname": "dasi-fachkraft-04",
  "prev_hash": "0a1b2c3d…",
  "hash":      "fedcba98…"
}
```

## Hash-Chain

```
Eintrag 0:   prev_hash = GENESIS (64x "0")
             hash      = SHA-256(canonical_json(payload_0))

Eintrag 1:   prev_hash = hash(0)
             hash      = SHA-256(canonical_json(payload_1))

Eintrag 2:   prev_hash = hash(1)
             hash      = SHA-256(canonical_json(payload_2))
...
```

`canonical_json` ist eine deterministische JSON-Serialisierung mit
sortierten Keys. Damit hängt der Hash nur vom Inhalt ab, nicht von der
Reihenfolge der Felder.

## Manipulationen erkennen

`AuditLog.verifyChain()` läuft die Kette von vorne nach hinten ab und
prüft pro Eintrag:

1. `prev_hash` stimmt mit dem `hash` des Vorgängers überein?
2. `hash` ist tatsächlich der SHA-256 über den restlichen Inhalt?

Bei Fehlern wird ein Fehlertext zurückgegeben:

| Fehler                                              | Bedeutung                                                                          |
|-----------------------------------------------------|------------------------------------------------------------------------------------|
| `Eintrag N: prev_hash bricht die Kette`             | Ein vorhergehender Eintrag wurde gelöscht oder seine Reihenfolge geändert.         |
| `Eintrag N: Hash stimmt nicht — Manipulation möglich` | Der Inhalt des Eintrags wurde editiert.                                            |

## In-App-Viewer

Unter *Einstellungen → Datenschutz → **Audit-Log ansehen*** öffnet sich
ein Viewer mit:

- Liste aller Einträge (neueste zuerst)
- **Filter-Chips** nach Event-Typ (Bericht, Login, Pseudonymisierung …)
- **Datums-Filter** (Heute / 7 Tage / 30 Tage / Alle)
- AppBar-Button **„Chain prüfen"** — startet `verifyChain()` und zeigt
  grün/rot-Dialog
- AppBar-Button **„Exportieren"** — siehe unten

## Export

Der Export liefert je nach Konfiguration:

| Status                                | Format                          |
|---------------------------------------|---------------------------------|
| Kein Audit-Schlüssel eingerichtet     | Plain-JSON mit Hash-Chain       |
| Audit-Schlüssel im Setup-Wizard aktiv | JSON mit Hash-Chain **und** Ed25519-Detached-Signatur + Public-Key + Fingerprint |

Beispiel (signiert):

```jsonc
{
  "appName": "FEGH-Bericht",
  "appVersion": "0.2.0+2",
  "exportedAt": "2026-05-22T07:25:00.221Z",
  "chainValid": true,
  "algorithm": "Ed25519",
  "publicKeyFingerprint": "5D:3C:2E:1B:7A:8F:90:23",
  "publicKey": "MCowBQYDK2VwAyEA…",
  "entries": [ /* … */ ],
  "signature": "5RZ7gMt…"
}
```

Der externe Python-Verifier in `tools/verify_audit_export.py` prüft
Hash-Chain **und** Signatur und gibt OK/FAIL aus. Aufruf:

```
pip install cryptography
python verify_audit_export.py audit_export.json [traeger_public.pem]
```

## Was passiert beim `data_reset`?

Das Audit-Log überlebt jeden Factory-Reset **absichtlich**. Der
`DataResetService` führt eine ausdrückliche Schutzliste:

| Geschützte Box  | Begründung                                                          |
|-----------------|---------------------------------------------------------------------|
| `audit_log`     | Forensischer Nachweis, gesetzlich erforderlich                      |
| `audit_context` | Device-ID muss konstant bleiben, sonst Bruch in der Zuordnung       |
| `audit_keys`    | Träger-Signaturschlüssel — sonst werden alte Exports unverifizierbar |

Vor dem Reset wird ein `data_reset`-Event mit `protectedBoxes` geschrieben,
sodass die Hash-Chain durchgängig bleibt — auch nach dem Reset.

## Best-Practice

1. **Audit-Schlüssel beim Setup einrichten** — Variante A (per OpenSSL
   beim DSB) oder Variante B (In-App-Wizard mit PEM-Backup). Details:
   [Audit-Log Signatur](audit-log-signing.md).
2. **Monatlich exportieren** und auf einem schreibgeschützten Medium
   (USB-Stick mit Schreibsperre, Cloud-Bucket mit WORM-Policy) ablegen.
3. **Stichproben verifizieren** — externe Python-CLI nutzen, Hash-Chain
   und Signatur müssen beide grün sein.
4. **Bei Verdacht auf Manipulation** sofort exportieren, verifizieren,
   und den DSB informieren.
