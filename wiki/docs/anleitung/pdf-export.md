# PDF-Export

FEGH-Bericht erzeugt Berichte als PDF auf zwei Wegen:

1. **Freier PDF-Export** — Eigenes Layout, druckfertig.
2. **Formular-Vorlage** — Die offiziellen Berliner Vorlagen werden mit
   den Bericht-Daten ausgefüllt.

Beide Wege laufen lokal — kein Server-Upload.

## Freier PDF-Export

`lib/features/export/services/pdf_generator.dart` nutzt das `pdf`-Paket
(Pure Dart). Aufbau:

| Element | Beschreibung |
| --- | --- |
| Header | Träger-Name (aus Settings), Berichts-Datum |
| Titel | Berichtstyp + Klient-Name |
| Inhalt | Markdown-formatierter LLM-Output, in PDF-Sätzen gerendert |
| Footer | Seitenzahl, Generierungs-Hash (für Audit) |

Stylesheet:
- Schrift: Roboto (eingebettet)
- Größen: 18pt Titel, 12pt Body, 10pt Footer
- Seitengröße: A4

Das resultierende PDF ist druckfertig, aber **nicht formularkonform**.

## Formular-Vorlage füllen

`lib/features/export/services/form_filler_service.dart` nutzt
`syncfusion_flutter_pdf` (kommerziell lizenziert, in OSS-Version
verfügbar für Privatprojekte).

Die App liefert zwei Vorlagen mit:

| Vorlage | Asset-Pfad |
| --- | --- |
| Informationsbericht 1.01 | `assets/templates/informationsbericht_101.pdf` |
| MdB-Ges 1.00 | `assets/templates/mdb-ges_100_11_v12sp.pdf` |

### Ablauf

```
1. PDF-Vorlage als Bytes lesen
2. PdfDocument.fromBytes()
3. PdfForm.fields durchlaufen
4. Felder mit Bericht-Daten füllen
   - Personalien aus ReportDraft
   - Aktenzeichen aus Modul personalData
   - Berichtszeitraum aus draft.updatedAt-Bereich
   - Freitextfelder mit dem generierten Bericht
5. PdfDocument.save() → neue Bytes
6. Speichern-Dialog (FilePicker)
```

### Feld-Mapping

Die offiziellen Berliner Formulare haben benannte Felder, z.B.:

```
nachname    → draft.personalData.lastName
vorname     → draft.personalData.firstName
geburtsdat  → draft.personalData.dateOfBirth
azkennzeich → draft.personalData.aktenzeichen
bericht_a   → erster Teil des generierten Texts (max. 4000 Zeichen)
bericht_b   → zweiter Teil (Continuation)
…
```

Das Mapping ist im `form_filler_service.dart` hartcodiert, weil die
Feldnamen pro Vorlage stabil sind. Bei Änderungen an der Vorlage muss
das Mapping angepasst werden.

### Limitierungen der PDF-Formulare

- Lange Berichte werden in mehrere Felder gesplittet — das Layout der
  Vorlage gibt die Verteilung vor.
- Wenn ein Feld die Eingabe überschreitet, wird der Text abgeschnitten.
  Die App warnt dann.
- Manche Vorlagen erwarten Datum im Format `dd.mm.yyyy`, andere
  `yyyy-mm-dd`. Das Mapping konvertiert je Feld.

## TXT-Export

Pure-Text-Variante ohne Formatierung. Speichert eine `.txt`-Datei mit
Standard-Dateinamen `Bericht_2026-05-16.txt`. Wird in Word/LibreOffice
geöffnet, übernimmt aber keine Stile.

## Markdown-Anzeige

Im Result-Screen wird der Bericht mit `flutter_markdown` gerendert
(Überschriften, Listen, fette/kursive Hervorhebungen). Beim PDF-Export
werden Markdown-Strukturen in PDF-Equivalente umgewandelt.

## Wasserzeichen und Schutz

Aktuell **kein** Wasserzeichen, **kein** PDF-Passwort. Wenn der Träger
ausgehende Dokumente schützen will:

- Per OS-Tool (PDF-A-Konvertierung, Adobe Acrobat) Wasserzeichen +
  Passwort nachträglich hinzufügen.
- Geplant für eine spätere Version: optionales Wasserzeichen mit
  Träger-Logo und Generierungs-Hash.

## Reproduzierbarkeit

Bei demselben Input + demselben Modell + `temperature: 0` wäre die
Ausgabe theoretisch reproduzierbar. In der Praxis:

- Die App verwendet `temperature: 0.7` als Default — der Output
  variiert zwischen Aufrufen leicht.
- Setze `temperature: 0` im Code (`ReportRequest.temperature`) für
  möglichst reproduzierbare Ergebnisse.

Der Audit-Log dokumentiert Modell, Token-Verbrauch und Kosten — aber
nicht den Bericht selbst (gehört nicht ins Audit-Log, weil PII).

## Druck

`printing`-Paket erlaubt direkten Druck:

```
[ Als PDF ] → [ Drucken ]
```

Wählt den Drucker und sendet das PDF direkt an das System.
