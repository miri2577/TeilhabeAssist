# Quickstart

In ungefähr zehn Minuten von der Installation zum ersten Bericht.

## Systemvoraussetzungen

| Plattform | Voraussetzung |
| --- | --- |
| Windows | Windows 10 1809+ oder Windows 11 |
| macOS | macOS 11 (Big Sur) oder neuer |
| Linux | GTK 3.16+, glibc 2.27+ |

Plus mindestens 200 MB freier Festplattenplatz. Es wird kein eigenes
Server-Backend benötigt.

## Installation

### Aus dem Quellcode (Flutter)

```bash
git clone https://github.com/miri2577/FEGH-Bericht.git
cd FEGH-Bericht
flutter pub get
flutter run -d windows   # oder -d macos / -d linux
```

Für Production-Builds:

```bash
flutter build windows --release
flutter build macos   --release
flutter build linux   --release
```

Die Builds landen in `build/windows/x64/runner/Release/`,
`build/macos/Build/Products/Release/` bzw. `build/linux/x64/release/bundle/`.

> **Flutter-SDK fehlt?** Anleitung unter
> https://docs.flutter.dev/get-started/install — bei Windows ist die
> Path-Variable wichtig, sonst findet PowerShell `flutter` nicht.

### Pre-built Releases

Falls du keine Flutter-Toolchain installieren willst, kannst du die
fertigen Binaries aus den GitHub-Releases verwenden, sobald welche
veröffentlicht sind (siehe Tab **Releases** im Repo).

## Erststart

1. **App-Passwort vergeben** — Beim allerersten Start fragt der
   Lock-Screen nach einem persönlichen Passwort (mindestens 8 Zeichen,
   die App zeigt eine Stärke-Indikator-Leiste). Dieses Passwort kann
   **nicht** wiederhergestellt werden. Es schützt das Audit-Log und in
   Zukunft die Pseudonymisierungs-Mappings (siehe
   [Sicherheitsmodell](Sicherheitsmodell)).

2. **Datenschutzerklärung lesen und bestätigen** — Einmalig erforderlich.
   Die elektronische Bestätigung wird mit Name und Zeitstempel im
   Audit-Log abgelegt.

3. **API-Key hinterlegen** — Im Hauptmenü zu *Einstellungen → API* und
   einen Schlüssel für Anthropic oder OpenAI eintragen. Beide werden
   AES-verschlüsselt in der lokalen Hive-Box gespeichert. Der
   Verschlüsselungsschlüssel selbst liegt im OS-Keystore (DPAPI auf
   Windows, Keychain auf macOS, AndroidKeystore auf Android).

   Anthropic-Keys bekommst du unter
   https://console.anthropic.com/settings/keys, OpenAI-Keys unter
   https://platform.openai.com/api-keys.

4. **Modell auswählen** — Empfehlung:
   - Routine-Berichte → `claude-sonnet-4-6` oder `gpt-5.4`
   - Komplexe Fälle / qualitativ höchster Output → `claude-opus-4-7` oder `gpt-5.5`
   - Kostensensitive Massengenerierung → `claude-haiku-4-5-20251001` oder `gpt-5.4-mini`

## Erster Bericht — überfliegen

1. **Neuer Bericht** anlegen — Typ ist *Informationsbericht (Berlin
   Vorlage 1.01)*; BRP wird nicht mehr unterstützt.
2. **Stichpunkte** im Editor erfassen, Module aus der Palette ziehen,
   ggf. Vorbericht und Referenzbericht hochladen.
3. **Generieren** klicken — die App pseudonymisiert lokal, zeigt eine
   Vorschau, fordert eine Pflichtbestätigung an und sendet erst dann den
   pseudonymisierten Text an das LLM. Die Antwort wird zurück-übersetzt.
4. **Qualität prüfen**, ggf. nachbessern.
5. **Exportieren** als PDF (mit Formularvorlage) oder TXT.

Die ausführliche Bedienung steht im [Benutzerhandbuch](Benutzerhandbuch).

## Was schief gehen kann

| Symptom | Ursache | Lösung |
| --- | --- | --- |
| Lock-Screen verweigert sich, "Falsches Passwort" trotz korrekter Eingabe | 10+ Fehlversuche, Account 5 Minuten gesperrt | Warten oder 5 Minuten Systemzeit zurückstellen (nicht empfohlen) |
| API-Key wird als ungültig gemeldet | Falscher Key, Provider-Probleme | API-Key in der Provider-Console testen, ggf. Quota prüfen |
| "Bericht NICHT exportieren!" | Rekonstruktion unvollständig | Pseudonymisierung wurde manipuliert oder das Modell hat Platzhalter halluziniert — Bericht neu generieren |

Mehr in [Troubleshooting](Troubleshooting).
