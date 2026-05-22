# Troubleshooting

Häufige Probleme und ihre Lösungen.

## App startet nicht

### Symptom: "No Windows desktop project configured"
**Diagnose:** Das Projekt hat noch keinen Windows-Build-Ordner.
**Lösung:**

```bash
cd FEGH-Bericht
flutter create --platforms=windows .
flutter run -d windows
```

### Symptom: "MSBuild not found" auf Windows
**Diagnose:** Visual Studio 2022 mit C++-Toolchain fehlt.
**Lösung:** Visual Studio Installer öffnen → "Modify" → "Desktop
development with C++" + "Windows 10 SDK" installieren.

### Symptom: App-Fenster bleibt schwarz
**Diagnose:** Hive-Box konnte nicht geöffnet werden (Berechtigungs- oder
Korruptionsproblem).
**Lösung:**

```bash
# Windows
del /S "%APPDATA%\teilhabe_assist\*.hive*"

# macOS / Linux
rm -rf ~/.local/share/teilhabe_assist/
```

⚠️ Datenverlust — alle Berichte und Einstellungen weg.

## Lock-Screen

### Symptom: "Falsches Passwort" trotz korrekter Eingabe
**Diagnose 1:** Capslock aktiv. Prüfe Eingabe.
**Diagnose 2:** Anti-Brute-Force-Sperre aktiv.
- Mehr als 5 Fehlversuche → 30 Sekunden Sperre.
- Mehr als 10 → 5 Minuten Sperre.
- Sperre überlebt App-Neustart.

**Lösung:** Warten. Bei vergessenem Passwort gibt es keinen Recovery —
**Reset über**: App löschen + Hive-Boxen löschen (siehe oben).

### Symptom: "Lockout-Zeit läuft nicht ab"
**Diagnose:** Systemzeit wurde manipuliert oder die App lief offline.
**Lösung:** Systemzeit korrigieren. Falls dauerhaft kaputt: Reset.

## API-Key

### Symptom: "API-Key ungültig" beim Speichern
**Diagnose:** Test-Request gegen Provider hat 401/403 erhalten.
**Lösung:**
1. Key im Provider-Dashboard verifizieren
   - Anthropic: https://console.anthropic.com → API Keys
   - OpenAI: https://platform.openai.com → API keys
2. Bei Anthropic prüfen: Format `sk-ant-…`, kein Truncate.
3. Bei OpenAI prüfen: Format `sk-…` oder `sk-proj-…`.
4. Quota / Billing prüfen.

### Symptom: "Rate Limit reached"
**Diagnose:** Provider-Rate-Limit erreicht (z.B. zu viele parallele
Berichte).
**Lösung:** Kurze Pause. Bei häufigem Auftreten: Tier-Upgrade beim
Provider oder kleineres Modell wählen.

## Pseudonymisierung

### Symptom: Engine erkennt einen offensichtlichen Namen nicht
**Diagnose:** Name ist nicht im Wörterbuch und nicht gelernt.
**Lösung:**
1. In der Preview den Namen markieren → "Als Name lernen" — kommt in den
   `learned_names_store`.
2. *Einstellungen → Wörterbuch → Eintrag hinzufügen*.

### Symptom: Engine markiert ein normales Wort als Namen (False Positive)
**Diagnose:** Wort ist im Vornamen-Wörterbuch oder gelernten Store.
**Lösung:**
1. Preview: Wort markieren → "Ausschließen".
2. *Einstellungen → Wörterbuch → Excluded Words → Eintrag hinzufügen*.

### Symptom: "Rekonstruktion unvollständig" — Bericht NICHT exportieren!
**Diagnose:** Das LLM hat einen Platzhalter im Output, den die Mapping-
Tabelle nicht kennt. Häufige Ursachen:
1. LLM hat einen Platzhalter halluziniert (`[PERSON_999]`).
2. Output wurde mitten in einem Platzhalter abgeschnitten (`stop_reason
   == "max_tokens"`).
3. Engine-Bug.

**Lösung:**
1. Modell wechseln (Sonnet 4.6 ist robuster als Haiku 4.5).
2. Output-Token-Limit erhöhen (in `ReportRequest.maxTokens`).
3. Bericht neu generieren — meist behebt das den Fehler.
4. Falls reproduzierbar: Issue im Repo melden mit anonymisiertem
   Beispiel.

## LLM-Generierung

### Symptom: Bericht ist zu kurz / zu lang
**Diagnose:** System-Prompt oder Modell-Wahl.
**Lösung:**
1. Größeres Modell wählen (Opus 4.7 / GPT-5.5 schreiben länger).
2. *Einstellungen → System-Prompt* — Custom-Prompt mit
   Längen-Vorgaben.
3. Mehr Stichpunkte erfassen — das Modell entwickelt sie aus.

### Symptom: Bericht enthält "Wenn du möchtest, kann ich noch …"
**Diagnose:** KI-typische Schlussfloskel.
**Lösung:** Die App entfernt diese automatisch (`_stripAiClosingText`).
Falls nicht: Issue melden.

