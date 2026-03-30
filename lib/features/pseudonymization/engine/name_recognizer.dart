import '../dictionaries/common_words.dart';
import '../dictionaries/first_names.dart';
import '../models/pseudonym_mapping.dart';

class NameMatch {
  final String text;
  final int start;
  final int end;
  final ConfidenceLevel confidence;

  const NameMatch({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
  });
}

class NameRecognizer {
  /// Case-insensitive lookup Sets (built once)
  late final Set<String> _firstNamesLower;
  late final Set<String> _commonWordsLower;

  /// Zusätzliche gelernte Namen (pro Session/Klient)
  final Set<String> _learnedNames = {};

  static final _anredePattern = RegExp(
    r'\b(?:Herr|Frau|Hr\.|Fr\.)\s+'
    r'(?:(?:Dr\.|Prof\.|Dipl\.\-?\w+\.?)\s+)?'
    r'([A-ZÄÖÜ][a-zäöüß]+(?:[\s\-][A-ZÄÖÜ][a-zäöüß]+)*)',
  );

  /// "Arzt/Ärztin Name", "Betreuer Name", "Therapeut Name"
  static final _rolePattern = RegExp(
    r'\b(?:Arzt|Ärztin|Betreuer(?:in)?|Therapeut(?:in)?|Psychiater(?:in)?|'
    r'Psycholog(?:e|in)|Sozialarbeiter(?:in)?|Sozialpädagog(?:e|in)?)\s+'
    r'([A-ZÄÖÜ][a-zäöüß]+(?:[\s\-][A-ZÄÖÜ][a-zäöüß]+)?)',
  );

  NameRecognizer() {
    _firstNamesLower = kFirstNames.map((n) => n.toLowerCase()).toSet();
    _commonWordsLower = kCommonWords.map((w) => w.toLowerCase()).toSet();
  }

  void learnName(String name) => _learnedNames.add(name.toLowerCase());

  List<NameMatch> findNames(String text) {
    final matches = <NameMatch>[];
    final coveredRanges = <(int, int)>[];

    bool isOverlapping(int start, int end) {
      return coveredRanges.any((r) => start < r.$2 && end > r.$1);
    }

    void addMatch(NameMatch m) {
      if (!isOverlapping(m.start, m.end)) {
        matches.add(m);
        coveredRanges.add((m.start, m.end));
      }
    }

    // 1. Hohe Konfidenz: Anrede + Name
    for (final match in _anredePattern.allMatches(text)) {
      addMatch(NameMatch(
        text: match.group(0)!,
        start: match.start,
        end: match.end,
        confidence: ConfidenceLevel.high,
      ));
    }

    // 2. Hohe Konfidenz: Rolle + Name
    for (final match in _rolePattern.allMatches(text)) {
      addMatch(NameMatch(
        text: match.group(0)!,
        start: match.start,
        end: match.end,
        confidence: ConfidenceLevel.high,
      ));
    }

    // 3. Mittlere Konfidenz: Wörterbuch-Match (Vorname im Fließtext)
    final wordPattern = RegExp(r'\b([A-ZÄÖÜ][a-zäöüß]{2,})\b');
    for (final match in wordPattern.allMatches(text)) {
      final word = match.group(1)!;
      if (isOverlapping(match.start, match.end)) continue;

      final wordLower = word.toLowerCase();
      if (_commonWordsLower.contains(wordLower)) continue;

      if (_firstNamesLower.contains(wordLower) ||
          _learnedNames.contains(wordLower)) {
        addMatch(NameMatch(
          text: word,
          start: match.start,
          end: match.end,
          confidence: ConfidenceLevel.medium,
        ));
      }
    }

    // 4. Niedrige Konfidenz: Großgeschriebenes Wort nicht am Satzanfang
    //    (Über-Erkennungs-Strategie)
    final suspiciousPattern = RegExp(
      r'(?<=[a-zäöüß,;:]\s)([A-ZÄÖÜ][a-zäöüß]{2,})',
    );
    for (final match in suspiciousPattern.allMatches(text)) {
      final word = match.group(1)!;
      if (isOverlapping(match.start, match.end)) continue;

      final wordLower = word.toLowerCase();
      if (_commonWordsLower.contains(wordLower)) continue;

      // Nicht schon als mittlere Konfidenz erkannt
      if (!_firstNamesLower.contains(wordLower) &&
          !_learnedNames.contains(wordLower)) {
        addMatch(NameMatch(
          text: word,
          start: match.start + match.group(0)!.indexOf(word),
          end: match.start + match.group(0)!.indexOf(word) + word.length,
          confidence: ConfidenceLevel.low,
        ));
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }
}
