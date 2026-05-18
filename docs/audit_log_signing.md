# Audit-Logs & Träger-Signaturschlüssel

**Stand: 2026-05-18**

Dieses Dokument beschreibt, wie ein DSGVO-konformer Audit-Log mit
forensisch belastbarer Signatur in einer FEGH-App (Flutter / Dart)
umgesetzt wird. Die Anleitung ist so geschrieben, dass sie in mehreren
FEGH-Apps (TeilhabeAssist, … andere KI-gestützte Sozialdienst-Tools)
wiederverwendet werden kann.

---

## 1. Ziel

Der Audit-Log dient zwei Zwecken:

1. **Rechenschaftspflicht (DSGVO Art. 5 Abs. 2)** — der Träger weist
   nach, *was wann mit welchen Mitteln* verarbeitet wurde.
2. **Integritätsnachweis (DSGVO Art. 32 Abs. 1 lit. b)** — der Log ist
   nachträglich nicht manipulierbar, ohne dass es auffällt.

Mit einem Träger-Signaturschlüssel kommt eine dritte Eigenschaft hinzu:

3. **Authentizität** — der Empfänger (Aufsicht, Gericht, externer
   Auditor) kann ohne Vertrauen in die App prüfen, dass der Export
   *unverändert vom Träger X* stammt.

---

## 2. DSGVO-Einordnung — was deckt der Log ab, was nicht?

| DSGVO-Artikel                                            | Vom Audit-Log gedeckt? |
|----------------------------------------------------------|------------------------|
| Art. 5 Abs. 2 — Rechenschaftspflicht (Einzelfall)        | **Ja**                 |
| Art. 32 — Integrität & Vertraulichkeit                   | **Ja** (Hash-Chain)    |
| Art. 33/34 — Meldung Datenpanne (Beweismittel)           | **Ja**                 |
| Art. 30 — Verzeichnis Verarbeitungstätigkeiten (VVT)     | Nein — Trägerdokument  |
| Art. 35 — Datenschutz-Folgenabschätzung (DSFA)           | Nein — Trägerdokument  |
| Art. 28 — Auftragsverarbeitungsvertrag (AVV)             | Nein — Vertrag         |
| TOMs — Technische / organisatorische Maßnahmen           | Nein — Trägerdokument  |

**Merksatz:** Der Log ist *ein* Baustein der Compliance, nicht der
ganze Nachweis. Er gehört in die Sammlung beim DSB neben VVT, DSFA,
AVV und TOM-Beschreibung.

---

## 3. Konzeptionelle Architektur

```
┌──────────────────────────────────────────────────────────────┐
│ Audit-Log (innerhalb der App)                                │
│                                                              │
│   Entry n-1: { ts, action, details, prev_hash, hash }        │
│                              │ SHA-256                       │
│                              ▼                               │
│   Entry  n : { ts, action, details, prev_hash, hash }        │
│                              │ SHA-256                       │
│                              ▼                               │
│   Entry n+1: ...                                             │
│                                                              │
│  → Interne Hash-Chain — manipulationssicher *innerhalb*      │
│    eines Exports                                             │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ Export
┌──────────────────────────────────────────────────────────────┐
│ audit_export_2026-05-18.json                                 │
│ {                                                            │
│   "appName": "TeilhabeAssist",                               │
│   "appVersion": "0.2.0+2",                                   │
│   "exportedAt": "2026-05-18T07:25:00Z",                      │
│   "chainValid": true,                                        │
│   "publicKey": "MCowBQYDK2VwAyEA…",                          │
│   "algorithm": "Ed25519",                                    │
│   "entries": [ … ],                                          │
│   "signature": "5RZ7g…/…=="    ← signiert mit Träger-PrivKey │
│ }                                                            │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ Empfänger (DSB, Aufsicht)
┌──────────────────────────────────────────────────────────────┐
│ Verifier (OpenSSL / Python / Online-Tool)                    │
│                                                              │
│   1. Hash-Chain nachrechnen        →  OK / Manipulation      │
│   2. Signatur prüfen mit PubKey    →  Echt / Gefälscht       │
└──────────────────────────────────────────────────────────────┘
```

