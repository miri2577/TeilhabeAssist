# Pseudonymisierungs-Engine

Die Engine erkennt direkte und indirekte Identifikatoren in deutschem
Fachtext und ersetzt sie durch nummerierte Platzhalter (`[PERSON_001]`,
`[ADRESSE_001]` …). Die Zuordnungstabelle bleibt lokal verschlüsselt;
nach der LLM-Antwort werden die Platzhalter wieder durch die Originale
ersetzt.

## Verarbeitungspipeline

Code: `lib/features/pseudonymization/engine/pseudonym_engine.dart`

```
Eingangstext (Stichpunkte, Vorbericht, Referenzbericht)
        │
        ▼
1. E-Mail-Adressen          (Regex, eindeutig durch @)
        │
        ▼
2. Aktenzeichen / IDs       (EH-2024-12345, EGH/2024/…)
        │
        ▼
3. Datumsformate            ◀── numerisch + Monatsname + Geburtsjahr
        │                       (mit ICD-10-Ausschluss)
        ▼
4. Telefonnummern           (+49, 030, 0170, …)
        │
        ▼
5. Adressen                 (Berliner Straßen + generisches Pattern)
        │
        ▼
6. Einrichtungsnamen        (Berliner Träger-Dictionary, längste zuerst)
        │
        ▼
7. Personennamen            (Anrede → Wörterbuch → gelernte Namen)
        │
        ▼
8. Validierung              (sucht nach übrig gebliebenen PII-Mustern)
        │
        ▼
Pseudonymisierter Text + Mapping-Tabelle + Warnings
```

Die Reihenfolge ist **spezifisch → allgemein**, damit Trägernamen
("Lebenshilfe") nicht zuerst als Personennamen erkannt werden, und
Aktenzeichen ("EH-2024-12345") nicht in Datumsbestandteile zerfallen.

## Erkennungsklassen

| Kategorie | Präfix | Erkennungs-Mechanismus | Konfidenz |
| --- | --- | --- | --- |
| `email` | `[EMAIL_NNN]` | Regex `local@domain.tld` | hoch |
| `aktenzeichen` | `[AKTENZEICHEN_NNN]` | `EH/EGH/SGB/TH/GPV` + Jahr + Nummer | hoch |
| `datum` (numerisch) | `[DATUM_NNN]` | `dd.MM.yyyy`, `dd/MM/yyyy`, `dd.MM.yy`, ISO `yyyy-MM-dd` | hoch |
| `datum` (Monatsname) | `[DATUM_NNN]` | `15. März 2024`, `März 2024`, alle deutschen Monatsnamen + Kurzformen | hoch |
| `datum` (Geburtsjahr) | `[DATUM_NNN]` | `geboren 1985`, `Jg. 1985`, `Jahrgang 1985` (nur die Jahreszahl wird ersetzt) | hoch |
| `telefon` | `[TELEFON_NNN]` | Deutsche Festnetz- und Mobil-Patterns | hoch |
| `adresse` | `[ADRESSE_NNN]` | Berliner Straßen-Dictionary + generisches Straße+Nr.-Pattern | hoch / mittel |
| `einrichtung` | `[EINRICHTUNG_NNN]` | Träger-Dictionary, längste Treffer zuerst | hoch |
| `person` | `[PERSON_NNN]` | Anrede + Name, Vornamen-Wörterbuch, gelernte Namen | hoch / mittel |
| `behandler` | `[BEHANDLER_NNN]` | Wie `person`, aber im Kontext "Arzt/Therapeut/Sozial…" | hoch |

Duplikate (gleicher Originalwert) bekommen denselben Platzhalter. Damit
referenziert der LLM die gleiche Person konsistent.

## Konfidenz-Stufen

```dart
enum ConfidenceLevel { high, medium, low }
```

- **high** — Regel- oder Pattern-basierter Treffer, der nicht zu False
  Positives neigt.
- **medium** — Wörterbuch-Treffer (z.B. Vorname in Fließtext).
  Wahrscheinlich richtig, aber prüfen empfohlen.
- **low** — Heuristische Vermutung. Aktuell **deaktiviert**, weil die
  früheren großgeschriebenes-Wort-Heuristiken in deutschem Fachtext zu
  viele False Positives erzeugten.

Bei Treffern mit `low` (oder bestimmten `medium`) wird eine Warnung
gesammelt, die in der Review-Vorschau angezeigt wird und ein zusätzliches
Bestätigungs-Häkchen erfordert.

