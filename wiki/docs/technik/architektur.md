# Architektur-Übersicht

FEGH-Bericht ist als klassische **Feature-First** Flutter-App
strukturiert. Module sind nach fachlichen Bereichen (Auth, Pseudonymisierung,
Berichte, Export) gruppiert, nicht nach technischer Schicht.

## Verzeichnisstruktur

```
lib/
├── main.dart                       # Bootstrap: Hive init, Provider-Overrides
├── app.dart                        # MaterialApp + 3-Stufen-Gate (locked → signed → ready)
│
├── core/
│   ├── crypto/
│   │   └── secure_random.dart      # Random.secure()-Seed, constant-time-Compare
│   ├── region/
│   │   └── region_config.dart      # Berliner Dictionaries + PLZ-/Aktenzeichen-Regex
│   ├── routing/
│   │   └── app_router.dart         # go_router-Konfiguration
│   ├── storage/
│   │   ├── audit_log.dart          # Hash-Chained Audit-Trail
│   │   ├── secure_storage.dart     # AES-Box für Pseudonym-Mappings (OS-Keystore)
│   │   ├── settings_storage.dart   # AES-Box für API-Keys (OS-Keystore)
│   │   └── data_reset_service.dart # Vollreset über Settings
│   └── theme/
│       ├── app_settings_provider.dart
│       └── app_theme.dart
│
└── features/
    ├── api/
    │   ├── adapters/               # LLMAdapter, AnthropicAdapter, OpenAIAdapter
    │   ├── models/                 # ReportRequest, ReportResponse
    │   ├── prompts/                # System-Prompts pro Berichtstyp
    │   ├── providers/              # Riverpod: Adapter, API-Keys, Modellwahl
    │   └── services/
    │       └── offline_queue.dart  # Vorbereitet für Offline-Modus
    │
    ├── auth/
    │   ├── auth_service.dart       # PBKDF2 + persistentes Rate-Limit
    │   └── lock_screen.dart        # Setup + Login-Screen
    │
    ├── export/
    │   ├── pdf_export_screen.dart
    │   ├── feedback_dialog.dart
    │   └── services/
    │       ├── pdf_generator.dart      # Freier Bericht → PDF
    │       └── form_filler_service.dart # PDF-Vorlagen ausfüllen
    │
    ├── help/
    │   ├── help_screen.dart
    │   └── wiki_content.dart       # Inline-Hilfe (App-intern)
    │
    ├── onboarding/
    │   └── onboarding_screen.dart  # Beim Erststart
    │
    ├── privacy/
    │   ├── privacy_policy_text.dart   # Vollständige Erklärung
    │   ├── privacy_signature_screen.dart
    │   └── signature_store.dart       # Signatur-Persistenz mit Hash über PolicyText
    │
    ├── pseudonymization/
    │   ├── dictionaries/           # Berliner Träger, Straßen, Vornamen, häufige Wörter
    │   ├── engine/
    │   │   ├── address_recognizer.dart
    │   │   ├── brp_page4_detector.dart
    │   │   ├── learned_names_store.dart
    │   │   ├── name_recognizer.dart
    │   │   ├── pseudonym_engine.dart    # Orchestrierung
    │   │   ├── regex_patterns.dart
    │   │   └── user_dictionary.dart
    │   ├── models/                 # PseudonymCategory, Mapping, Result
    │   ├── providers/
    │   └── ui/                     # Preview, Highlighting, ConfirmationDialog
    │
    ├── report_editor/
    │   ├── generate_screen.dart    # Hauptablauf Pseudonymize → Preview → API → Result
    │   ├── report_editor_screen.dart
    │   ├── models/                 # ReportDraft, ReportModule, ReportTemplate, FLS, ICF
    │   ├── providers/
    │   ├── services/
    │   │   ├── draft_storage.dart
    │   │   ├── pdf_import_service.dart
    │   │   ├── quality_checker.dart
    │   │   └── template_storage.dart
    │   └── widgets/
    │
    └── settings/
        ├── dictionary_screen.dart  # Benutzer-Wörterbuch verwalten
        ├── prompt_editor_screen.dart # Custom System-Prompts
        └── settings_screen.dart
```

## Schichten und Verantwortlichkeiten

```
┌──────────────────────────────────────────────────────────────┐
│  UI Layer (features/*/ui, *_screen.dart)                     │
│  Flutter-Widgets, Material Design 3, Riverpod-Consumer       │
└──────────────────────────────────────────────────────────────┘
                          │ ref.watch / ref.read
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  State / Providers (features/*/providers)                    │
│  Riverpod 2.x — StateProvider, Provider, StateNotifier       │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Domain Logic (features/*/engine, services)                  │
│  Pseudonymisierungs-Engine, QualityChecker, FormFiller       │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Persistence (core/storage, features/*/services/*_storage)   │
│  Hive (AES-256-CBC) + flutter_secure_storage                 │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  External (LLM-Adapter, OS-Keystore, Dateisystem)            │
│  Dio HTTP → Anthropic / OpenAI                               │
└──────────────────────────────────────────────────────────────┘
```