Zwei Anker — interne Chain *und* externe Signatur — geben dem Log
forensische Belastbarkeit, die Behörden und Gerichte akzeptieren.

---

## 4. Schlüsselpaar — was, warum, wie

### 4.1 Was ist ein Schlüsselpaar?

Ein asymmetrisches Krypto-Paar:

- **Private Key** — geheim, NUR beim Träger / DSB. Signiert Exports.
- **Public Key** — darf öffentlich sein. Verifiziert Signaturen.

**Algorithmus-Empfehlung: Ed25519.** Kurz (32 Byte Private Key, 32 Byte
Public Key, 64 Byte Signatur), schnell, modern, sicherer als RSA-2048.

### 4.2 Drei Wege das Paar zu erzeugen

| Variante                          | Wer macht es?       | Wann?                                    |
|-----------------------------------|---------------------|------------------------------------------|
| **A — OpenSSL-CLI**               | DSB / IT des Trägers | Beim einmaligen Compliance-Setup         |
| **B — In-App-Wizard**             | Fachkraft beim 1. Start | Wenn der Träger keine eigene IT hat   |
| **C — Externes Dart-Keygen-Tool** | Du als Entwickler   | Wenn du es zentral generieren willst     |

**Empfohlene Strategie für FEGH-Apps:** Variante A *und* B im Setup-
Wizard anbieten. Der Wizard fragt:

```
[ ] Privater Schlüssel importieren (PEM-File vom DSB)
[ ] Neuen Schlüssel generieren (Backup auf Karte ausdrucken)
```

So kann jeder Träger den Weg wählen, der zu seiner IT-Kompetenz passt.

### 4.3 OpenSSL-Befehle (Variante A)

Auf einem beliebigen Linux/macOS-Rechner oder unter Windows mit OpenSSL:

```bash
# Privater Schlüssel
openssl genpkey -algorithm ed25519 -out traeger_private.pem

# Öffentlicher Schlüssel aus dem privaten ableiten
openssl pkey -in traeger_private.pem -pubout -out traeger_public.pem

# Fingerprint berechnen (für Anzeige in der App)
openssl pkey -in traeger_public.pem -pubin -outform DER \
  | sha256sum | head -c 16
```

Die beiden PEM-Files schaut der DSB einmal an, packt `traeger_private.pem`
in den Tresor (Passwort-Manager), `traeger_public.pem` darf auf die
Website oder ins Audit-Begleitdokument.

### 4.4 In-App-Wizard (Variante B)

Beim ersten App-Start nach Datenschutz-Signatur:

1. App generiert Ed25519-Paar via `pointycastle`
2. **Privater Schlüssel wird einmalig angezeigt** als:
   - Großer Block PEM-Text (zum Kopieren)
   - QR-Code (zum Scannen mit Passwort-Manager)
   - „Backup-Karte drucken" Button (PDF mit Text + Fingerprint)
3. Der Private Key wird *nach* dem Backup-Schritt in **DPAPI / Keychain
   / Keystore** abgelegt (via `flutter_secure_storage`).
4. Der Public Key wird in der App-Datenbank (Hive) gespeichert für die
   Anzeige und die Beigabe zum Export.

**Wichtig:** Vor dem Wegspeichern muss die UI eine Checkbox haben
„Ich habe den privaten Schlüssel sicher gesichert" — sonst hat der
User beim Verlust des Geräts keinen Backup.

---

## 5. Schlüssel-Storage

| Schlüssel | Speicherort                  | Begründung                                              |
|-----------|------------------------------|---------------------------------------------------------|
| Private   | `flutter_secure_storage`      | DPAPI (Win) / Keychain (mac) / Keystore (Android) — OS-Schutz |
| Public    | Hive-Box `audit_keys`         | Wird im Klartext gebraucht (Anzeige, Export), unkritisch |

**Regeln für den Private Key:**

- **Niemals** in Hive (auch nicht verschlüsselt — die Box-Cipher würde
  die Sicherheit auf das Box-Passwort reduzieren).