## Personennamen-Erkennung im Detail

`lib/features/pseudonymization/engine/name_recognizer.dart`

Drei Stufen, mit Anti-Überlapp:

### Stufe 1 — Anrede + Name (hoch)

```
Herr Müller             → [PERSON_NNN]
Herrn Dr. Schmidt       → [PERSON_NNN]
Frau Prof. Dipl.-Psych. Schulze   → [PERSON_NNN]
```

Regex: `\b(?:Herrn?|Frau|Hr\.|Fr\.)\s+(?:(?:Dr\.|Prof\.|Dipl\.…)\s+)?Name`.

### Stufe 2 — Rolle + Name (hoch, Kategorie `behandler`)

```
Therapeut Schmidt       → [BEHANDLER_NNN]
Sozialarbeiterin Meier  → [BEHANDLER_NNN]
```

Regex deckt Arzt/Ärztin, Betreuer(in), Therapeut(in), Psychiater(in),
Psycholog(e/in), Sozialarbeiter(in), Sozialpädagog(e/in).

### Stufe 3 — Vornamen-Wörterbuch (mittel)

```
Maria sagte, dass …     → [PERSON_NNN] sagte, dass …
```

Voraussetzung: Wort fängt mit Großbuchstabe an, ist ≥ 3 Zeichen,
**nicht** in der Liste der häufigen Wörter (`kCommonWords`),
**nicht** im User-Excluded-Wörterbuch, und entweder im
`kFirstNames`-Wörterbuch oder im `_learnedNames`-Store.

### Stufe 4 — Statistische Heuristik (DEAKTIVIERT)

Die ursprüngliche Idee — alle großgeschriebenen Wörter nach Komma/Punkt
als möglichen Eigennamen zu markieren — funktioniert in deutschem
Fachtext nicht, weil **alle** Substantive großgeschrieben werden. Die
False-Positive-Rate war so hoch, dass Berichte zu rauschig wurden.
Stattdessen: **Lernfunktion**.

## Lernfunktion

`learned_names_store.dart` — persistente Hive-Box mit allen Namen, die
die Fachkraft beim ersten Bericht händisch bestätigt hat. Beim nächsten
Bericht (gleicher oder anderer Klient) werden diese Namen automatisch
in Stufe 3 erkannt.

```
Bericht 1: "Herr Müller wurde von Janine Schulze besucht."
            ─────────────              ─────────────────
            Stufe 1 (hoch)             unbekannt – Vorname nicht im Dict

→ User bestätigt "Janine Schulze" als Name
→ "janine" und "schulze" landen im _learnedNames-Store

Bericht 2: "Schulze war pünktlich, Janine ebenfalls."
                   ──────         ──────
                   Stufe 3 ✓     Stufe 3 ✓
```

Der Store ist verschlüsselt und gerätelokal. Ein Export ist nur
intentional über *Einstellungen → Wörterbuch* möglich.

## Adressen-Erkennung

`address_recognizer.dart` hat zwei Stufen:

1. **Bekannte Berliner Straßen** — `kBerlinStreets` enthält rund 700
   Straßennamen aus dem Berliner Geo-Datensatz. Match mit Hausnummer
   und optionalem PLZ-/Ortssuffix → `high`.
2. **Generisches Straßen-Pattern** — Wort mit großem Anfangsbuchstaben
   gefolgt von `str.`, `straße`, `weg`, `platz`, `allee`, `damm`,
   `ring`, `ufer`, `zeile`, `gasse`, `pfad`, `chaussee`, `promenade`,
   `steig`, plus Hausnummer → `medium`.
3. **PLZ + Berlin** — Postleitzahlen aus dem Berliner Bereich
   (10115–14199) gefolgt von "Berlin" → `medium`.

Bei Region-Konfiguration für andere Bundesländer siehe
[Region-Konfiguration](Region-Konfiguration).

## Datumserkennung — Edge Cases

