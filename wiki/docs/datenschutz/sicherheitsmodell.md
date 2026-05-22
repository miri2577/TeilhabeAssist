# Sicherheitsmodell

FEGH-Bericht verarbeitet **Sozial- und Gesundheitsdaten** im Sinne von
§ 67 SGB X und Art. 9 DSGVO. Das Sicherheitsmodell ist mehrschichtig
aufgebaut, mit dem Ziel, dass weder Filesystem-Zugriff allein noch
LLM-Provider-Logs zur De-Identifikation der betroffenen Personen ausreichen.

## Bedrohungsmodell

| Angreifer | Mittel | Schutz durch |
| --- | --- | --- |
| **Schulter-Surfer / Familie** | Physischer Zugang zum Bildschirm | Lock-Screen, App-Sandbox |
| **Dieb eines abgesperrten Geräts** | Filesystem-Zugriff über USB-Boot / Festplatten-Image | Hive-AES, OS-Keystore (DPAPI/Keychain), starkes Lock-Screen-Passwort |
| **Malware im User-Kontext** | Lese- und Schreibrechte auf Files + Memory | DPAPI/Keychain-Schlüssel sind an die OS-Session gebunden, nicht im Klartext im Filesystem |
| **LLM-Provider (Anthropic/OpenAI)** | Speichert API-Inputs in Logs | Pseudonymisierter Text enthält keine Klarnamen, Geburtsdaten, Adressen, Aktenzeichen |
| **US-Behörden (CLOUD Act)** | Zwingt Provider zur Datenherausgabe | Pseudonymisierter Text ist aus Sicht des Providers anonym — Zuordnungstabelle existiert nur lokal |
| **Manipulation des Audit-Logs** | Editiert Hive-Box, um Vorgänge zu verbergen | SHA-256-Hash-Chain — Manipulation einzelner Einträge bricht die Verifikation |

**Nicht im Bedrohungsmodell:** Targeted Malware mit Kernel-Privilegien;
Hardware-Keylogger; Cold-Boot-Angriffe; Side-Channel-Angriffe auf das
OS-Keystore-Modul.

## Schichten

```
┌──────────────────────────────────────────┐
│  Layer 1 – App-Zugang                    │  Lock-Screen, PBKDF2-Hash
├──────────────────────────────────────────┤
│  Layer 2 – Datenschutz-Einwilligung      │  signierte Erklärung, gehasht
├──────────────────────────────────────────┤
│  Layer 3 – Encryption-at-Rest            │  AES-256-CBC für alle Boxen
├──────────────────────────────────────────┤
│  Layer 4 – Key-Storage                   │  OS-Keystore (DPAPI/Keychain)
├──────────────────────────────────────────┤
│  Layer 5 – Pseudonymisierung             │  Engine + Pflicht-Review
├──────────────────────────────────────────┤
│  Layer 6 – Audit                         │  SHA-256-Hash-Chain
└──────────────────────────────────────────┘
```

## Layer 1 — App-Zugang

### Passworthashing

Implementierung in `lib/features/auth/auth_service.dart`.

| Parameter | Wert | Begründung |
| --- | --- | --- |
| KDF | PBKDF2-HMAC-SHA256 | Konservativ, FIPS-konform; Argon2id ist stärker, ist aber in pointycastle nicht stabil verfügbar |
| Iterationen | 600 000 | OWASP-Empfehlung 2023 für PBKDF2-SHA256 |
| Salt-Länge | 32 Byte (256 Bit) | Aus OS-Entropie via `Random.secure()` |
| Output | 32 Byte / Base64 | Direkt mit constant-time-Compare |
| Storage | Hive-Box `auth_data` | `password_hash`, `password_salt`, `password_iterations` |

Bei jedem erfolgreichen Login mit einem Legacy-Hash (`< 600 000` Iterationen)
wird der Hash transparent auf die aktuellen Parameter migriert. Damit
ziehen sich alle alten Installationen ohne User-Aktion auf das aktuelle
Sicherheitsniveau.

### Constant-time Compare

Die Hash-Vergleichsoperation läuft byteweise und akkumuliert die XOR-Differenz
über die volle Länge, ohne early-exit. Das ist Best Practice gegen
Timing-Seitenkanäle, auch wenn die praktische Ausnutzbarkeit bei einer
lokalen Desktop-App gering ist.

```dart
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
```

### Persistentes Rate-Limiting

Fehlversuche werden in `auth_data` persistiert. Damit überlebt die Sperre
einen App-Neustart.

| Fehlversuche | Sperre |
| --- | --- |
| 5–9 | 30 Sekunden |
| ≥ 10 | 5 Minuten |

Bei erfolgreichem Login werden Counter und Sperre gelöscht.

### Passwort-Stärke

| Score | Bezeichnung |
| --- | --- |
| 0–2 | Schwach |
| 3–4 | Mittel |
| 5–6 | Stark |

Der Score zählt einen Punkt je Kriterium: Länge ≥ 10, Länge ≥ 14, Klein-,
Groß-, Ziffer-, Sonderzeichen. **Mindestlänge: 8.** Die App lässt auch
schwache Passwörter zu, weist aber visuell darauf hin.

## Layer 2 — Datenschutz-Einwilligung

`SignatureStore` speichert die Bestätigung mit drei Feldern:

| Feld | Inhalt |
| --- | --- |
| `fullName` | Vollständiger Name der Fachkraft |
| `policyHash` | SHA-256 des angezeigten Datenschutztexts |
| `timestamp` | ISO-8601 |

Beim App-Start wird geprüft, ob `policyHash` zum **aktuell** angezeigten
Text passt. Sobald die Datenschutzerklärung sich ändert (z.B. nach einer
Audit-Runde), wird die Signatur ungültig und die Fachkraft muss neu
bestätigen. Dadurch ist die Einwilligung nachweisbar versionsspezifisch.

