# Benutzerhandbuch

Schritt-für-Schritt durch alle Bedienschritte. Diese Seite ist für
Fachkräfte ohne Programmier-Hintergrund geschrieben — Entwickler:innen
finden technische Details in der [Architektur-Übersicht](Architektur).

## Erster Start

### 1. Passwort vergeben

Beim allerersten Öffnen erscheint ein Setup-Screen:

```
┌─────────────────────────────────────┐
│ 🔒  FEGH-Bericht                  │
│                                     │
│ Bitte vergib ein persönliches       │
│ Passwort zum Schutz der Sozialdaten.│
│                                     │
│ Neues Passwort:  ●●●●●●●●           │
│ Stärke:          [████████░] Stark  │
│                                     │
│ Passwort bestätigen: ●●●●●●●●       │
│                                     │
│ [ Passwort vergeben ]               │
└─────────────────────────────────────┘
```

**Empfehlung:** mindestens 14 Zeichen, eine Mischung aus
Groß-/Kleinbuchstaben, Ziffern und Sonderzeichen. Notiere dir das
Passwort an einem **sicheren Ort** — es lässt sich nicht
wiederherstellen.

### 2. Datenschutzerklärung lesen und unterzeichnen

Die App zeigt die vollständige Datenschutzerklärung. Lies sie
**aufmerksam**:

- Welche Daten lokal gespeichert werden
- Welche Daten an Anthropic / OpenAI übermittelt werden
- Welche Restrisiken bestehen (§ 4.3 und § 12)
- Welche Pflichten du als Fachkraft übernimmst (§ 11)

Danach:
- Häkchen "Ich habe gelesen und verstanden" setzen
- Deinen vollständigen Namen eintragen
- "Gelesen und bestätigt" klicken

Die Signatur wird mit Zeitstempel und Hash der Erklärung gespeichert.

### 3. API-Key hinterlegen

Über *Einstellungen → API*:

- **Anthropic-Key:** Erhältst du auf https://console.anthropic.com →
  Settings → API Keys → "Create Key". Format: `sk-ant-…`
- **OpenAI-Key:** Erhältst du auf https://platform.openai.com → API Keys
  → "Create new secret key". Format: `sk-…` oder `sk-proj-…`

Klicke auf "Testen" — die App prüft kurz, ob der Key gültig ist, und
zeigt ein grünes Häkchen.

### 4. Modell wählen

```
Provider:  ( ) Anthropic Claude   (•) OpenAI GPT
Modell:    [ gpt-5.4              ▼ ]
```

Empfehlung für den Anfang:
- **claude-sonnet-4-6** (Anthropic) oder **gpt-5.4** (OpenAI) —
  Standardberichte, gutes Verhältnis von Qualität zu Kosten.
- Für besonders schwierige Fälle: **claude-opus-4-7** oder **gpt-5.5**.
- Für Massenberichte: **claude-haiku-4-5** oder **gpt-5.4-mini**.

## Neuer Bericht

### 5. Berichtstyp wählen

Im Hauptmenü "Neuer Bericht":

| Typ | Verwendung |
| --- | --- |
| **Informationsbericht** | Berliner Vorlage v1.01, klassischer Bericht an den Kostenträger |

### 6. Stichpunkte erfassen

Der Editor zeigt eine **Modul-Palette** links und den Bericht in der
Mitte. Module per Drag&Drop hinzufügen — oder über das Plus-Menü
auswählen.

Typische Module:

- **Persönliche Daten** — Name, Geburtsdatum, Aktenzeichen
- **Lebenssituation** — Wohnsituation, Familie, soziales Umfeld
- **Diagnostik** — ICD-10-Codes, Diagnosenarrativ
- **Ressourcen** — Stärken, Interessen
- **Bedarf** — Hilfebedarf je ICF-Domäne
- **Ziele** — SMART-Ziele
- **Maßnahmen** — Konkrete Schritte mit Anbietern
- **Prognose** — Risiko, Verlauf

Du erfasst **Stichpunkte**, nicht ausformulierte Sätze. Das Modell macht
daraus den Berichtstext.

### 7. Vorbericht hochladen (optional)

Wenn du einen Fortschreibungsbericht erstellst:

- "Vorbericht hochladen" → PDF auswählen
- Die App extrahiert den Text und legt ihn in den Vorbericht-Slot.

Der Vorbericht hilft dem Modell, Verlaufsbeschreibungen zu erstellen
("Im letzten Berichtszeitraum hatte Herr Müller …").

### 8. Referenzbericht hochladen (optional)

Wenn du einen bestimmten Stil bevorzugst (z.B. die Schreibweise eines
Träger-Vorbilds):

- "Referenzbericht hochladen" → PDF
- Die App pseudonymisiert ihn und nutzt ihn als **Stilvorbild**.
- Inhalt wird nicht übernommen, nur der Sprachduktus.

### 9. Bericht generieren

"Generieren"-Button klicken. Die App:

1. Pseudonymisiert lokal (Sekundenbruchteile bis ~2 Sekunden).
2. Zeigt eine **Vorschau** mit Hervorhebung aller Ersetzungen.

### 10. Vorschau prüfen

```
┌─────────────────────────────────────────────────────┐
│ ✓ 18 Ersetzungen   ⚠ 2 Warnungen                    │
│                                                     │
│ Bitte prüfen (2):                                   │
│ • Möglicher Name erkannt: "Tatjana" – bitte prüfen │
│ • Mögliches Datum gefunden: "13.11" – bitte prüfen │
│                                                     │
│ ─── Gesamter Text der an die API gesendet wird ──  │
│                                                     │
│ [PERSON_001] wohnt in [ADRESSE_001] und besucht    │
│ wöchentlich die Tagesstätte. [BEHANDLER_001] hat   │
│ am [DATUM_001] die Diagnose F20.0 gestellt.        │
│ Tatjana arbeitet im Haushalt mit.                  │
│                                                     │
│ ☐ Ich habe den Text Zeile für Zeile geprüft und    │
│   bestätige, dass keine personenbezogenen Daten    │
│   mehr enthalten sind.                             │
│                                                     │
│ ☐ Ich habe die Warnungen oben einzeln gelesen und  │
│   bewertet. Etwaige Restrisiken übernehme ich in   │
│   meiner fachlichen Verantwortung.                 │
│                                                     │
│         [ Bericht generieren ]   (deaktiviert)      │
└─────────────────────────────────────────────────────┘
```

**Was du tun musst:**

1. **Lies den gesamten Text** Zeile für Zeile.
2. **Prüfe jede Warnung** in der Liste — meistens sind die Funde
   harmlos (z.B. Patronyme), aber manchmal hat die Engine einen
   richtigen Namen übersehen.
3. **Gehe zurück zum Editor**, wenn du PII findest, und entferne sie
   händisch. Wenn ein Vorname fehlt: über "Wörterbuch → Name lernen".
4. **5 Sekunden warten** — die App gibt das erste Häkchen erst nach
   einer kurzen Lesezeit frei.
5. **Beide Häkchen setzen** (das zweite nur falls Warnungen).
6. **Klicke "Bericht generieren"** — der Knopf wird jetzt aktiv.

### 11. Warten

Die App sendet den pseudonymisierten Text an das LLM und zeigt einen
Spinner. Dauer typischerweise:
- Sonnet 4.6 / GPT-5.4: 5–15 Sekunden
- Opus 4.7 / GPT-5.5: 15–40 Sekunden
- Haiku 4.5 / GPT-5.4-nano: 2–8 Sekunden

### 12. Ergebnis prüfen

Nach der Generierung sind die Platzhalter wieder durch die Originale
ersetzt. Du siehst den **fertigen Bericht** mit Klarnamen.

```
┌─────────────────────────────────────────────────────┐
│ ✓ Bericht erfolgreich generiert                     │
│                                                     │
│ API-Verbrauch: 2,8k → 1,6k Token                   │
│ Modell: claude-sonnet-4-6 · Kosten: $0.018          │
│                                                     │
│ ─── Qualität ──────────────────────────────────    │
│ ⚠ Modul "Prognose" wirkt zu kurz                   │
│                                                     │
│ ─── Bericht ───────────────────────────────────    │
│                                                     │
│ Maria Müller wohnt in der Friedrichstraße 12 in    │
│ Berlin-Mitte und besucht wöchentlich die           │
│ Tagesstätte der Lebenshilfe Berlin. Dr. Schmidt    │
│ hat am 15.03.2026 die Diagnose F20.0 …             │
│                                                     │
│ [ Zurück ] [ Kopieren ] [ Als TXT ] [ Als PDF ]    │
└─────────────────────────────────────────────────────┘
```