| Eingabe | Erkennung |
| --- | --- |
| `15.03.1985` | ✓ Datum (numerisch) |
| `1.1.24` | ✓ Datum (numerisch, dd.MM.yy) |
| `2024-03-15` | ✓ Datum (ISO) |
| `15. März 2024` | ✓ Datum (Monatsname) |
| `März 2024` | ✓ Datum (Monatsname, ohne Tag) |
| `geboren 1985` | ✓ Geburtsjahr (nur "1985" ersetzt, "geboren" bleibt) |
| `Jg. 1985` | ✓ Geburtsjahr |
| `Jahrgang 1985` | ✓ Geburtsjahr |
| `seit 2020` | ✗ keine Geburtsjahr-Anker — wird NICHT als PII markiert |
| `Ende der 1980er Jahre` | ✗ keine Erkennung — wenig identifizierend |
| `F20.0` | ✗ ICD-10, wird explizit nicht ersetzt |
| `B12` (Vitamin) | ✗ ICD-10-Regex matcht; im Datums-Kontext aber ausgeschlossen, Vitamin-Erwähnungen sind unproblematisch |

ICD-10 wird **erkannt aber nicht ersetzt**, weil Diagnose-Codes für den
Bericht inhaltlich notwendig sind und keine direkte Identifikation
ermöglichen.

## Validierung nach der Pseudonymisierung

`PseudonymEngine.validateAnonymization(text)` läuft am Ende über den
bereinigten Text und prüft, ob noch Datums-, Monatsnamen- oder
Telefon-Patterns übrig sind. Funde werden als Warnings angehängt — die
Fachkraft sieht sie in der Review-Vorschau.

Namens-Heuristik im Nachgang ist absichtlich deaktiviert, weil sie zu
viele False Positives produzieren würde.

## Rekonstruktion

Nach der LLM-Antwort werden die Platzhalter durch die Originale ersetzt.
Wichtig: **Längste Platzhalter zuerst**, damit `[PERSON_001]` nicht in
`[PERSON_0011]` reinläuft:

```dart
final sorted = mappings.toList()
  ..sort((a, b) => b.placeholder.length.compareTo(a.placeholder.length));
for (final m in sorted) {
  result = result.replaceAll(m.placeholder, m.original);
}
```

Übrig gebliebene Platzhalter (`[XXX_NNN]`) im rekonstruierten Text sind
ein Alarm-Signal: entweder hat das LLM einen Platzhalter halluziniert,
oder die Engine kennt diesen nicht. Die App zeigt dann eine rote
Warnung **"Bericht NICHT exportieren!"** und blockiert den PDF-Export.

## Grenzen

> **Wichtig.** Die Engine ist ein **Hilfsmittel**, keine Garantie. Die
> finale Verantwortung liegt bei der prüfenden Fachkraft.

| Was die Engine nicht zuverlässig erkennt |
| --- |
| Seltene Nachnamen, die *ohne* Anrede vorkommen ("Frau X war krank, Müller berichtete später, …") |
| Ungewöhnlich geschriebene Vornamen, die nicht im Wörterbuch und nicht gelernt sind |
| Spitznamen, Kosenamen, abgekürzte Namen ("L. M.") |
| Geburtsdaten in der Form "vor 30 Jahren geboren" — kein Anker |
| Postleitzahlen außerhalb Berlins ohne weitere Adress-Bestandteile |
| Indirekte Identifikatoren: Bezirk + sehr seltene Diagnose + sehr seltener Beruf |

Daher die UI-Architektur:

1. **Hervorhebung** im Preview macht visuell sichtbar, was bereits
   ersetzt wurde — und was eben nicht.
2. **Pflicht-Bestätigung** zwingt die Fachkraft, jede Zeile zu lesen.
3. **Zweite Bestätigung bei Warnings** vermeidet Reflex-Klicks.
4. **5 Sekunden Mindest-Lesezeit** vor freigegebener Bestätigung.
5. **Lernfunktion** — Namen, die einmal bestätigt wurden, finden sich
   beim nächsten Bericht automatisch.

## Test-Coverage

`test/features/pseudonymization/` enthält 49 Tests, u.a.:

- Datumsformate (numerisch, mit Monatsnamen, Geburtsjahr)
- Telefonnummern in 3 Schreibweisen
- E-Mails mit Subdomains
- Aktenzeichen in 7 Format-Varianten
- ICD-10 wird nicht ersetzt
- Personennamen: Anrede, Wörterbuch, türkische Namen, Lernfunktion
- Adressen: Berliner Straßen-Dictionary + generisches Pattern
- Einrichtungen + Abkürzungen
- Rekonstruktion vollständig
- Synthetischer realistischer Berliner Informationsbericht

Beim Erweitern: jeder neue Regex bekommt mindestens einen positiv- und
einen negativ-Test (FP vermeiden).