- **Niemals** als Klartext in einer Log-Datei.
- **Niemals** über `print` ausgeben — auch nicht beim Debugging.
- **Niemals** mit einem anderen User auf demselben Gerät teilen
  (jeder User hat sein eigenes DPAPI-Profil).

---

## 6. Log-Format — Event-Struktur

Jeder Eintrag enthält **mindestens** folgende Felder:

| Feld          | Typ      | Beispiel                                  | Zweck                          |
|---------------|----------|-------------------------------------------|--------------------------------|
| `timestamp`   | ISO 8601 | `2026-05-18T07:25:13.221Z`                | Wann                           |
| `action`      | string   | `report_generated`                        | Was                            |
| `userName`    | string   | `Mirko Richter`                           | Wer (aus Datenschutz-Signing)  |
| `details`     | object   | `{model: "claude-opus-4-7", costUsd: …}`  | Was im Detail                  |
| `deviceId`    | UUID v4  | `8f29-…`                                  | Welches Gerät                  |
| `appVersion`  | string   | `0.2.0+2`                                 | Welche Software-Build          |
| `hostname`    | string   | `dasi-fachkraft-04`                       | Welcher Rechner                |
| `prev_hash`   | hex      | `0000…000` (Genesis) oder `4a8…`          | Verkettung mit Vor-Eintrag     |
| `hash`        | hex      | `9c2…`                                    | SHA-256 über alle anderen Felder |

**Hash-Berechnung (kanonisch):**

1. Felder ohne `hash` nehmen
2. JSON serialisieren mit **sortierten Keys** (kanonisch, damit der
   Hash deterministisch bleibt)
3. SHA-256 über die UTF-8-Bytes
4. Hex-Encoding als String

**Genesis:** Für den allerersten Eintrag ist `prev_hash` ein konstanter
String aus 64 Nullen (`"0".repeat(64)`).

### 6.1 Mindestmenge der zu protokollierenden Events

| Event                  | Wann                                       |
|------------------------|--------------------------------------------|
| `signature_created`    | Datenschutzerklärung wurde signiert        |
| `password_set`         | App-Passwort gesetzt                       |
| `login_success`        | Erfolgreiches Entsperren                   |
| `login_failed`         | Fehlgeschlagene Anmeldung                  |
| `login_locked`         | Brute-Force-Lock ausgelöst                 |
| `api_key_validated`    | API-Key wurde erfolgreich getestet         |
| `pseudonymization_run` | Pseudonymisierung gelaufen                 |
| `report_generated`     | KI-Generierung abgeschlossen               |
| `data_reset`           | Factory-Reset ausgeführt                   |
| `key_rotated`          | Träger-Signaturschlüssel ausgetauscht      |

Pro Event nur **Metadaten** loggen — *niemals* den Inhalt selbst,
*niemals* den Klarnamen einer betreuten Person. Die `details` dürfen
Token-Zahlen, Provider, Modell-Name enthalten, aber keine PII.

---

## 7. Signatur-Format

### 7.1 Was wird signiert?

Das gesamte Export-JSON **ohne** das `signature`-Feld. Vorgehen:

1. JSON-Objekt mit allen Feldern außer `signature` zusammenbauen
2. Kanonisch serialisieren (Keys sortiert)
3. UTF-8-Bytes signieren mit Ed25519 + Private Key
4. Base64-codieren
5. Als `signature`-Feld einfügen → fertiges Export-JSON

### 7.2 Beispiel-Export

```json
{
  "appName": "TeilhabeAssist",
  "appVersion": "0.2.0+2",
  "exportedAt": "2026-05-18T07:25:00.221Z",
  "chainValid": true,
  "algorithm": "Ed25519",
  "publicKeyFingerprint": "5d3c2e1b7a8f9023",
  "publicKey": "MCowBQYDK2VwAyEA…",
  "entries": [
    {
      "timestamp": "2026-05-18T06:10:01.000Z",
      "action": "signature_created",
      "userName": "Mirko Richter",
      "details": { "policyHash": "a7e3…" },
      "deviceId": "8f29-…",
      "appVersion": "0.2.0+2",
      "hostname": "dasi-fachkraft-04",
      "prev_hash": "0000…",
      "hash": "9c2…"
    }
  ],
  "signature": "5RZ7gMt…"
}
```

