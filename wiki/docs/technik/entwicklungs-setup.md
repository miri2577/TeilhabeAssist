# Entwicklungs-Setup

Für alle, die FEGH-Bericht erweitern, debuggen oder forken.

## Voraussetzungen

| Werkzeug | Version | Hinweis |
| --- | --- | --- |
| Flutter SDK | ≥ 3.24 (Stable Channel) | Dart 3.9 oder höher |
| IDE | VS Code, Android Studio, IntelliJ | Dart- und Flutter-Plugin installieren |
| Git | beliebig | Für Repo-Operationen |
| Windows-Build | Visual Studio 2022 mit "Desktop Development with C++" | Plattform-Tools, Build-SDKs |
| macOS-Build | Xcode 15+, CocoaPods | Apple-Entwickler-Konto für Notarisierung |
| Linux-Build | clang, ninja-build, libgtk-3-dev, libsecret-1-dev | Standard-Build-Toolchain |

### Flutter installieren

```bash
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"   # bzw. PowerShell: $env:Path
flutter doctor
```

`flutter doctor` muss alle Komponenten mit ✓ zeigen, bevor du baust.

## Repo klonen

```bash
git clone https://github.com/miri2577/FEGH-Bericht.git
cd FEGH-Bericht
flutter pub get
```

## Erststart in der Entwicklung

```bash
flutter run -d windows   # bzw. -d macos / -d linux
```

Hot Reload mit `r`, Hot Restart mit `R`, Beenden mit `q`.

### Debug vs. Release

| Modus | Befehl | Eignung |
| --- | --- | --- |
| Debug | `flutter run` | Hot Reload, Inspector, Logs |
| Profile | `flutter run --profile` | Performance-Messung |
| Release | `flutter run --release` | Endbenutzer-Build |

Im Debug-Mode sind zusätzliche Assertions aktiv. Für UX-Tests
**Release-Build** verwenden — die Startzeit ist deutlich kürzer.

## Plattform-Build

```bash
# Windows
flutter build windows --release
# → build/windows/x64/runner/Release/teilhabe_assist.exe

# macOS
flutter build macos --release
# → build/macos/Build/Products/Release/teilhabe_assist.app

# Linux
flutter build linux --release
# → build/linux/x64/release/bundle/teilhabe_assist
```

## Tests laufen

```bash
flutter test                                   # alle Tests
flutter test test/features/pseudonymization/   # nur Pseudonymisierung
flutter test --coverage                        # mit Coverage-Report
```

Coverage-Report wird unter `coverage/lcov.info` abgelegt. Für ein
HTML-Render:

```bash
brew install lcov   # macOS — auf Windows: choco install lcov
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Lint

```bash
flutter analyze
```

Lint-Konfiguration in `analysis_options.yaml` — basiert auf
`flutter_lints` plus einige projektspezifische Ergänzungen.

Vor jedem Commit prüfen:

```bash
flutter analyze && flutter test
```

## VS Code-Setup

`.vscode/settings.json` (nicht in Git, lokal anlegen):

```jsonc
{
  "dart.flutterSdkPath": "C:/Users/<USER>/flutter",
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.rulers": [80, 100],
  "files.exclude": {
    "**/.dart_tool": true,
    "**/build": true
  }
}
```

Empfohlene Extensions:
- Dart-Code.dart-code (Dart-Sprachsupport)
- Dart-Code.flutter (Flutter-Tools)
- ms-vscode.hexeditor (Hive-Files anschauen — read-only)

## Hot-Reload-Falsstricke

Hot-Reload funktioniert *nicht* für:

- Änderungen an `main()`
- Statische Felder (`static const`)
- Neue oder umbenannte enum-Werte
- Hive-Box-Initialisierungen
- Provider-Overrides in `ProviderScope`

Bei diesen Änderungen Hot Restart (`R`) oder voller Neustart nötig.

## Build-Probleme

### Windows: "MSBuild not found"

Visual Studio Installer öffnen, "Desktop Development with C++"-Workload
+ Windows 10 SDK installieren.

### macOS: "CocoaPods not installed"

```bash
sudo gem install cocoapods
cd macos && pod install
```

### Linux: "Could not find libsecret"

```bash
sudo apt install libsecret-1-dev
```

### "Plugin xy depends on registrar"

Geneuerter Plugin-Registrant ist out-of-sync. Lösung:

```bash
flutter clean
flutter pub get
```

## Code-Stil

- `dart format --line-length=80` vor jedem Commit
- Variablen-Namen in `lowerCamelCase`, Klassen in `UpperCamelCase`,
  Konstanten in `kCamelCase` oder `SCREAMING_SNAKE` (Konvention im
  Projekt: `kFoo`)
- Imports gruppiert: `dart:*`, `package:flutter/*`, `package:*`, dann
  relative Imports
- Doc-Kommentare `///` für public APIs, Inline-Kommentare nur, wenn der
  Code nicht offensichtlich ist

## Dependencies aktualisieren

```bash
flutter pub outdated         # zeigt veraltete Packages
flutter pub upgrade          # ohne Major-Bumps
flutter pub upgrade --major-versions   # mit Major-Bumps (Vorsicht!)
```

Major-Bumps **nicht ohne Test-Lauf** mergen. Insbesondere `hive`,
`pointycastle` und `flutter_secure_storage` sind sicherheitsrelevant.

## Release-Checkliste

1. Version in `pubspec.yaml` erhöhen (`version: 0.3.0+3`)
2. `CHANGELOG.md` aktualisieren
3. `flutter analyze` ohne Fehler
4. `flutter test` alle grün
5. Plattform-Builds (Win/Mac/Linux) testen
6. GitHub-Release mit Binaries pushen
7. Wiki ggf. aktualisieren
8. Audit-Log-Tests gegen Migration testen — Hash-Chain-Migration darf
   keine bestehenden Einträge invalidieren
