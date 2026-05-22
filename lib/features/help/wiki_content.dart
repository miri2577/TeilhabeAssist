/// In-App Wiki — Vollständige Dokumentation aller Funktionen.
/// Jedes Kapitel ist ein WikiArticle mit Titel, Icon und Markdown-Inhalt.

import 'package:flutter/material.dart';

class WikiArticle {
  final String id;
  final String title;
  final IconData icon;
  final String markdown;
  final List<String> tags; // Für Suche

  const WikiArticle({
    required this.id,
    required this.title,
    required this.icon,
    required this.markdown,
    this.tags = const [],
  });
}

const wikiArticles = <WikiArticle>[
  // ============================================================
  // 1. ÜBERSICHT
  // ============================================================
  WikiArticle(
    id: 'overview',
    title: 'Was ist FEGH-Bericht?',
    icon: Icons.info_outline,
    tags: ['übersicht', 'einführung', 'start', 'was'],
    markdown: '''
# Was ist FEGH-Bericht?

FEGH-Bericht ist eine KI-gestützte Desktop-Anwendung für Fachkräfte der **Eingliederungshilfe in Berlin**. Die App unterstützt bei der Erstellung von:

- **Informationsberichten** (Berliner Vorlage, Version 1.01)

## Das Grundprinzip

1. **Vorbericht importieren** — Eine bestehende PDF wird eingelesen
2. **Stichpunkte eingeben** — Aktuelle Veränderungen und Beobachtungen notieren
3. **Pseudonymisierung** — Alle personenbezogenen Daten werden automatisch durch Platzhalter ersetzt
4. **KI-Generierung** — Der pseudonymisierte Text wird an die KI gesendet
5. **Rekonstruktion** — Die Platzhalter werden durch die Originaldaten ersetzt
6. **Export** — Als professionelles PDF, Original-Formular oder Text

## Datenschutz-Versprechen

**Personenbezogene Daten verlassen NIEMALS das Gerät.**

Nur pseudonymisierte Texte (z.B. "[PERSON_001] lebt in [ADRESSE_001]") werden an die KI-API gesendet. Die Zuordnung Platzhalter → Originalname existiert ausschließlich lokal auf Ihrem Computer.

## Zeitersparnis

Fachkräfte berichten von einer Reduktion der Berichtszeit von **2-3,5 Stunden auf 30-40 Minuten** pro Bericht.
''',
  ),

  // ============================================================
  // 2. PSEUDONYMISIERUNG
  // ============================================================
  WikiArticle(
    id: 'pseudonymization',
    title: 'Pseudonymisierung',
    icon: Icons.shield_outlined,
    tags: ['pseudonymisierung', 'dsgvo', 'datenschutz', 'platzhalter', 'namen', 'erkennung'],
    markdown: '''
# Pseudonymisierung

Die Pseudonymisierung ist das Herzstück von FEGH-Bericht. Sie stellt sicher, dass keine personenbezogenen Daten an die KI-API übermittelt werden.

## Wie funktioniert es?

Die Pseudonymisierungs-Engine erkennt automatisch:

| Kategorie | Beispiel | Platzhalter |
|-----------|----------|-------------|
| Personen | Max Mustermann | [PERSON_001] |
| Adressen | Musterstraße 42 | [ADRESSE_001] |
| Telefonnummern | 030/12345678 | [TELEFON_001] |
| E-Mail-Adressen | max@example.de | [EMAIL_001] |
| Datumsangaben | 15.03.2026 | [DATUM_001] |
| Aktenzeichen | Az: 123/456 | [AKTENZEICHEN_001] |
| Einrichtungen | DASI Berlin gGmbH | [EINRICHTUNG_001] |

## Über-Erkennung statt Unter-Erkennung

Die Engine arbeitet nach dem Prinzip: **Lieber ein Wort zu viel pseudonymisieren als einen Klarnamen an die API senden.** Daher kann es vorkommen, dass auch Nicht-Namen als Personen erkannt werden. Diese können Sie im Review-Schritt korrigieren.

## Wörterbuch

Unter **Einstellungen → Wörterbuch** können Sie:
- **Ausgeschlossene Wörter** — Wörter die nie als Name erkannt werden sollen (z.B. Fachbegriffe)
- **Gelernte Namen** — Namen die immer erkannt werden sollen

Das Wörterbuch wird über die Zeit besser, je mehr Sie es pflegen.

## Rekonstruktion

Nach der KI-Generierung werden alle Platzhalter automatisch durch die Originaldaten ersetzt. Die App prüft, ob alle Platzhalter aufgelöst wurden. Falls nicht, erhalten Sie eine Warnung.

## Konfidenz-Stufen

Im Pseudonymisierungs-Test (Hauptmenü → Pseudonymisierung testen) sehen Sie farblich markiert:
- 🟢 **Grün** — Sicher erkannt (z.B. bekannter Name im Kontext)
- 🟡 **Orange** — Mittlere Konfidenz (könnte ein Name sein)
- 🔴 **Rot** — Verdachtsstelle (ungewöhnliches Wort, könnte Name sein)
''',
  ),

  // ============================================================
  // 3. PDF-IMPORT
  // ============================================================
  WikiArticle(
    id: 'pdf-import',
    title: 'PDF-Import',
    icon: Icons.picture_as_pdf,
    tags: ['pdf', 'import', 'vorbericht', 'formular', 'drag', 'drop'],
    markdown: '''
# PDF-Import

FEGH-Bericht kann PDF-Dateien direkt importieren und die relevanten Inhalte extrahieren.

## Unterstützte Formate

- **Informationsberichte** (Berliner Vorlage v1.01) — Formularfelder und Freitext
- **Andere PDFs** — Seitentext wird extrahiert
- **Textdateien** (.txt, .md) — Direkt importiert

## So funktioniert der Import

### Per Drag & Drop
Ziehen Sie die PDF-Datei direkt in das Importfeld der App.

### Per Datei-Dialog
Klicken Sie auf "PDF auswählen" und wählen Sie die Datei aus.

## Technischer Hintergrund

Die App nutzt zwei Methoden zur Textextraktion:
1. **Appearance-Stream-Parser** — Liest den gerenderten Text direkt aus den PDF-Zeichenbefehlen. Funktioniert auch bei speziellen Font-Encodings.
2. **Formularfeld-API** — Liest die Formularfeld-Werte als Fallback.
''',
  ),

  // ============================================================
  // 4. BERICHTSERSTELLUNG
  // ============================================================
  WikiArticle(
    id: 'report-creation',
    title: 'Bericht erstellen',
    icon: Icons.edit_document,
    tags: ['bericht', 'erstellen', 'editor', 'module', 'notizen', 'folgebericht', 'erstbericht'],
    markdown: '''
# Bericht erstellen

## Erstbericht vs. Folgebericht

### Erstbericht
Für den ersten Bericht zu einer Person. Sie geben alle Informationen direkt in die Module ein.

### Folgebericht
Basiert auf einem Vorbericht. Sie importieren den vorherigen Bericht (PDF) und geben nur die aktuellen Veränderungen als Stichpunkte ein. Die KI erstellt daraus den aktualisierten Bericht.

## Der Editor

### Module
Der Editor ist in Module unterteilt, die der Berichtsstruktur entsprechen:
- **Kopfdaten** — Berichtszeitraum, Leistungserbringer etc.
- **Persondaten** — Name, Adresse, Geburtsdatum etc.
- **Allgemeine Informationen** — Tagesstruktur, Kontakte
- **Teilhabeziele** — Pro Ziel ein Modul
- **FLS-Übersicht** — Fachleistungsstunden
- **Kontextfaktoren** — Förder- und Barrierefaktoren
- **Zusammenfassung** — Empfehlung

Module können umgeordnet, hinzugefügt und (nicht-Pflichtmodule) entfernt werden.

### Stichpunkte (Folgebericht)
Das Feld "Aktuelle Notizen / Veränderungen" ist der zentrale Input für die KI. Hier tragen Sie ein, was sich seit dem letzten Bericht verändert hat:
- Fortschritte und Rückschritte
- Neue oder geänderte Ziele
- Besondere Vorkommnisse
- FLS-Anpassungen

### Referenz-Bericht (optional)
Sie können zusätzlich einen besonders gut geschriebenen Bericht als **Stilvorlage** laden. Die KI orientiert sich dann am Sprachstil dieses Referenz-Berichts. Klicken Sie im Editor auf "Referenz-Bericht laden".

## Generieren

Nach Klick auf "Generieren" durchläuft der Text folgende Schritte:
1. **Pseudonymisierung** — Automatische Erkennung und Ersetzung
2. **Review** — Sie sehen den kompletten Text (Notizen + Vorbericht) und bestätigen
3. **API-Aufruf** — Der pseudonymisierte Text wird an die KI gesendet
4. **Rekonstruktion** — Platzhalter werden durch Originaldaten ersetzt
5. **Ergebnis** — Der fertige Bericht wird angezeigt
''',
  ),

  // ============================================================
  // 5. KI UND PROMPTS
  // ============================================================
  WikiArticle(
    id: 'ai-prompts',
    title: 'KI-Generierung & Prompts',
    icon: Icons.auto_awesome,
    tags: ['ki', 'ai', 'prompt', 'system', 'anpassen', 'generierung', 'modell'],
    markdown: '''
# KI-Generierung & Prompts

## Wie die KI arbeitet

FEGH-Bericht sendet einen **System-Prompt** (Anweisungen an die KI) zusammen mit dem pseudonymisierten Text an die API. Der System-Prompt definiert:

- **Rolle** — Fachexperte für Eingliederungshilfe Berlin
- **Struktur** — Zwingend einzuhaltende Berichtsstruktur
- **Fachsprache** — ICF-orientiert, ressourcenorientiert, personenzentriert
- **Platzhalter-Regeln** — Die KI darf nur vorhandene Platzhalter verwenden
- **Beispiel-Formulierungen** — Kuratierte Passagen als Stilvorlage

## System-Prompts anpassen

Unter **Einstellungen → KI-Prompts** können Sie die System-Prompts für beide Berichtstypen bearbeiten. Das ist nützlich wenn Sie:
- Den Stil anpassen möchten
- Zusätzliche Fachbegriffe einführen wollen
- Die Berichtsstruktur modifizieren müssen
- Eigene Beispiel-Formulierungen hinzufügen wollen

Der Standard-Prompt kann jederzeit wiederhergestellt werden.

## Unterstützte API-Anbieter

| Anbieter | Modelle | Einstellung |
|----------|---------|-------------|
| **Anthropic** | Claude Sonnet 4, Claude Haiku 4.5 | API-Key in Einstellungen |
| **OpenAI** | GPT-5.4, GPT-5.4-mini, GPT-4o | API-Key in Einstellungen |

## Kosten

Die Token-Kosten werden nach jeder Generierung angezeigt. Typische Kosten pro Bericht:
- **GPT-5.4-mini**: ~0,02-0,05 €
- **Claude Sonnet 4**: ~0,05-0,15 €
- **GPT-5.4**: ~0,05-0,10 €

## Platzhalter-Regeln

Die KI wurde angewiesen:
- **NUR** vorhandene Platzhalter zu verwenden
- **NIEMALS** eigene Platzhalter zu erfinden
- Bei fehlenden Daten "[ANGABE FEHLT]" zu schreiben
- Platzhalter-Nummern nicht zu ändern
''',
  ),

  // ============================================================
  // 6. EXPORT
  // ============================================================
  WikiArticle(
    id: 'export',
    title: 'Export-Optionen',
    icon: Icons.download,
    tags: ['export', 'pdf', 'speichern', 'drucken', 'formular', 'txt'],
    markdown: '''
# Export-Optionen

Nach der Berichtsgenerierung stehen mehrere Export-Formate zur Verfügung:

## Professionelles PDF
Eigenständiges, druckfertiges A4-Dokument mit professionellem Layout:
- Blauer Kopfbalken mit Titel
- Strukturierte Kopfdaten-Tabelle
- Automatische Seitenumbrüche
- Seitennummerierung und Footer
- Unterschriftenfelder

## Original-Formular befüllen
Befüllt das offizielle Berliner Informationsbericht-Formular (v1.01) — die Formularfelder werden automatisch mit den Metadaten befüllt, der Berichtstext wird in die Freitextbereiche eingesetzt.

## Nur Text (TXT)
Reiner Text zum Kopieren in andere Programme.

## Zwischenablage
Text direkt in die Zwischenablage kopieren zum Einfügen in andere Formulare.

## Speichern unter
In der PDF-Vorschau können Sie über das Speichern-Symbol die Datei an einem beliebigen Ort speichern.
''',
  ),

  // ============================================================
  // 7. DATENSCHUTZ
  // ============================================================
  WikiArticle(
    id: 'privacy',
    title: 'Datenschutz & DSGVO',
    icon: Icons.lock_outline,
    tags: ['datenschutz', 'dsgvo', 'api', 'lokal', 'verschlüsselung', 'sicherheit'],
    markdown: '''
# Datenschutz & DSGVO

## Was bleibt auf Ihrem Gerät?

**ALLES** außer dem pseudonymisierten Text:

| Daten | Speicherort | Verschlüsselung |
|-------|-------------|-----------------|
| API-Keys | Lokal (Hive) | AES-256 |
| Pseudonymisierungs-Mappings | Lokal (Hive) | AES-256 + PBKDF2 |
| Wörterbücher | Lokal (Hive) | Nein (keine PII) |
| Berichte/Entwürfe | Lokal (Hive) | Nein |
| Datenschutz-Bestätigung | Lokal (Hive) | Nein |
| Audit-Log | Lokal (Hive) | Nein |

## Was wird an die API gesendet?

**Ausschließlich pseudonymisierter Text.** Beispiel:

> ❌ "Herr Müller lebt in der Musterstraße 42 in Berlin."
>
> ✅ "[PERSON_001] lebt in [ADRESSE_001] in [ADRESSE_002]."

Die KI sieht **niemals** echte Namen, Adressen, Telefonnummern oder andere personenbezogene Daten.

## Audit-Log

Alle sicherheitsrelevanten Aktionen werden protokolliert:
- Berichtsgenerierungen (mit Modell, Token, Kosten)
- Pseudonymisierungs-Durchläufe (Anzahl Ersetzungen)
- API-Aufrufe

Das Audit-Log kann unter **Einstellungen → Audit-Log exportieren** als JSON-Datei gespeichert werden.

## App-Passwort

Optional können Sie ein Passwort für die App setzen. Dieses wird beim Start abgefragt und schützt vor unbefugtem Zugriff.

## Datenschutzerklärung

Unter **Einstellungen → Datenschutz & Recht** finden Sie die vollständige Datenschutzerklärung. Diese muss beim ersten Start bestätigt werden.
''',
  ),

  // ============================================================
  // 9. EINSTELLUNGEN
  // ============================================================
  WikiArticle(
    id: 'settings',
    title: 'Einstellungen',
    icon: Icons.settings_outlined,
    tags: ['einstellungen', 'api', 'key', 'modell', 'theme', 'wörterbuch', 'prompt'],
    markdown: '''
# Einstellungen

## Darstellung
- **Theme** — Hell, Dunkel oder Systemstandard
- **Textgröße** — Skalierung von 80% bis 140%

## API-Konfiguration
- **Anbieter** — Anthropic (Claude) oder OpenAI (GPT)
- **Modell** — Wählen Sie das gewünschte KI-Modell
- **API-Key** — Ihr persönlicher API-Schlüssel. Wird verschlüsselt gespeichert.
- **Key prüfen** — Testet ob der API-Key gültig ist

### API-Key erhalten
- **Anthropic**: [console.anthropic.com](https://console.anthropic.com) → API Keys
- **OpenAI**: [platform.openai.com](https://platform.openai.com) → API Keys

## Wörterbuch
Verwalten Sie die Pseudonymisierungs-Regeln:
- **Ausgeschlossene Wörter** — Werden nie als Name erkannt
- **Gelernte Namen** — Werden immer als Name erkannt
- **Export/Import** — Wörterbuch als JSON sichern oder laden

## KI-Prompts
Bearbeiten Sie den System-Prompt für den Informationsbericht. Der Standard-Prompt kann jederzeit wiederhergestellt werden.

## Datenschutz & Recht
- Datenschutzerklärung lesen und bestätigen
- Audit-Log exportieren

## Info & Daten
- Über FEGH-Bericht
- **Alle Daten löschen** — Setzt die gesamte App zurück (API-Keys, Wörterbücher, Einstellungen)
''',
  ),

  // ============================================================
  // 10. QUALITÄTSPRÜFUNG
  // ============================================================
  WikiArticle(
    id: 'quality',
    title: 'Qualitätsprüfung',
    icon: Icons.fact_check_outlined,
    tags: ['qualität', 'prüfung', 'warnung', 'fehler', 'check'],
    markdown: '''
# Qualitätsprüfung

FEGH-Bericht prüft den generierten Bericht automatisch auf Qualitätsprobleme.

## Automatische Prüfungen

### Vor der Generierung
- **Pseudonymisierung vollständig?** — Alle erkannten Daten ersetzt?
- **Eingabedaten ausreichend?** — Genug Stichpunkte vorhanden?

### Nach der Generierung
- **Platzhalter aufgelöst?** — Alle [PERSON_001] etc. durch Originaldaten ersetzt?
- **Berichtslänge** — Warnung wenn der Bericht ungewöhnlich kurz ist (< 200 Wörter)
- **Strukturvollständigkeit** — Alle erwarteten Abschnitte vorhanden?

## Manuelle Prüfung

**WICHTIG:** Die KI-Generierung ersetzt NICHT die fachliche Prüfung!

Prüfen Sie immer:
- ✅ Fachliche Korrektheit der Inhalte
- ✅ Korrekte Zuordnung der Teilhabeziele
- ✅ Angemessene Formulierungen
- ✅ Keine erfundenen Fakten (Halluzinationen)
- ✅ Richtige FLS-Angaben
- ✅ Vollständige Rekonstruktion der Personendaten
''',
  ),

  // ============================================================
  // 11. FEHLERBEHEBUNG
  // ============================================================
  WikiArticle(
    id: 'troubleshooting',
    title: 'Fehlerbehebung',
    icon: Icons.build_outlined,
    tags: ['fehler', 'problem', 'hilfe', 'api', 'crash', 'leer'],
    markdown: '''
# Fehlerbehebung

## "API-Key ungültig"
- Prüfen Sie ob der Key korrekt kopiert wurde (keine Leerzeichen)
- Prüfen Sie ob Sie den richtigen Anbieter ausgewählt haben
- Testen Sie den Key mit "API-Key prüfen" in den Einstellungen

## Bericht ist leer oder sehr kurz
- Prüfen Sie ob genügend Stichpunkte eingegeben wurden
- Prüfen Sie ob der Vorbericht korrekt importiert wurde
- Versuchen Sie ein anderes KI-Modell

## PDF-Import liest keine Daten
- Stellen Sie sicher, dass die PDF Formularfelder enthält (Berliner Vorlagen)
- Bei normalen PDFs (ohne Formularfelder) wird der Seitentext extrahiert
- Manche gescannte PDFs enthalten keinen maschinenlesbaren Text

## Pseudonymisierung erkennt zu viel / zu wenig
- Nutzen Sie das **Wörterbuch** (Einstellungen) um Wörter auszuschließen oder Namen zu lernen
- Im Review-Schritt können Sie einzelne Erkennungen korrigieren

## Platzhalter im fertigen Bericht
- Die KI hat möglicherweise neue Platzhalter erfunden
- Gehen Sie zurück zum Editor und generieren Sie erneut
- Prüfen Sie den System-Prompt auf korrekte Platzhalter-Regeln

## App reagiert nicht
- Schließen Sie die App und starten Sie neu
- Bei anhaltenden Problemen: Einstellungen → Alle Daten löschen
''',
  ),

  // ============================================================
  // 12. TASTATURKÜRZEL
  // ============================================================
  WikiArticle(
    id: 'shortcuts',
    title: 'Tipps & Tricks',
    icon: Icons.lightbulb_outline,
    tags: ['tipps', 'tricks', 'schnell', 'effizient', 'workflow'],
    markdown: '''
# Tipps & Tricks

## Effizienter Workflow

1. **Vorbericht per Drag & Drop** — Ziehen Sie die PDF direkt ins Fenster
2. **Stichpunkte kurz halten** — Die KI macht aus Stichpunkten Fließtext
3. **Referenz-Bericht nutzen** — Laden Sie Ihren besten Bericht als Stilvorlage
4. **Wörterbuch pflegen** — Spart Zeit bei wiederholter Pseudonymisierung

## Optimale Stichpunkte

**Schlecht:**
> "Alles gut."

**Besser:**
> "- Wohnsituation stabil, Wohnung wird selbstständig gehalten
> - 3x/Woche Termine, gute Mitwirkung
> - Werkstatt-Besuch abgebrochen, sucht Alternativen
> - FLS von 480 auf 520 erhöhen wg. erhöhtem Bedarf bei Behördengängen"

## KI-Modell wählen

- **Schnell & günstig**: GPT-5.4-mini oder Claude Haiku → gut für Routine-Berichte
- **Beste Qualität**: GPT-5.4 oder Claude Sonnet 4 → für komplexe Fälle
- **Tipp**: Probieren Sie verschiedene Modelle und vergleichen Sie die Ergebnisse

## Datensicherung

- Exportieren Sie regelmäßig Ihr **Wörterbuch** (Einstellungen → Wörterbuch exportieren)
- Exportieren Sie das **Audit-Log** für Ihre Dokumentation
- Benutzerdefinierte **Prompts** werden automatisch gespeichert
''',
  ),
];