---

## 8. Verifikation (Empfänger-Seite)

### 8.1 Schritt 1 — Hash-Chain prüfen

Wer verifiziert? Jeder, der das Export-JSON in den Händen hält. Kein
Schlüssel nötig — die Chain ist self-contained.

Python-Snippet:

```python
import json, hashlib

def canonical(obj):
    if isinstance(obj, dict):
        items = sorted(obj.items())
        return '{' + ','.join(
            f'{json.dumps(k)}:{canonical(v)}' for k, v in items
        ) + '}'
    if isinstance(obj, list):
        return '[' + ','.join(canonical(x) for x in obj) + ']'
    return json.dumps(obj)

def verify_chain(entries):
    prev = '0' * 64
    for i, e in enumerate(entries):
        stored = e.pop('hash', None)
        if e['prev_hash'] != prev:
            return f'Entry {i}: prev_hash bricht die Kette'
        h = hashlib.sha256(canonical(e).encode()).hexdigest()
        if h != stored:
            return f'Entry {i}: hash stimmt nicht'
        e['hash'] = stored
        prev = stored
    return None  # OK

with open('audit_export.json') as f:
    data = json.load(f)
print(verify_chain(data['entries']) or 'Chain OK')
```

### 8.2 Schritt 2 — Signatur prüfen

```python
import json, base64
from cryptography.hazmat.primitives.serialization import load_pem_public_key
from cryptography.exceptions import InvalidSignature

with open('audit_export.json') as f:
    data = json.load(f)

sig = base64.b64decode(data.pop('signature'))
pub_pem = base64.b64decode(data['publicKey'])  # oder aus PEM-File
pub = load_pem_public_key(pub_pem)

payload = canonical(data).encode()
try:
    pub.verify(sig, payload)
    print('Signatur OK — Export stammt vom Träger')
except InvalidSignature:
    print('Signatur UNGÜLTIG — Datei manipuliert oder anderer Träger')
```

### 8.3 OpenSSL-Alternative (CLI)

```bash
# 1. JSON ohne "signature" extrahieren und kanonisch serialisieren
jq 'del(.signature)' audit_export.json | jq -S . > payload.json

# 2. Signatur als Binär-File
jq -r .signature audit_export.json | base64 -d > sig.bin

# 3. Verifikation
openssl pkeyutl -verify -pubin -inkey traeger_public.pem \
  -rawin -in payload.json -sigfile sig.bin
```

---

## 9. Implementation in Dart/Flutter

### 9.1 Pakete

```yaml
dependencies:
  pointycastle: ^3.9.1          # Ed25519 + SHA-256
  crypto: ^3.0.7                # Convenience SHA-256
  uuid: ^4.5.1                  # Device-ID
  flutter_secure_storage: ^9.2  # Private Key in DPAPI
  hive: ^2.2.3                  # Public Key + Log-Einträge
  package_info_plus: ^8.0.0     # App-Version
```

### 9.2 Schlüssel generieren

```dart
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_generators/ed25519_key_generator.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';

({Uint8List privateKey, Uint8List publicKey}) generateEd25519() {
  final random = FortunaRandom();
  final seed = Uint8List(32);
  // Seed aus secureRandom füllen — Plattform-spezifisch
  random.seed(KeyParameter(_secureSeed()));

  final generator = Ed25519KeyGenerator()
    ..init(ParametersWithRandom(Ed25519KeyGeneratorParameters(), random));
  final pair = generator.generateKeyPair();
  final priv = (pair.privateKey as Ed25519PrivateKey).bytes;
  final pub = (pair.publicKey as Ed25519PublicKey).bytes;
  return (privateKey: priv, publicKey: pub);
}
```

### 9.3 Signieren