### Symptom: Bericht hat halluzinierte Fakten
**Diagnose:** Das LLM hat aus den Stichpunkten unzulässig erweitert.
**Lösung:**
1. Stichpunkte präziser formulieren.
2. Modell wechseln (Opus 4.7 halluziniert weniger als Haiku 4.5).
3. **In jedem Fall: Bericht händisch korrigieren!** Die LLM-Ausgabe
   ist ein Vorschlag, nicht die endgültige Wahrheit.

### Symptom: Stream bricht mit "FormatException" ab
**Diagnose:** UTF-8-Chunk ist mitten in einer Mehrbyte-Sequenz gerissen.
**Lösung:** Seit 0.2.0 sollte das nicht mehr vorkommen — der Adapter
nutzt `Utf8Decoder().bind(stream)`. Falls doch: Issue melden.

## PDF-Export

### Symptom: PDF-Felder bleiben leer
**Diagnose:** Field-Mapping in `form_filler_service.dart` passt nicht
zur PDF-Vorlage.
**Lösung:**
1. PDF in Adobe Reader öffnen, Field-Namen prüfen.
2. Mapping anpassen.

### Symptom: PDF-Text wird abgeschnitten
**Diagnose:** Bericht ist länger als das Vorlage-Feld erlaubt.
**Lösung:** Bericht händisch kürzen, oder freien PDF-Export wählen
(ohne Vorlage).

### Symptom: "Drucker nicht gefunden"
**Diagnose:** `printing`-Paket findet keinen Drucker.
**Lösung:** Erst als PDF speichern, dann mit System-PDF-Viewer drucken.

## Audit-Log

### Symptom: `chainValid: false` beim Export
**Diagnose 1:** Legacy-Einträge (vor Hash-Chain-Migration) vorhanden.
**Lösung:** Beim ersten Eintrag nach 0.2.0 startet eine frische Chain.
Im DSB-Report explizit darauf hinweisen.

**Diagnose 2:** Datei wurde manipuliert.
**Lösung:** Sofort dem DSB melden. Eventuell forensische Analyse.

## Datenresets

### Symptom: Nach Reset startet die App nicht mehr
**Diagnose:** Hive-Boxen sind komplett gelöscht, aber OS-Keystore
hat noch alte Einträge.
**Lösung:**

```bash
# Manuell OS-Keystore-Einträge löschen
# Windows: certmgr.msc → "Persönlich" → suche nach "teilhabe_assist"
# macOS: Schlüsselbundverwaltung → Suche "teilhabe_assist" → löschen
```

## Performance

### Symptom: Pseudonymisierung dauert > 5 Sekunden
**Diagnose:** Sehr großer Text (>20 KB) oder sehr großes
User-Dictionary.
**Lösung:**
1. Vorbericht in Module aufteilen.
2. Dictionary aufräumen (gelernte Namen, die nicht mehr relevant sind,
   löschen).

### Symptom: App-Start dauert > 10 Sekunden
**Diagnose:** Audit-Log mit >10 000 Einträgen, alle werden beim
`init()` geladen.
**Lösung:**
1. Audit-Log exportieren und archivieren.
2. *Einstellungen → Audit-Log → "Älter als 6 Monate löschen"*.

## Debug-Hilfen

### Verbose-Logs aktivieren

```bash
flutter run --verbose
```

Plus in `main.dart` Debug-Provider aktivieren:

```dart
ProviderScope(
  observers: [LoggerProviderObserver()],
  …
)
```

### Hive-Box inspizieren (nur Debug-Builds)

```dart
// in lib/main.dart, nach Hive.init
if (kDebugMode) {
  print('Hive path: ${Hive.defaultDirectory}');
  for (final name in ['auth_data', 'audit_log', ...]) {
    if (Hive.boxExists(name)) {
      print('$name: ${Hive.box(name).length} entries');
    }
  }
}
```

⚠️ **Niemals** in Release-Builds aktivieren — würde PII loggen.

### Network-Traffic mitschneiden

```bash
# mitmproxy für lokales Debugging
mitmproxy -p 8080
# Dann Dio-Adapter auf Proxy umstellen:
_dio.options.connectTimeout = Duration(seconds: 30);
_dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () => HttpClient()
    ..findProxy = (_) => 'PROXY localhost:8080',
);
```

⚠️ Sicherheits-Hinweis: Pseudonymisierter Text ist im mitmproxy
sichtbar — okay (das ist genau das, was beim Provider ankommt). Aber
NIE den Klartext-Bericht durch einen Proxy schicken.

## Issue-Report

Wenn du einen Bug öffnest, bitte beifügen:

1. App-Version (`pubspec.yaml` → `version`)
2. OS + Version
3. Flutter-Doctor-Output (`flutter doctor -v`)
4. Schritte zur Reproduktion
5. **Anonymisierte** Beispiel-Eingaben (keine echten Sozialdaten!)
6. Stacktrace oder Screenshot des Fehlers

Issues unter https://github.com/miri2577/FEGH-Bericht/issues.
