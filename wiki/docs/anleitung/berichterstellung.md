# Berichterstellungs-Flow

Vom ersten Stichpunkt zum exportierten PDF. Diese Seite folgt dem
gleichen Pfad, den die App durchläuft, und referenziert die jeweiligen
Code-Stellen.

## Übersicht

```
┌────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Stichpunkte    │ →  │ Pseudonymisierung│ →  │ Review-Vorschau │
│ + Vorbericht   │    │ (lokal)          │    │ + Bestätigung   │
└────────────────┘    └──────────────────┘    └────────┬────────┘
                                                       │
                                                       ▼
┌────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ PDF-Export     │ ←  │ Quality-Check    │ ←  │ LLM-API-Aufruf  │
│ oder TXT/Copy  │    │ + Rekonstruktion │    │ (pseudonymisiert)│
└────────────────┘    └──────────────────┘    └─────────────────┘
```

## Schritt 1 — Erfassung im Editor

`lib/features/report_editor/report_editor_screen.dart`

Die Datenstruktur ist der `ReportDraft`:

```dart
class ReportDraft {
  String id;
  ReportType type;           // informationsbericht (BRP wurde entfernt)
  List<ReportModule> modules; // dynamische Bausteine
  String previousReport;     // optional: Vorbericht
  String referenceReport;    // optional: Stilreferenz
  FlsData? fls;              // optional: Funktionsleistungseinschätzung
  IcfDomain? primaryDomain;  // optional: ICF-Hauptdomäne
  String generatedText;      // gefüllt nach Generierung
  DateTime updatedAt;
}
```

Drafts werden in `DraftStorage` (verschlüsselte Hive-Box) persistiert,
damit ein Strom-Ausfall oder Bug nicht zum Datenverlust führt. Speicherung
erfolgt automatisch bei jedem `setState` mit Debounce ~500 ms.

### Module

Module sind wiederverwendbare Bausteine pro Berichtstyp:

| Modul | Verwendung |
| --- | --- |
| `personalData` | Name, Geburtsdatum, Aktenzeichen — wird voll pseudonymisiert |
| `lebenssituation` | Frei-Text mit Stichpunkten zur aktuellen Lebenslage |
| `diagnostik` | ICD-10-Codes, Diagnosenarrativ |
| `ressourcen` | Stärken, soziale Anbindung |
| `bedarf` | Hilfebedarf je ICF-Domäne |
| `ziele` | SMART-Ziele |
| `massnahmen` | Konkrete Maßnahmen + Anbieter |
| `prognose` | Risikoeinschätzung |

Welche Module Pflicht sind, hängt vom `ReportType` und vom verwendeten
`ReportTemplate` ab.

### Templates

`TemplateStorage` speichert Träger-spezifische oder fachkraft-spezifische
Templates. Ein Template ist eine Sammlung von Modul-Stubs mit
Default-Inhalten. Beim Anlegen eines neuen Berichts wählt die Fachkraft
ein Template — oder beginnt leer.

### PDF-Import

`pdf_import_service.dart` kann einen alten PDF-Bericht parsen und die
extrahierten Module als Stub in den neuen Draft laden. Das ist nützlich,
wenn die Fachkraft einen Fortschreibungsbericht erstellt.

## Schritt 2 — Pseudonymisierung

`lib/features/report_editor/generate_screen.dart` ist die zentrale
Drehscheibe. Beim Wechsel in den Generate-Screen wird automatisch eine
einzige `PseudonymEngine`-Instanz erzeugt — damit über Notizen,
Vorbericht und Referenzbericht hinweg dieselben Platzhalter-Nummern
vergeben werden.

```dart
_engine = PseudonymEngine();
_engine!.loadUserDictionary(dictionary);

// Referenz-Bericht zuerst (eigene Mappings, dann …
final refResult = _engine!.pseudonymize(draft.referenceReport);

// Vorbericht — gleiche Namen erhalten gleiche Platzhalter)
final prevResult = _engine!.pseudonymize(draft.previousReport,
                                          keepMappings: true);

// Aktuelle Notizen — bauen weiter auf die gleichen Mappings auf
_pseudonymResult = _engine!.pseudonymize(draft.allNotesAsText,
                                          keepMappings: true);
```


## Schritt 3 — Review-Vorschau

Die Fachkraft sieht:

- **Chips** mit Anzahl Ersetzungen und Warnungen
- **Pseudonymisierungs-Warnings** in oranger Box mit Liste
- **Highlighted Text** der Notizen — jede Ersetzung farblich markiert mit
  Kategorie-Icon
- **Vorbericht** roh-pseudonymisiert
- **Eine Pflicht-Checkbox** für die Bestätigung
- **Bei Warnungen: zusätzliche Pflicht-Checkbox** für das Eingeständnis
  des Restrisikos
- Eine 5-sekündige Wartezeit, bevor die Bestätigung überhaupt aktiv ist

Code: `_buildReviewStep` in `generate_screen.dart`.

## Schritt 4 — LLM-Aufruf

`_generate()` wird erst aktiv, wenn `_canGenerate == true`. Dann:

1. Signature-Check: Datenschutzerklärung gültig signiert?
2. API-Key-Check: Key für den ausgewählten Provider hinterlegt?
3. Adapter aus `llmAdapterProvider` ziehen
4. `ReportRequest` zusammenbauen:
   - `apiKey`
   - `model` (aktuell ausgewähltes Modell)
   - `reportType` (entscheidet über System-Prompt)
   - `pseudonymizedNotes`, `pseudonymizedPreviousReport`,
     `pseudonymizedReferenceReport`
5. Non-Streaming `adapter.generateReport(request)` aufrufen.
   - Non-Streaming, damit die Token-Usage-Daten (Input/Output-Tokens,
     Kosten-Schätzung) zurückkommen.