```dart
import 'package:pointycastle/signers/ed25519_signer.dart';

Uint8List sign(Uint8List privateKey, Uint8List payload) {
  final signer = Ed25519Signer()
    ..init(true, PrivateKeyParameter(Ed25519PrivateKey(privateKey)));
  final sig = signer.generateSignature(payload) as Ed25519Signature;
  return sig.bytes;
}
```

### 9.4 PEM-Encoding (Import/Export)

PEM ist Base64-wrapped DER. Für Ed25519 gibt's vordefinierte DER-Prefixe.
Vereinfacht (kein vollständiger ASN.1-Parser, aber funktioniert für
saubere PEMs):

```dart
String encodePrivateKeyPem(Uint8List privKey) {
  // DER-Prefix für Ed25519 PKCS#8
  const prefix = [0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
                  0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20];
  final der = Uint8List.fromList([...prefix, ...privKey]);
  final b64 = base64Encode(der);
  return '-----BEGIN PRIVATE KEY-----\n'
      '${b64.replaceAllMapped(RegExp(r".{64}"), (m) => "${m.group(0)}\n")}\n'
      '-----END PRIVATE KEY-----\n';
}
```

(Public-Key-Encoding analog mit eigenem Prefix.)

### 9.5 Storage-Wrapper

```dart
class AuditKeyStore {
  static const _privKeySecureKey = 'traeger_audit_priv';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Box<String> _publicBox;

  Future<void> store(Uint8List priv, Uint8List pub) async {
    await _secure.write(key: _privKeySecureKey, value: base64Encode(priv));
    await _publicBox.put('public_key', base64Encode(pub));
  }

  Future<Uint8List?> loadPrivate() async {
    final b64 = await _secure.read(key: _privKeySecureKey);
    return b64 == null ? null : base64Decode(b64);
  }

  Uint8List? loadPublic() {
    final b64 = _publicBox.get('public_key');
    return b64 == null ? null : base64Decode(b64);
  }
}
```

---

## 10. Multi-App-Strategie

### 10.1 Empfohlene Variante: Ein Schlüssel pro Träger

**Vorteile:**

- DSB verwaltet nur **einen** Private Key
- Aufsicht braucht nur **einen** Public Key zur Verifikation aller Logs
- Konsistenz: alle FEGH-Apps des Trägers signieren mit demselben Schlüssel

**Wie geht das praktisch?**

1. DSB generiert das Paar **einmal** (Variante A — OpenSSL)
2. Beim Setup jeder FEGH-App importiert er die `traeger_private.pem`
3. Jede App speichert den Private Key in **ihrem** DPAPI-Profil
   (Apps können sich gegenseitig nicht in den Secure-Storage schauen,
   das ist OS-Isolation — daher muss jede App ihr eigenes Backup haben)

### 10.2 Setup-Wizard in jeder FEGH-App

```
┌────────────────────────────────────────────────────────────┐
│ Audit-Signatur einrichten                                  │
│                                                            │
│ Diese App signiert Audit-Logs mit einem Träger-Schlüssel,  │
│ damit die Echtheit für Aufsichtsbehörden nachweisbar ist.  │
│                                                            │
│  ○ Neuen Schlüssel generieren                              │
│    (Wenn Sie noch keinen Träger-Schlüssel haben)           │
│                                                            │
│  ● Bestehenden Schlüssel importieren                       │
│    (Empfohlen, wenn Sie schon andere FEGH-Apps nutzen)     │
│                                                            │
│  [ PEM-File auswählen … ]   [ Überspringen ]               │
│                                                            │
│ Hinweis: Auch ohne Signatur funktioniert der Audit-Log     │
│ (Hash-Chain). Die externe Verifikation ist dann aber nur   │
│ in Grenzen möglich.                                        │
└────────────────────────────────────────────────────────────┘
```

### 10.3 Schlüssel-Rotation

Wenn ein Private Key kompromittiert wird:

1. **Sofort** den alten Public Key als „revoked" auf der Träger-Website
   markieren
