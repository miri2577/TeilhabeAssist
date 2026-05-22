# Region-Konfiguration

FEGH-Bericht ist heute auf das **Berliner Berichtswesen für die
Eingliederungshilfe** zugeschnitten. Wenn die App in anderen
Bundesländern oder Verbänden eingesetzt werden soll, sind mehrere
Bestandteile region-spezifisch — und müssen ausgetauscht werden.

## Was ist region-spezifisch?

| Bestandteil | Berlin-Default | Anpassbar? |
| --- | --- | --- |
| Postleitzahlen-Bereich | 10115 – 14199 | Ja, Regex in `RegionConfig` |
| Aktenzeichen-Format | `EH/EGH/SGB/TH/GPV` + Jahr + Nr. | Ja |
| Trägerinstitutionen | `kBerlinInstitutions` | Ja |
| Straßennamen-Dictionary | `kBerlinStreets` | Ja |
| Berichts-Vorlagen (PDF-Formular) | Informationsbericht 1.01. Berliner Fassung | Ja, neue Vorlagen als Assets + Field-Mapping |
| System-Prompts | Berliner Format-Vorgaben | Ja, Custom-Prompts pro Region |

## RegionConfig

`lib/core/region/region_config.dart`

```dart
class RegionConfig {
  final String id;
  final String label;
  final Set<String> institutions;
  final Set<String> streets;
  final String postalCodePattern;
  final String aktenzeichenPattern;

  static final berlin = RegionConfig(
    id: 'berlin',
    label: 'Berlin (Eingliederungshilfe)',
    institutions: kBerlinInstitutions,
    streets: kBerlinStreets,
    postalCodePattern:
        r'\b(1(?:0\d{3}|1\d{3}|2\d{3}|3\d{3}|4[01]\d{2}))\b',
    aktenzeichenPattern:
        r'\b(?:EH|EGH|SGB|TH|GPV)[\-/]\d{4}[\-/]\d{3,6}(?:[\-/][A-Z]{1,3})?\b',
  );
}

final regionConfigProvider = Provider<RegionConfig>((ref) {
  return RegionConfig.berlin;
});
```

Aktuelle Engine-Implementierung greift noch nicht überall auf
`regionConfigProvider` zu — das ist Schritt 2 (siehe unten).

## Schritt 1 — Neue Region anlegen

Beispiel für Hamburg (BTHG-Eingliederungshilfe):

1. Neue Dictionary-Datei `lib/features/pseudonymization/dictionaries/hamburg_institutions.dart`:

```dart
const kHamburgInstitutions = <String>{
  'Diakonisches Werk Hamburg',
  'Caritas Hamburg',
  'Awo Hamburg',
  'PARITÄTISCHER Hamburg',
  'Leben mit Behinderung Hamburg',
  // …
};
```

2. Straßen-Dictionary `hamburg_streets.dart` mit Hamburger Geo-Daten
   (typisch: aus OpenStreetMap exportieren — Straßennamen pro
   Bundesland sind ~5000–15 000 Einträge).

3. Erweiterung in `region_config.dart`:

```dart
static final hamburg = RegionConfig(
  id: 'hamburg',
  label: 'Hamburg (BTHG)',
  institutions: kHamburgInstitutions,
  streets: kHamburgStreets,
  postalCodePattern: r'\b(2[01]\d{3})\b',         // 20000–21999
  aktenzeichenPattern: r'\b(?:EGH|BTHG)[\-/]\d{4}[\-/]\d{3,6}\b',
);
```

4. UI: In *Einstellungen → Region* kann der User aus der Liste wählen.
   `regionConfigProvider` wird dann mit `ref.refresh` neu geladen.

## Schritt 2 — Engine an `RegionConfig` koppeln (offener Refactor)

Aktuell hartcodiert in `address_recognizer.dart`:

```dart
final _plzBerlin = RegExp(r'\b(1(?:0\d{3}|...)\s+Berlin\b');
```

Zukünftiger Refactor:

```dart
class AddressRecognizer {
  AddressRecognizer({required this.region});
  final RegionConfig region;

  late final _plzPattern = RegExp(
    '${region.postalCodePattern}\\s+' + region.cityName + r'\b'
  );
  // …
}
```

Plus die Wörter-Dictionaries (`institutions`, `streets`) werden über
`region.institutions` / `region.streets` geladen, nicht aus
top-level-Konstanten.

Diese Migration ist **noch offen** — siehe [Roadmap](Roadmap).

## Schritt 3 — PDF-Vorlagen ergänzen

Andere Bundesländer haben eigene Formulare:

- Hamburg: BTHG-Hilfeplan
- Bayern: Hilfeplan-Bogen Bayern
- NRW: LWL-/LVR-Bögen
- Niedersachsen: BTHG-Gesamtplan

Pro Vorlage:

1. PDF unter `assets/templates/<region>_<typ>_<version>.pdf` ablegen.
2. Pfad in `pubspec.yaml` registrieren.
3. Field-Mapping in `form_filler_service.dart` ergänzen.
4. Test mit Sample-Daten.

## Schritt 4 — System-Prompts anpassen

Pro Region/Träger kann der System-Prompt variieren — z.B. weil
Hamburg eine andere Berichtsstruktur erwartet. Drei Optionen:

1. **Custom-Prompt pro Region** in `system_prompts.dart` als
   Map `<RegionId, String>`.
2. **Custom-Prompt pro Träger** über die UI (*Einstellungen → System-Prompt*)
   — wird in `SettingsStorage.customInfoPrompt` /
   `customBrpPrompt` persistiert.
3. **Template-System** — Prompts mit Variablen
   (`{REGION_NAME}`, `{TRAEGER}`) und einer Template-Engine.

Aktuell ist (2) implementiert; (1) und (3) sind in der [Roadmap](Roadmap).

## Schritt 5 — Lokale Eigenheiten

Pro Region kommen unter Umständen weitere Anpassungen:

- **Anrede**: in Süddeutschland "Grüß Gott", in Norden "Moin" — irrelevant
  für die Pseudonymisierung, aber relevant für den Sprachduktus
  (Referenzberichte!).
- **Spezielle Diagnosen / ICF-Module**: regionale Schwerpunkte können
  in der Module-Palette voreingestellt werden.
- **Datumsformat**: durchgehend `dd.MM.yyyy` in DACH — aber bei Export
  in englischsprachige Träger evtl. ISO-Format.

## Migration bestehender Daten

Wenn ein Träger von Berlin auf Hamburg umstellt:

- **Bestehende Berichte** bleiben pseudonymisierbar — die alten Mappings
  enthalten die Berliner Adressen, die werden weiter erkannt.
- **Neue Berichte** nutzen die neue Region.
- **User-Wörterbuch** ist user-spezifisch, nicht region-spezifisch —
  bleibt unverändert.

## Test-Checkliste für eine neue Region

1. Mindestens 50 Sample-Adressen aus der Region — alle werden erkannt?
2. Mindestens 20 Aktenzeichen im regionalen Format — Erkennung +
   keine False Positives?
3. 10 typische Trägernamen — keine Personen-Verwechslung?
4. End-to-End-Bericht im Trockenlauf mit Mock-LLM — Output
   strukturell korrekt?
5. PDF-Form-Filling — alle Felder befüllt, keine Trunkierung?

## Beispiel: Bayern

```dart
static final bayern = RegionConfig(
  id: 'bayern',
  label: 'Bayern (Eingliederungshilfe BTHG)',
  institutions: kBayernInstitutions,    // Lebenshilfe BY, Diakonie BY, …
  streets: kBayernStreets,
  postalCodePattern: r'\b(8\d{4}|9[0-6]\d{3})\b',   // ~80000–96999
  aktenzeichenPattern: r'\b(?:BTHG|EH-By)[\-/]\d{4}[\-/]\d{3,6}\b',
);
```

Plus eine zugehörige `assets/templates/bayern_hilfeplan_v2.pdf` mit
korrektem Field-Mapping.