**Quality-Check:** Die App zeigt mögliche Schwachstellen (zu kurze
Module, vage Sprache, fehlende Abschnitte). Du kannst sie ignorieren
oder den Bericht überarbeiten.

### 13. Exportieren

| Button | Verhalten |
| --- | --- |
| **Kopieren** | Bericht in die Zwischenablage — kann in Word/Outlook eingefügt werden |
| **Als TXT** | Speichert eine `.txt`-Datei |
| **Als PDF** | Öffnet den PDF-Export-Screen mit Wahl: freier Bericht oder Formular-Vorlage |

#### PDF mit Formular-Vorlage

Wenn du die offizielle Berliner Vorlage (Informationsbericht 1.01)
nutzen willst:

- "Als PDF" → "Mit Vorlage füllen"
- Die App füllt Felder wie *Name, Aktenzeichen, Berichtszeitraum*
  automatisch aus dem Bericht aus.
- Das Ergebnis ist ein druckfertiges PDF mit dem Berliner Layout.

## Folgeberichte

Wenn du einen **Fortschreibungsbericht** für dieselbe Klientin erstellst:

1. "Neuer Bericht" → Typ wählen → "Vorbericht hochladen"
2. Beim Pseudonymisieren erkennt die App, dass *Maria Müller* schon
   beim letzten Bericht bestätigt wurde — der Name landet im
   Lernspeicher.
3. Du musst nichts neu lernen lassen.

Über *Einstellungen → Wörterbuch* kannst du den Lernspeicher einsehen,
einzelne Einträge löschen oder das ganze Wörterbuch exportieren.

## Settings im Detail

### API
- Provider-Wechsel
- API-Keys verwalten und testen
- Modellwahl
- Custom System-Prompts (Fortgeschrittene)

### Wörterbuch
- Gelernte Namen ansehen
- Ausgeschlossene Wörter pflegen (z.B. "Lebenswelt" als
  nicht-Person markieren)
- Wörterbuch importieren/exportieren als JSON

### Audit-Log
- Letzte 100 Events anzeigen
- Vollständigen Trail als JSON exportieren
- Chain-Verifikation prüfen

### Datenschutz
- Aktuelle Signatur ansehen
- Datenschutzerklärung neu unterzeichnen (wenn sie sich geändert hat)

### Datenverwaltung
- "Alle Daten löschen" — Voll-Reset (siehe
  [Datenspeicherung § Löschen](Datenspeicherung#auf-disk-löschen))

### Erscheinungsbild
- Hell / Dunkel / System
- Schriftgröße

## Tastatur-Kürzel

| Aktion | Windows / Linux | macOS |
| --- | --- | --- |
| Neuer Bericht | `Ctrl + N` | `⌘ + N` |
| Speichern | `Ctrl + S` | `⌘ + S` |
| Generieren | `Ctrl + Enter` | `⌘ + Enter` |
| Exportieren | `Ctrl + E` | `⌘ + E` |
| Suche | `Ctrl + F` | `⌘ + F` |
| App sperren | `Ctrl + L` | `⌘ + L` |

## Häufige Fragen

**Was passiert, wenn ich mein Passwort vergesse?**
Nichts — es lässt sich nicht wiederherstellen. Die einzige Option ist
ein "Alle Daten löschen" und Neuanfang. Daher: notieren!

**Kann ich den Bericht parallel auf einem zweiten Gerät weiterbearbeiten?**
Aktuell nicht. Drafts liegen lokal, eine Synchronisation ist in der
[Roadmap](Roadmap).

**Was ist, wenn die API offline ist?**
Die App zeigt einen Fehler. Der pseudonymisierte Text und der Draft
bleiben lokal — du kannst später erneut auf "Generieren" klicken.

**Wie ändere ich den Stil eines Berichts?**
- Anderes Modell wählen (Opus 4.7 → kreativer, Haiku 4.5 → kürzer).
- Referenzbericht hochladen.
- Custom System-Prompt schreiben (*Einstellungen → System-Prompt*).
