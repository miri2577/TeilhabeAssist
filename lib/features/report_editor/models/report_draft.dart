import 'package:uuid/uuid.dart';
import 'report_module.dart';

const _uuid = Uuid();

/// Feld-Definition für die strukturierten Stammdaten.
class StammdatenField {
  const StammdatenField({
    required this.key,
    required this.label,
    this.required = false,
    this.kind = StammdatenFieldKind.text,
    this.options = const [],
    this.hint,
  });

  final String key;
  final String label;
  final bool required;
  final StammdatenFieldKind kind;
  final List<String> options; // für dropdown
  final String? hint;
}

enum StammdatenFieldKind {
  text,
  date,
  email,
  phone,
  dropdown, // strict — nur Werte aus options
  autocomplete, // freie Eingabe + Vorschläge aus options
  multiline,
}

/// Kopfdaten-Felder (Bericht-Metadaten).
const List<StammdatenField> kStammdatenKopfFields = [
  StammdatenField(
      key: 'id_kostenuebernahme',
      label: 'ID Kostenübernahme',
      required: true,
      hint: 'z.B. EH-2026-12345'),
  StammdatenField(
      key: 'berichtszeitraum_von',
      label: 'Berichtszeitraum von',
      required: true,
      kind: StammdatenFieldKind.date),
  StammdatenField(
      key: 'berichtszeitraum_bis',
      label: 'Berichtszeitraum bis',
      required: true,
      kind: StammdatenFieldKind.date),
  StammdatenField(
    key: 'leistungstyp',
    label: 'Leistungstyp',
    required: true,
    kind: StammdatenFieldKind.autocomplete,
    options: [
      'Therapeutisch betreutes Einzelwohnen (TBEW)',
      'Betreutes Einzelwohnen (BEW)',
      'Therapeutische Wohngemeinschaft (TWG)',
      'Betreute Wohngemeinschaft (BWG)',
      'Tagesstätte',
      'Tagesstrukturierende Angebote',
      'Zuverdienst',
      'Sozialpädagogische Tagesbetreuung',
      'Familienpflege',
      'Ambulant betreutes Wohnen',
      'Sonstiges',
    ],
  ),
  StammdatenField(
    key: 'leistungserbringer',
    label: 'Leistungserbringer',
    required: true,
    kind: StammdatenFieldKind.autocomplete,
    options: [
      'DASI Berlin gGmbH',
      'Lebenshilfe Berlin gGmbH',
      'Caritas Berlin',
      'Diakonie Berlin',
      'Unionhilfswerk',
      'Volkssolidarität Berlin',
      'Pinel gGmbH',
      'Albatros e.V.',
      'Mittelhof e.V.',
      'Stephanus-Stiftung',
      'Fürst Donnersmarck-Stiftung',
      'Träger gGmbH',
      'Sonstiger Träger',
    ],
  ),
  StammdatenField(
      key: 'kontakt_le',
      label: 'Kontakt LE (E-Mail / Tel)',
      hint: 'Ansprechperson erreichbar unter'),
  StammdatenField(key: 'strasse', label: 'Straße'),
  StammdatenField(key: 'hausnummer', label: 'Hausnummer'),
  StammdatenField(key: 'weitere_adresse', label: 'Weitere Adresse (z.B. c/o)'),
  StammdatenField(key: 'plz', label: 'PLZ'),
  StammdatenField(key: 'ort', label: 'Ort'),
  StammdatenField(
      key: 'teilhabefachdienst',
      label: 'Teilhabefachdienst (Bezirk)',
      hint: 'z.B. Treptow-Köpenick'),
];

/// Persondaten-Felder (Stammdaten der leistungsberechtigten Person).
const List<StammdatenField> kStammdatenPersonFields = [
  StammdatenField(
      key: 'anrede',
      label: 'Anrede',
      required: true,
      kind: StammdatenFieldKind.dropdown,
      options: ['Herr', 'Frau', 'Divers', 'keine Angabe']),
  StammdatenField(key: 'titel', label: 'Titel'),
  StammdatenField(
      key: 'familienname', label: 'Familienname', required: true),
  StammdatenField(key: 'vorname', label: 'Vorname(n)', required: true),
  StammdatenField(key: 'geburtsname', label: 'Geburtsname'),
  StammdatenField(
      key: 'geburtsdatum',
      label: 'Geburtsdatum',
      required: true,
      kind: StammdatenFieldKind.date),
  StammdatenField(key: 'geburtsort', label: 'Geburtsort'),
  StammdatenField(
      key: 'geschlecht',
      label: 'Geschlecht',
      kind: StammdatenFieldKind.dropdown,
      options: ['männlich', 'weiblich', 'divers', 'keine Angabe']),
  StammdatenField(
      key: 'familienstand',
      label: 'Familienstand',
      kind: StammdatenFieldKind.dropdown,
      options: [
        'ledig',
        'verheiratet',
        'verwitwet',
        'geschieden',
        'getrennt lebend',
        'eingetragene Lebenspartnerschaft',
      ]),
  StammdatenField(
      key: 'telefon_festnetz',
      label: 'Telefon (Festnetz)',
      kind: StammdatenFieldKind.phone),
  StammdatenField(
      key: 'telefon_mobil',
      label: 'Telefon (Mobil)',
      kind: StammdatenFieldKind.phone),
  StammdatenField(
      key: 'email', label: 'E-Mail', kind: StammdatenFieldKind.email),
];