## App-Lebenszyklus

```
┌────────────────────┐
│ main()             │
│ - Hive.initFlutter │
│ - alle Storages    │
│   öffnen           │
│ - SystemPrompts    │
│   laden            │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ ProviderScope      │
│ overrides:         │
│ - apiKeyProvider   │
│ - authService      │
│ - signatureStore   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ FEGH-BerichtApp  │
│ AppGateState:      │
│ locked|signed|ready│
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ MaterialApp.router │
│ go_router          │
└────────────────────┘
```

`main.dart` öffnet absichtlich **alle** Boxen synchron beim Start. Das ist
robust gegen "Race"-Probleme, hat aber den Nachteil, dass die
`SettingsStorage` (mit API-Keys) bereits geöffnet ist, bevor der
Lock-Screen das Passwort verlangt. Diese architektonische Entscheidung wird
durch den OS-Keystore kompensiert: Der Encryption-Key für die Settings-Box
liegt im DPAPI-/Keychain-/AndroidKeystore-Container und ist ohne
OS-Benutzersitzung nicht abrufbar.

## State-Management mit Riverpod

Riverpod wird als zentrales Werkzeug eingesetzt, mit drei Mustern:

1. **Singleton-Services** über `Provider<T>` mit `overrideWithValue` in
   `main.dart` — gilt für `AuthService`, `SignatureStore`, `DraftStorage`,
   `AuditLog`, `UserDictionary`.
2. **State** über `StateProvider` für einfache Werte wie aktuelles Modell,
   API-Key oder selektierter Provider.
3. **Stabile LLM-Adapter** in eigenen `Provider`-Definitionen mit
   `ref.keepAlive()` — damit Dio Connection-Pooling und HTTP-Keep-Alive
   nutzen kann (siehe `lib/features/api/providers/api_providers.dart`).

```dart
final _anthropicAdapterProvider = Provider<AnthropicAdapter>((ref) {
  ref.keepAlive();   // ← verhindert Re-Instantiierung
  return AnthropicAdapter();
});
```

## Routing

`go_router` als deklarative Router-Library. Routen werden in
`lib/core/routing/app_router.dart` gepflegt. Drei Stufen schalten *vor*
dem Router:

| Stufe | Wann |
| --- | --- |
| `locked` | Passwort-Lock-Screen |
| `needsSignature` | Datenschutzerklärung noch nicht unterzeichnet |
| `ready` | Router aktiv, App vollständig nutzbar |

Solange `gate != ready` läuft eine `MaterialApp` ohne Router, danach
wechselt sie zu `MaterialApp.router`. Das ist bewusst — go_router würde
sonst Deep-Links akzeptieren, bevor der User authentifiziert ist.

## Plattform-Spezifika

- **macOS** — Eigene Entitlements (`Runner/Release.entitlements`),
  App Sandbox, Notarisierung möglich.
- **Windows** — Standard-Flutter-Setup. DPAPI über flutter_secure_storage.
- **Linux** — Standard-GTK-Setup. Schlüsselverwaltung via libsecret /
  freedesktop secrets.

## Externe Abhängigkeiten (Auszug)

| Paket | Zweck |
| --- | --- |
| `flutter_riverpod` | State |
| `go_router` | Routing |
| `hive` / `hive_flutter` | Verschlüsselter Local-Storage |
| `flutter_secure_storage` | OS-Keystore-Wrapper |
| `pointycastle` | PBKDF2, AES, Digests |
| `crypto` | SHA-256 für Audit-Log-Chain |
| `dio` | HTTP-Client für LLM-API |
| `pdf` / `printing` | PDF-Generation |
| `syncfusion_flutter_pdf` | Form-Filling existierender PDF-Vorlagen |
| `signature` | Handschriftliche Datenschutz-Signatur |
| `flutter_markdown` | Anzeige der LLM-Antwort |

Alle Abhängigkeiten sind in `pubspec.yaml` mit ihren Versionen fixiert.

## Build-Targets

| Target | Werkzeug |
| --- | --- |
| Windows | `flutter build windows` (Visual Studio Build Tools nötig) |
| macOS | `flutter build macos` (Xcode + Pods) |
| Linux | `flutter build linux` |
| Android (geplant) | `flutter build apk` |
| iOS (geplant) | `flutter build ios` |

Der Web-Build ist derzeit **deaktiviert**, weil Hive-Encryption im Browser
keine sichere Schlüsselablage hat (siehe [Roadmap](Roadmap)).