## Layer 3 — Encryption at Rest

Alle persistenten Daten liegen in Hive-Boxen, die mit `HiveAesCipher`
(AES-256-CBC) verschlüsselt sind. Die Box-Schlüssel werden **nicht** im
Filesystem gespeichert (siehe Layer 4).

| Box | Inhalt | Sensibilität |
| --- | --- | --- |
| `auth_data` | Hash + Salt + Counter | Hoch |
| `app_settings_encrypted` | API-Keys, Provider-Wahl, Custom-Prompts | Sehr hoch |
| `pseudonym_mappings` | Pseudonym ↔ Originaldaten | Höchst |
| `audit_log` | Metadaten, keine PII | Mittel |
| `user_dictionary` | Gelernte Namen + Excludes | Hoch |
| `report_drafts` | In-Bearbeitung-Berichte | Höchst |
| `signature_store` | Datenschutz-Signaturen | Mittel |
| `app_display_settings` | Theme, Schriftgröße | Niedrig (unverschlüsselt) |

## Layer 4 — Key-Storage

Implementierung in `lib/core/storage/secure_storage.dart` und
`settings_storage.dart`.

### OS-Keystore

| OS | Backend | Eigenschaft |
| --- | --- | --- |
| Windows | DPAPI (Data Protection API) | Schlüssel an Windows-User-SID gebunden |
| macOS | Keychain | Standard-User-Keychain, accessibility=first_unlock |
| iOS | Keychain | first_unlock-Policy |
| Android | EncryptedSharedPreferences + Keystore | AES-GCM mit Hardware-Backed-Key |
| Linux | libsecret (gnome-keyring/kwallet) | Pro Session entsperrt |

### Migration aus dem Legacy-Format

In Versionen < 0.2.0 lag der Hive-Box-Schlüssel **im Klartext** in einer
unverschlüsselten Hive-Box `app_settings_key`. Beim ersten Start nach dem
Update wird:

1. Der OS-Keystore-Eintrag (falls vorhanden) bevorzugt.
2. Bei leerem Keystore wird die Legacy-Box gelesen, ihr Inhalt in den
   Keystore übernommen, die Legacy-Box vom Disk gelöscht.
3. Bei leerer Legacy-Box wird ein frischer 256-Bit-Schlüssel aus OS-Entropie
   erzeugt.

Damit ist die Migration für bestehende Installationen verlustfrei.

### Schlüsselverlust

Wenn der OS-Keystore-Eintrag verloren geht (z.B. Profil-Wiederherstellung
auf einem neuen Gerät), sind alle verschlüsselten Hive-Boxen **nicht
mehr lesbar**. Es gibt keinen Recovery-Mechanismus — die App ist hier
bewusst auf Vorsicht statt Komfort optimiert. Backup-Strategien siehe
[Datenspeicherung § Backup](Datenspeicherung#backup).

## Layer 5 — Pseudonymisierung

Siehe ausführlich [Pseudonymisierungs-Engine](Pseudonymisierung).
Kurzfassung:

1. Regex + Wörterbuch + Lern-Store erkennen direkte Identifikatoren.
2. Eine Vorschau zeigt jeden ersetzten Begriff hervorgehoben.
3. Die Fachkraft muss bestätigen, **bevor** der Text das Gerät verlässt.
4. Bei Engine-Warnungen ist ein **zweites** Häkchen nötig.
5. Eine Mindest-Lesezeit von 5 Sekunden verhindert reflexartiges Durchklicken.

## Layer 6 — Audit-Log

SHA-256-Hash-Chain — siehe eigene Seite [Audit-Log](Audit-Log).

## Kryptographische Bibliotheken

- **pointycastle** für PBKDF2, AES, SHA-256
- **crypto** (offiziell von Dart-Team) für die Audit-Log-Chain
- **FlutterSecureStorage** als OS-Keystore-Wrapper
- **`Random.secure()`** aus `dart:math` als Entropie-Quelle (nutzt
  `BCryptGenRandom` auf Windows, `/dev/urandom` auf POSIX,
  `getrandom()`-Syscall auf Linux ≥ 3.17)

Eigene Krypto-Implementierungen werden **nicht** geschrieben — alle
Operationen laufen über etablierte Bibliotheken.

## Bekannte Einschränkungen

| Einschränkung | Wirkung |
| --- | --- |
| Keine FIDO2 / Hardware-Token-Auth | Single-Factor-Passwort |
| Kein Argon2id | PBKDF2 ist GPU-anfälliger als Argon2id |
| Keine TPM-/Secure-Enclave-Bindung der Box-Keys | Schlüssel sind portabel, an User-SID gebunden, nicht an Hardware |
| Keine Datei-Integritätsprüfung | Hive erkennt korrupte Boxen, schützt aber nicht aktiv vor Manipulation außerhalb des Audit-Logs |
| Memory-Strings | API-Keys liegen kurzzeitig als Klartext im Heap (Dart strings sind nicht clearable) |

## Sicherheits-Audit-Checkliste (für Träger)

1. Wird das App-Passwort regelmäßig geändert? *(empfohlen alle 90 Tage)*
2. Ist das Gerät verschlüsselt? *(BitLocker / FileVault / LUKS)*
3. Ist der Bildschirm bei Abwesenheit gesperrt?
4. Werden die Audit-Logs regelmäßig exportiert und verifiziert? Siehe
   [Audit-Log § Verifikation](Audit-Log#verifikation).
5. Wird die Datenschutzerklärung jährlich überprüft und re-signiert?
6. Gibt es einen Vertretungs-Account? *(Nein — Passwort ist
   personengebunden, das ist beabsichtigt.)*