/// Alle Felder kombiniert — Reihenfolge: Kopf zuerst, dann Person.
const List<StammdatenField> kStammdatenAllFields = [
  ...kStammdatenKopfFields,
  ...kStammdatenPersonFields,
];

/// Keys der Pflichtfelder.
final List<String> kStammdatenRequired = kStammdatenAllFields
    .where((f) => f.required)
    .map((f) => f.key)
    .toList(growable: false);

enum ReportType {
  informationsbericht('Informationsbericht (Berlin v1.01)'),
  brp('BRP (4. Berliner Fassung)');

  const ReportType(this.label);
  final String label;
}

/// Ausgabe-Schema für den generierten Bericht.
///
/// - `ausfuehrlichTib`: ICF-/TIB-orientierte Aufgliederung pro Ziel
///   (a–h: Leitziel, Sicht Klient, Sicht LE, Förderfaktoren, Barrieren,
///   Umfang Unterstützung, Zielerreichungsgrad, Veränderungsbedarf).
///   Ausführlich und transparent, dupliziert aber Teile der Bedarfs-
///   ermittlung (TIB).
/// - `kompaktOffiziell`: folgt der offiziellen Berliner Vorlage 1.01
///   (Leitziel, Indikator, Erläuterung Zielerreichung, abweichende
///   Einschätzung Klient, Anmerkungen). Kompakter, näher am Formular.
enum ReportSchema {
  ausfuehrlichTib('Ausführlich (TIB / ICF)'),
  kompaktOffiziell('Kompakt (Berliner Vorlage 1.01)');

  const ReportSchema(this.label);
  final String label;
}

class ReportDraft {
  final String id;
  final ReportType type;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Alter Bericht (Copy & Paste)
  String previousReport;

  /// Module in der Reihenfolge des Berichts
  List<ReportModule> modules;

  /// Aktuelle Stichpunkte/Notizen für den neuen Bericht
  /// (zentrale Grundlage für die KI-Generierung)
  String currentNotes;

  /// Optionaler Referenz-Bericht für stilistische Orientierung
  /// (ein besonders gut geschriebener Bericht als Vorlage)
  String referenceReport;

  /// Strukturierte Stammdaten — Vorrang vor Schreibweisen aus Vorberichten.
  /// Werden als Pflichtfelder im Editor gepflegt; verwendete Keys siehe
  /// `kStammdatenKopfKeys` und `kStammdatenPersonKeys`.
  Map<String, String> stammdaten = {};

  /// Generierter Berichtstext (Default-Variante — TIB-Schema, ausführlich).
  /// Bleibt für Rückwärtskompatibilität bestehen und entspricht
  /// `generatedTexts[ReportSchema.ausfuehrlichTib]`.
  String? generatedText;

  /// Beide Schema-Varianten nach paralleler Generierung. Wird vom
  /// Result-Screen genutzt, um zwischen "Ausführlich (TIB)" und
  /// "Kompakt (Berliner Vorlage)" umzuschalten.
  Map<ReportSchema, String> generatedTexts = {};

  /// Strukturierter Output aus den LLM-Adaptern (schema-validiertes JSON).
  /// Wird vom PDF-Form-Filler direkt verwendet — damit keine Regex auf
  /// dem Markdown nötig ist und alle Ziele zuverlässig befüllt werden.
  Map<ReportSchema, Map<String, dynamic>> structuredReports = {};

  /// Aktuell im Result-Screen angezeigte Variante.
  ReportSchema selectedSchema = ReportSchema.ausfuehrlichTib;

  /// Pseudonymisierter Text (der an die API ging)
  String? pseudonymizedText;