2. Neues Paar generieren
3. In allen FEGH-Apps das neue Paar importieren (Setup-Wizard erneut)
4. Audit-Event `key_rotated` mit Fingerprint-Alt → Fingerprint-Neu
   schreiben
5. Künftige Exports werden mit dem neuen Key signiert
6. Alte Exports bleiben mit dem alten Key prüfbar (deshalb sollte der
   alte Public Key öffentlich archiviert bleiben — nicht löschen)

---

## 11. Sicherheits-Checkliste

- [ ] Privater Schlüssel nur in `flutter_secure_storage`
- [ ] Privater Schlüssel **nie** in einer Log-Datei
- [ ] Privater Schlüssel **nie** mit `print` ausgeben
- [ ] Vor erstem Speichern: User muss Backup-Bestätigung geben
- [ ] Beim Reset (`data_reset`): **Audit-Log + Schlüsselpaar bleiben
      erhalten** (explizit aus der Lösch-Liste ausnehmen!)
- [ ] Beim Reset wird der Reset selbst geloggt (`data_reset`-Event)
- [ ] Public-Key-Fingerprint ist in der App sichtbar (UI-Sektion
      „Audit-Schlüssel" in Settings)
- [ ] Kanonisches JSON (sortierte Keys) für Hash + Signatur
- [ ] Ed25519, nicht RSA (kompakter, kein Padding-Risiko)
- [ ] Kein Custom-Krypto — nur etablierte Pakete (pointycastle, crypto)
- [ ] Beim Audit-Export: Hash-Chain VOR der Signatur verifizieren
- [ ] Schlüsselpaar-Rotation als eigenes Audit-Event dokumentieren

---

## 12. Anhang — Wiederverwendung in anderen FEGH-Apps

**Wiederverwendbare Code-Stücke (kopierbar in jede neue FEGH-App):**

1. `lib/core/storage/audit_log.dart` — Hash-Chain + Export
2. `lib/core/storage/audit_keys.dart` — Schlüssel-Management
3. `lib/core/storage/audit_context.dart` — Device-ID, App-Version, etc.
4. `lib/features/settings/audit_log_screen.dart` — In-App-Viewer
5. `lib/features/settings/audit_keys_screen.dart` — Schlüssel-Setup
6. `tools/verify_audit_export.py` — externer Python-Verifier

**Pro App-spezifisch anzupassen:**

- Liste der Event-Typen (`AuditEvent` statische Methoden)
- Logging-Aufrufe an den richtigen Code-Stellen
- `appName`-Konstante im Export-Header

**Was du beim DSB hinterlegst (einmalig pro Träger):**

| Datei                          | Wo verwahrt           |
|--------------------------------|-----------------------|
| `traeger_private.pem`          | Tresor / Passwort-Manager / Krypto-USB |
| `traeger_public.pem`           | Backup + Träger-Website (optional)     |
| `verify_audit_export.py`       | Beim DSB für Audits   |
| Dieses Dokument als PDF        | Beim DSB als Spezifikation             |

---

## 13. Glossar

- **Audit-Log** — Chronologisches Protokoll sicherheitsrelevanter Aktionen
- **Hash-Chain** — Jeder Eintrag enthält den Hash des Vorgängers
- **Detached Signature** — Signatur in separatem Feld, nicht im Payload
- **Kanonisches JSON** — JSON mit sortierten Keys, deterministisch
- **Ed25519** — Modernes EC-Signatur-Verfahren (RFC 8032)
- **DPAPI** — Windows Data Protection API (User-gebundene Verschlüsselung)
- **DSB** — Datenschutzbeauftragter
- **VVT** — Verzeichnis von Verarbeitungstätigkeiten (DSGVO Art. 30)
- **DSFA** — Datenschutz-Folgenabschätzung (DSGVO Art. 35)
- **TOM** — Technisch-organisatorische Maßnahmen (DSGVO Art. 32)

---

**Lizenz dieses Dokuments:** CC-BY-SA 4.0 — frei verwendbar mit
Namensnennung. Code-Snippets unter AGPL-3.0 (wie der Rest der
FEGH-Apps).
