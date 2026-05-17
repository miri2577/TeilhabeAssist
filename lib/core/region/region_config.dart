import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pseudonymization/dictionaries/berlin_institutions.dart';
import '../../features/pseudonymization/dictionaries/berlin_streets.dart';

/// Regionale Konfiguration für Pseudonymisierungs-Dictionaries.
///
/// Die App ist heute auf Berlin (Eingliederungshilfe) zugeschnitten —
/// PLZ-Bereiche, lokale Träger, Berliner Aktenzeichen-Präfixe. Diese
/// Konstanten und Dictionaries sind hier gebündelt, damit ein zukünftiger
/// Ausrollen auf andere Bundesländer/Träger nur einen neuen `RegionConfig`
/// erfordert — kein Eingriff in Engine oder Recognizer.
class RegionConfig {
  const RegionConfig({
    required this.id,
    required this.label,
    required this.institutions,
    required this.streets,
    required this.postalCodePattern,
    required this.aktenzeichenPattern,
  });

  final String id;
  final String label;
  final Set<String> institutions;
  final Set<String> streets;

  /// Regex-String für Postleitzahlen der Region.
  final String postalCodePattern;

  /// Regex-String für Aktenzeichen / Kostenübernahme-IDs der Region.
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

/// Globaler Provider für die aktive Region. Default: Berlin.
/// Kann in Tests oder beim Rollout in andere Regionen überschrieben werden.
final regionConfigProvider = Provider<RegionConfig>((ref) {
  return RegionConfig.berlin;
});