  ReportDraft({
    String? id,
    required this.type,
    DateTime? createdAt,
    this.previousReport = '',
    this.currentNotes = '',
    this.referenceReport = '',
    List<ReportModule>? modules,
    Map<String, String>? stammdaten,
    this.generatedText,
    Map<ReportSchema, String>? generatedTexts,
    Map<ReportSchema, Map<String, dynamic>>? structuredReports,
    ReportSchema? selectedSchema,
    this.pseudonymizedText,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = DateTime.now(),
        modules = modules ?? _defaultModules(type),
        stammdaten = stammdaten ?? {},
        generatedTexts = generatedTexts ?? {},
        structuredReports = structuredReports ?? {},
        selectedSchema = selectedSchema ?? ReportSchema.ausfuehrlichTib;

  /// Wahr, wenn alle Pflicht-Stammdatenfelder gefüllt sind.
  bool get hasRequiredStammdaten => kStammdatenRequired
      .every((k) => (stammdaten[k] ?? '').trim().isNotEmpty);

  /// Liste der noch leeren Pflichtfelder (für UI-Hinweise).
  List<String> get missingRequiredStammdaten => kStammdatenRequired
      .where((k) => (stammdaten[k] ?? '').trim().isEmpty)
      .toList();

  /// Erstellt eine Kopie mit überschriebenen Feldern. Andere Felder bleiben
  /// unverändert — wichtig damit z.B. `stammdaten` nicht versehentlich
  /// verloren gehen, wenn nur `previousReport` aktualisiert wird.
  ReportDraft copyWith({
    String? previousReport,
    String? currentNotes,
    String? referenceReport,
    List<ReportModule>? modules,
    Map<String, String>? stammdaten,
    String? generatedText,
    Map<ReportSchema, String>? generatedTexts,
    Map<ReportSchema, Map<String, dynamic>>? structuredReports,
    ReportSchema? selectedSchema,
    String? pseudonymizedText,
  }) {
    return ReportDraft(
      id: id,
      type: type,
      createdAt: createdAt,
      previousReport: previousReport ?? this.previousReport,
      currentNotes: currentNotes ?? this.currentNotes,
      referenceReport: referenceReport ?? this.referenceReport,
      modules: modules ?? this.modules,
      stammdaten: stammdaten ?? this.stammdaten,
      generatedText: generatedText ?? this.generatedText,
      generatedTexts: generatedTexts ?? this.generatedTexts,
      structuredReports: structuredReports ?? this.structuredReports,
      selectedSchema: selectedSchema ?? this.selectedSchema,
      pseudonymizedText: pseudonymizedText ?? this.pseudonymizedText,
    );
  }

  /// Text der aktuell aktiven Schema-Variante, mit Fallback auf das
  /// Legacy-Feld `generatedText`.
  String? get activeGeneratedText =>
      generatedTexts[selectedSchema] ?? generatedText;

  /// Strukturierte Map der aktiven Schema-Variante (falls vorhanden).
  Map<String, dynamic>? get activeStructured =>
      structuredReports[selectedSchema];

  static List<ReportModule> _defaultModules(ReportType type) {
    return switch (type) {
      ReportType.informationsbericht => [
        ReportModule(type: ModuleType.kopfdaten),
        ReportModule(type: ModuleType.persondaten),
        ReportModule(type: ModuleType.allgemeineInfos),
        ReportModule(type: ModuleType.teilhabeziel, goalNumber: 1),
        ReportModule(type: ModuleType.flsUebersicht),
        ReportModule(type: ModuleType.kontextfaktoren),
        ReportModule(type: ModuleType.zusammenfassung),
      ],
      ReportType.brp => [
        ReportModule(type: ModuleType.kopfdaten),
        ReportModule(type: ModuleType.persondaten),
        ReportModule(type: ModuleType.brpLebenssituation),
        ReportModule(type: ModuleType.brpHilfebedarf),
        ReportModule(type: ModuleType.brpHilfebedarfsbemessung),
        ReportModule(type: ModuleType.brpZieleMassnahmen),
        ReportModule(type: ModuleType.flsUebersicht),
        ReportModule(type: ModuleType.zusammenfassung),
      ],
    };
  }

  /// Alle Stichpunkte als zusammenhängenden Text für die KI.
  /// currentNotes (zentrale Stichpunkte) werden prominent vorangestellt.
  String get allNotesAsText {
    final buffer = StringBuffer();

    // Aktuelle Stichpunkte zuerst – das ist der Hauptinput
    if (currentNotes.trim().isNotEmpty) {
      buffer.writeln('## Aktuelle Notizen / Veränderungen');
      buffer.writeln(currentNotes.trim());
      buffer.writeln();
    }

    // Dann die Modul-spezifischen Notizen (Kopfdaten, Persondaten etc.)
    for (final module in modules) {
      if (module.notes.trim().isNotEmpty) {
        buffer.writeln('## ${module.title}');
        buffer.writeln(module.notes.trim());
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}
