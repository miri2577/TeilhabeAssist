/// Wörter, die im deutschen Berichtswesen der Eingliederungshilfe
/// **immer** großgeschrieben sind. LLMs (besonders bei längeren Texten)
/// vergessen das gelegentlich — wir korrigieren still nach.
///
/// Die Liste enthält Substantive und Eigennamen. Adjektive und Verben
/// sind absichtlich NICHT enthalten, weil sie kleingeschrieben werden.
const List<String> kCanonicalCapitalized = [
  // ─── Behörden & Kostenträger ─────────────────────────────────
  'Sozialamt',
  'Sozialämter',
  'Jobcenter',
  'Bezirksamt',
  'Bezirksämter',
  'Standesamt',
  'Versorgungsamt',
  'Gesundheitsamt',
  'Jugendamt',
  'Familienkasse',
  'Krankenkasse',
  'Pflegekasse',
  'Rentenversicherung',
  'Rentenversicherungsträger',
  'Bundesagentur',
  'Arbeitsagentur',
  'Arbeitsamt',
  'Sozialgericht',
  'Verwaltungsgericht',
  'Senatsverwaltung',
  'Senatsverwaltung für Soziales',
  'Teilhabefachdienst',
  'Sozialpsychiatrischer Dienst',
  'Senat',
  'Bezirk',

  // ─── Fachbegriffe Eingliederungshilfe ─────────────────────────
  'Eingliederungshilfe',
  'Teilhabe',
  'Teilhabeplan',
  'Teilhabeplanung',
  'Teilhabeziel',
  'Teilhabeziele',
  'Teilhabebericht',
  'Informationsbericht',
  'Behandlungsplan',
  'Rehabilitationsplan',
  'Fachleistungsstunde',
  'Fachleistungsstunden',
  'Bezugsbetreuer',
  'Bezugsbetreuerin',
  'Bezugsbetreuung',
  'Bezugsperson',
  'Leistungserbringer',
  'Leistungsberechtigte',
  'Leistungsberechtigter',
  'Kostenübernahme',
  'Kostenträger',
  'Klient',
  'Klientin',
  'Hilfebedarf',
  'Hilfebedarfsgruppe',
  'Berichtszeitraum',
  'Leistungszeitraum',
  'Leitziel',
  'Handlungsziel',
  'Maßnahme',
  'Maßnahmen',
  'Zielerreichung',
  'Lebensführung',
  'Versorgung',
  'Versorgungslage',
  'Lebenssituation',
  'Lebensbereich',
  'Lebensbereiche',
  'Kontextfaktor',
  'Kontextfaktoren',
  'Förderfaktor',
  'Förderfaktoren',
  'Umweltfaktor',
  'Umweltfaktoren',
  'Barriere',
  'Barrieren',
  'Mitwirkungsbereitschaft',
  'Ressourcen',
  'Belastbarkeit',
  'Selbstversorgung',
  'Selbstständigkeit',
  'Alltagsbewältigung',
  'Alltagsstrukturierung',
  'Tagesstruktur',
  'Sozialraum',
  'Wohnsituation',
  'Wohnumfeld',
  'Wohngemeinschaft',
  'Werkstatt',
  'Werkstätten',
  'Tagesstätte',
  'Tagesstätten',
  'Treffpunkt',
  'Treffpunkte',
  'Frühstücksgruppe',
  'Mittagstisch',

  // ─── Akteure & Rollen ─────────────────────────────────────────
  'Klient',
  'Klientin',
  'Therapeut',
  'Therapeutin',
  'Psychotherapeut',
  'Psychotherapeutin',
  'Sozialarbeiter',
  'Sozialarbeiterin',
  'Sozialpädagoge',
  'Sozialpädagogin',
  'Ergotherapeut',
  'Ergotherapeutin',
  'Psychiater',
  'Psychiaterin',
  'Psychologe',
  'Psychologin',
  'Hausarzt',
  'Hausärztin',
  'Augenarzt',
  'Augenärztin',
  'Facharzt',
  'Fachärztin',
  'Betreuer',
  'Betreuerin',

  // ─── Wohnen & Versorgung ─────────────────────────────────────
  'Wohnung',
  'Wohnen',
  'Mietvertrag',
  'Mietverhältnis',
  'Vermieter',
  'Vermieterin',
  'Wohnberechtigungsschein',

  // ─── Rechtliches ─────────────────────────────────────────────
  'Schwerbehinderung',
  'Schwerbehindertenausweis',
  'Pflegegrad',
  'Grundsicherung',
  'Sozialhilfe',
  'Arbeitslosengeld',
  'Bürgergeld',
  'Antrag',
  'Bescheid',
  'Widerspruch',
  'Verwaltungsakt',

  // ─── Berliner Träger (Eigennamen) ────────────────────────────
  'Lebenshilfe',
  'Caritas',
  'Diakonie',
  'AWO',
  'DRK',
  'Paritätischer',
  'Albatros',
  'Pinel',
  'Mittelhof',
  'Stephanus',
  'Unionhilfswerk',
  'Volkssolidarität',
  'Fürst Donnersmarck-Stiftung',

  // ─── ICF / Klassifikationen ──────────────────────────────────
  'ICF',
  'ICD',
  'BTHG',
  'SGB',
  'BGB',
  'TBEW',
  'BEW',
  'BWG',
  'TWG',
];

/// Korrigiert die Großschreibung kanonischer Substantive in einem Text.
///
/// Geht durch die Liste `kCanonicalCapitalized` und ersetzt jedes
/// Vorkommen (case-insensitive, mit Word-Boundaries) durch die kanonische
/// Schreibweise. Eigennamen und Behörden-Begriffe sind damit zuverlässig
/// großgeschrieben — auch wenn das LLM sie klein gesetzt hat.
String correctCapitalization(String text) {
  if (text.isEmpty) return text;
  var result = text;
  // Nach Länge absteigend, damit längere Wörter zuerst matchen
  // (verhindert dass "Amt" "Sozialamt" verfälscht).
  final sorted = List<String>.from(kCanonicalCapitalized)
    ..sort((a, b) => b.length.compareTo(a.length));
  // Statt `\b` nutzen wir explizite Lookbehind/Lookahead. Grund: Dart's
  // `\b` ist ASCII-only — Umlaute zählen nicht als Wortzeichen. Damit
  // matchen Kurzformen wie "BEW" auch mitten in "Bewältigen", weil
  // zwischen "BEW" und "ä" ein `\b` greift. Mit dem expliziten Set
  // (inkl. Umlaute und ß) wird das korrekt ignoriert.
  const wordChar = r"[A-Za-z0-9_äöüßÄÖÜ]";
  for (final canonical in sorted) {
    final pattern = RegExp(
      '(?<!$wordChar)' + RegExp.escape(canonical) + '(?!$wordChar)',
      caseSensitive: false,
    );
    result = result.replaceAllMapped(pattern, (m) {
      final matched = m.group(0)!;
      if (matched == canonical) return matched;
      return canonical;
    });
  }
  return result;
}

/// Wendet die Großschreibungs-Korrektur rekursiv auf alle String-Werte
/// eines JSON-Objekts an (Mirror zu `reconstructMap`).
Map<String, dynamic> capitalizeMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    out[key] = _capitalizeValue(value);
  });
  return out;
}

dynamic _capitalizeValue(dynamic value) {
  if (value is String) return correctCapitalization(value);
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k.toString()] = _capitalizeValue(v);
    });
    return out;
  }
  if (value is List) {
    return value.map(_capitalizeValue).toList();
  }
  return value;
}
