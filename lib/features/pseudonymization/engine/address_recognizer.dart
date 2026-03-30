import '../dictionaries/berlin_streets.dart';
import '../models/pseudonym_mapping.dart';

class AddressMatch {
  final String text;
  final int start;
  final int end;
  final ConfidenceLevel confidence;

  const AddressMatch({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
  });
}

class AddressRecognizer {
  /// Pattern: "Straßenname Hausnummer" (mit optionaler PLZ + Ort)
  static final _streetWithNumber = RegExp(
    r'([A-ZÄÖÜ][a-zäöüß]+(?:[\s\-][A-Za-zäöüßÄÖÜ]+)*'
    r'(?:str(?:aße|\.)|weg|platz|allee|damm|ring|ufer|zeile|gasse|pfad|chaussee|promenade|steig))'
    r'\s*(\d{1,4}\s*[a-zA-Z]?)'
    r'(\s*,?\s*\d{5}\s+[A-ZÄÖÜ][a-zäöüß]+)?',
    caseSensitive: false,
  );

  /// Pattern: PLZ + Berlin
  static final _plzBerlin = RegExp(
    r'\b(1(?:0\d{3}|1\d{3}|2\d{3}|3\d{3}|4[01]\d{2}))\s+Berlin\b',
  );

  AddressRecognizer();

  List<AddressMatch> findAddresses(String text) {
    final matches = <AddressMatch>[];
    final coveredRanges = <(int, int)>[];

    bool isOverlapping(int start, int end) {
      return coveredRanges.any((r) => start < r.$2 && end > r.$1);
    }

    // 1. Bekannte Berliner Straßen mit Hausnummer → hohe Konfidenz
    for (final street in kBerlinStreets) {
      final pattern = RegExp(
        '${RegExp.escape(street)}\\s*\\d{1,4}\\s*[a-zA-Z]?'
        '(\\s*,?\\s*\\d{5}\\s+[A-ZÄÖÜ][a-zäöüß]+)?',
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(text)) {
        if (!isOverlapping(match.start, match.end)) {
          matches.add(AddressMatch(
            text: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: ConfidenceLevel.high,
          ));
          coveredRanges.add((match.start, match.end));
        }
      }
    }

    // 2. Generisches Straßen-Pattern mit Hausnummer → mittlere Konfidenz
    for (final match in _streetWithNumber.allMatches(text)) {
      if (!isOverlapping(match.start, match.end)) {
        matches.add(AddressMatch(
          text: match.group(0)!,
          start: match.start,
          end: match.end,
          confidence: ConfidenceLevel.medium,
        ));
        coveredRanges.add((match.start, match.end));
      }
    }

    // 3. PLZ Berlin Pattern → mittlere Konfidenz
    for (final match in _plzBerlin.allMatches(text)) {
      if (!isOverlapping(match.start, match.end)) {
        matches.add(AddressMatch(
          text: match.group(0)!,
          start: match.start,
          end: match.end,
          confidence: ConfidenceLevel.medium,
        ));
        coveredRanges.add((match.start, match.end));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }
}
