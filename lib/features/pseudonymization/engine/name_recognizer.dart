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

  /// Vom Benutzer ausgeschlossene Wörter (kein Name)
  Set<String> _excludedWords = {};

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
  void excludeWord(String word) => _excludedWords.add(word.toLowerCase());
  void setExcludedWords(Set<String> words) => _excludedWords = words;
  void setLearnedNames(Set<String> names) =>
      _learnedNames.addAll(names);

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
      if (_excludedWords.contains(wordLower)) continue;

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

    // 4. Niedrige Konfidenz: DEAKTIVIERT
    //    Im Deutschen sind ALLE Substantive großgeschrieben.
    //    Die Heuristik produziert bei Fachtext (Eingliederungshilfe)
    //    fast nur False Positives. Schritte 1-3 (Anrede, Wörterbuch,
    //    gelernte Namen) sind ausreichend für die Erkennung.
    //    Unbekannte Namen werden über die Lernfunktion ergänzt.

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  /// Prüft ob ein Wort wie ein deutsches Substantiv aussieht (kein Name).
  /// Deutsche Substantive haben typische Suffixe die Namen nie haben.
  static bool _looksLikeGermanNoun(String wordLower) {
    const nounSuffixes = [
      'ung', 'keit', 'heit', 'tion', 'sion', 'ment', 'nis', 'schaft',
      'tät', 'enz', 'anz', 'ismus', 'ität', 'eur', 'ling', 'chen',
      'lein', 'tum', 'sal', 'sel', 'icht', 'ive', 'oge', 'thek',
      'phie', 'gie', 'mie', 'pie', 'rie', 'sie', 'bie', 'die',
      'fie', 'lie', 'nie', 'vie', 'zie',
      // Verbale Substantive / Gerundien
      'ieren', 'ieren',
      // Adjektiv-Substantive
      'iges', 'iges',
    ];

    for (final suffix in nounSuffixes) {
      if (wordLower.endsWith(suffix) && wordLower.length > suffix.length + 2) {
        return true;
      }
    }

    // Wörter mit typischen Vorsilben die auf Substantive hindeuten
    const nounPrefixes = [
      'ver', 'vor', 'über', 'unter', 'ein', 'aus', 'auf', 'ab',
      'an', 'be', 'er', 'ent', 'zer', 'miss', 'um', 'mit',
      'nach', 'neben', 'zwischen', 'gegen', 'wieder', 'rück',
    ];

    // Wenn Vorsilbe + Rest > 8 Zeichen → wahrscheinlich Substantiv
    if (wordLower.length > 8) {
      for (final prefix in nounPrefixes) {
        if (wordLower.startsWith(prefix)) return true;
      }
    }

    return false;
  }
}