6. Antwort durch `_stripAiClosingText` filtern — entfernt typische
   KI-Schlussfloskeln ("Wenn du möchtest …", "Soll ich noch …", "Bei
   Bedarf kann ich …", "Gerne kann ich …") aus den letzten Absätzen.

## Schritt 5 — Rekonstruktion

Die Engine ersetzt die Platzhalter zurück durch Originale (siehe
[Pseudonymisierung § Rekonstruktion](Pseudonymisierung#rekonstruktion)).
Anschließend prüft eine **F1-Validierung**:

```dart
final remainingPlaceholders = RegExp(r'\[[A-Z]+_\d{3}\]');
if (remainingPlaceholders.hasMatch(finalText)) {
  _error = 'Rekonstruktion unvollständig: N Platzhalter konnten nicht '
           'aufgelöst werden ([XYZ_001], [ABC_004], …). '
           'Bericht NICHT exportieren!';
}
```

Mögliche Ursachen für ein Rekonstruktions-Fail:

1. **Halluzination** — das LLM hat einen Platzhalter erfunden, den die
   Mapping-Tabelle nicht kennt. Bei guten Modellen (Sonnet 4.6+) selten.
2. **Engine-Bug** — Platzhalter wurde im Pseudonymizing-Text
   nicht korrekt eingefügt. Sollte durch Tests gefangen werden.
3. **Trunkierter Output** — `stop_reason == "max_tokens"` und das LLM
   wurde mitten in einem Platzhalter abgeschnitten.

## Schritt 6 — Quality-Check

`QualityChecker.checkGeneratedText(text, reportType)` läuft auf dem
rekonstruierten Text und sucht nach typischen Schwachstellen je
Berichtstyp:

| Issue-Typ | Bedeutung |
| --- | --- |
| `tooShort` | Bericht hat zu wenige Worte für den Typ |
| `missingSection` | Erwartete Überschrift fehlt |
| `vagueLanguage` | "möglicherweise", "irgendwie", "ein bisschen" — fachlich zu unpräzise |
| `redundantPhrase` | "in Bezug auf" statt direkten Aussagen |
| `placeholderArtifact` | Platzhalter ist sichtbar geblieben |

Die Issues werden im `QualityPanel` angezeigt — die Fachkraft kann sie
ignorieren, korrigieren oder den Bericht neu generieren.

## Schritt 7 — Export

| Format | Implementierung | Verwendungszweck |
| --- | --- | --- |
| PDF (frei) | `pdf_generator.dart` | Eigener Header, alphanumerische Bericht-ID, druckfertig |
| PDF (Formular) | `form_filler_service.dart` | Berliner Standard-Vorlagen — Informationsbericht 1.01 (`assets/templates/informationsbericht_101.pdf`) und MdB-Ges 1.00 (`mdb-ges_100_11_v12sp.pdf`) — werden mit `syncfusion_flutter_pdf` Form-gefüllt |
| TXT | `_exportAsTxt` in `generate_screen.dart` | Roh-Text, kann in Word/LibreOffice nachbearbeitet werden |
| Clipboard | `Clipboard.setData` | Schnelles Einfügen in andere Tools |

## Schritt 8 — Audit-Log

Nach jeder Generierung schreibt die App einen Audit-Eintrag:

```dart
ref.read(auditLogProvider).log(AuditEvent.reportGenerated(
  mappingCount: pseudonymResult.totalReplacements,
  model: response.model,
  reportType: reportType.name,
  inputTokens: response.inputTokens,
  outputTokens: response.outputTokens,
  costUsd: response.costUsd,
));
```

Damit ist nachvollziehbar, *welcher Berichtstyp wann mit welchem Modell
zu welchen Kosten generiert wurde* — ohne dass irgendwelche
Berichtsinhalte oder Personendaten ins Audit-Log gelangen.

## Fehlerpfade

```
┌──── pseudonymize ──── error: keine Notizen ──┐
│                                              │
│  setState(_error = "..."); _step = review    │
└──────────────────────────────────────────────┘

┌──── generate ─────── error: 401 Unauthorized ─┐
│                                                │
│  parse DioException → "API-Fehler: ${msg}"     │
└────────────────────────────────────────────────┘

┌──── reconstruct ──── error: unaufgelöste Platzhalter ─┐
│                                                        │
│  setState(_error = "Bericht NICHT exportieren!");      │
│  Export-Buttons bleiben deaktiviert                    │
└────────────────────────────────────────────────────────┘
```

## Sequenz-Diagramm

```
User    GenerateScreen   Engine   Adapter   LLM        AuditLog
 │             │           │         │        │           │
 │ click       │           │         │        │           │
 │ "Generate"  │           │         │        │           │
 │ ─────────►  │           │         │        │           │
 │             │ pseudonymize()      │        │           │
 │             │ ────────► │         │        │           │
 │             │ ◄──────── │         │        │           │
 │             │  result   │         │        │           │
 │  show preview           │         │        │           │
 │ ◄─────────  │           │         │        │           │
 │             │           │         │        │           │
 │ confirm     │           │         │        │           │
 │ ─────────►  │           │         │        │           │
 │             │ generateReport()    │        │           │
 │             │ ──────────────────► │        │           │
 │             │           │         │ POST   │           │
 │             │           │         │ ─────► │           │
 │             │           │         │ ◄───── │           │
 │             │           │         │ response           │
 │             │ ◄────────────────── │        │           │
 │             │ reconstruct()       │        │           │
 │             │ ────────► │         │        │           │
 │             │ ◄──────── │         │        │           │
 │             │ log()                                    │
 │             │ ───────────────────────────────────────► │
 │  show result                                           │
 │ ◄─────────  │                                          │
 │             │                                          │
```
