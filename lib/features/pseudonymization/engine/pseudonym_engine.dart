import '../dictionaries/berlin_institutions.dart';
import '../dictionaries/common_words.dart';
import '../models/pseudonym_category.dart';
import '../models/pseudonym_mapping.dart';
import '../models/pseudonym_result.dart';
import 'address_recognizer.dart';
import 'name_recognizer.dart';
import 'regex_patterns.dart';
import 'user_dictionary.dart';

class PseudonymEngine {
  final List<PseudonymMapping> _mappings = [];
  final Map<PseudonymCategory, int> _counters = {};
  final List<String> _warnings = [];

  final NameRecognizer _nameRecognizer = NameRecognizer();
  final AddressRecognizer _addressRecognizer = AddressRecognizer();

  late final Set<String> _commonWordsLower;

  PseudonymEngine() {
    _commonWordsLower = kCommonWords.map((w) => w.toLowerCase()).toSet();
  }

  /// Lädt Benutzer-Wörterbuch in die Engine
  void loadUserDictionary(UserDictionary dictionary) {
    if (!dictionary.isInitialized) return;
    _nameRecognizer.setExcludedWords(dictionary.excludedWords);
    _nameRecognizer.setLearnedNames(dictionary.learnedNames);
  }

  String _nextPlaceholder(PseudonymCategory cat) {
    _counters[cat] = (_counters[cat] ?? 0) + 1;
    final num = _counters[cat]!.toString().padLeft(3, '0');
    return '[${cat.prefix}_$num]';
  }

  void _addMapping(
    String original,
    PseudonymCategory category,
    ConfidenceLevel confidence,
    int start,
    int end,
  ) {
    // Bei Duplikat: gleichen Platzhalter wiederverwenden
    final existing = _mappings.where(
      (m) => m.original == original && m.category == category,
    );
    if (existing.isNotEmpty) return;

    _mappings.add(PseudonymMapping(
      placeholder: _nextPlaceholder(category),
      original: original,
      category: category,
      confidence: confidence,
      startIndex: start,
      endIndex: end,
    ));
  }

  /// Setzt die Engine komplett zurück
  void reset() {
    _mappings.clear();
    _counters.clear();
    _warnings.clear();
  }

  /// Hauptmethode: Text pseudonymisieren.
  /// Bei erneutem Aufruf auf derselben Engine werden bekannte Mappings
  /// wiederverwendet (gleicher Name → gleicher Platzhalter).
  PseudonymResult pseudonymize(String text, {bool keepMappings = false}) {
    if (!keepMappings) {
      _warnings.clear();
    }

    var cleanText = text;

    // Verarbeitungsreihenfolge: spezifisch → allgemein

    // 1. E-Mail-Adressen (eindeutig durch @)
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.email,
      PseudonymCategory.email,
    );

    // 2. Aktenzeichen / IDs
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.aktenzeichen,
      PseudonymCategory.aktenzeichen,
    );

    // 3. Datumsformate
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.date,
      PseudonymCategory.datum,
    );

    // 4. Telefonnummern
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.phone,
      PseudonymCategory.telefon,
    );

    // 5. Adressen
    cleanText = _replaceAddresses(cleanText);

    // 6. Einrichtungsnamen (VOR Personennamen, da Trägernamen sonst
    //    fälschlich als Personennamen erkannt werden)
    cleanText = _replaceInstitutions(cleanText);

    // 7. Personennamen (Anrede → Wörterbuch → Heuristik)
    cleanText = _replaceNames(cleanText);

    // 8. Validierung
    _validateRemainingPii(cleanText);

    return PseudonymResult(
      cleanText: cleanText,
      mappings: List.unmodifiable(_mappings),
      warnings: List.unmodifiable(_warnings),
    );
  }

  /// Rekonstruktion: Platzhalter durch Originaldaten ersetzen
  String reconstruct(String pseudonymizedText) {
    var result = pseudonymizedText;
    // Längste Platzhalter zuerst, um Teilmatches zu vermeiden
    final sorted = List<PseudonymMapping>.from(_mappings)
      ..sort((a, b) => b.placeholder.length.compareTo(a.placeholder.length));
    for (final mapping in sorted) {
      result = result.replaceAll(mapping.placeholder, mapping.original);
    }
    return result;
  }

  /// Rekonstruktion mit externen Mappings (z.B. aus SecureStorage geladen)
  static String reconstructWith(
    String pseudonymizedText,
    List<PseudonymMapping> mappings,
  ) {
    var result = pseudonymizedText;
    final sorted = List<PseudonymMapping>.from(mappings)
      ..sort((a, b) => b.placeholder.length.compareTo(a.placeholder.length));
    for (final mapping in sorted) {
      result = result.replaceAll(mapping.placeholder, mapping.original);
    }
    return result;
  }

  /// Nachträgliche Validierung auf übriggebliebene PII
  List<String> validateAnonymization(String cleanText) {
    final issues = <String>[];

    // Prüfe auf übrig gebliebene Datumsformate
    for (final match in RegexPatterns.date.allMatches(cleanText)) {
      issues.add(
        'Mögliches Datum gefunden: "${match.group(0)}" – bitte prüfen',
      );
    }

    // Prüfe auf übrig gebliebene Telefonnummern
    for (final match in RegexPatterns.phone.allMatches(cleanText)) {
      issues.add(
        'Mögliche Telefonnummer: "${match.group(0)}" – bitte prüfen',
      );
    }

    // Prüfe auf Wörter die nach Eigennamen aussehen
    final namePattern = RegExp(r'(?<=[a-zäöüß]\s)[A-ZÄÖÜ][a-zäöüß]{2,}');
    for (final match in namePattern.allMatches(cleanText)) {
      final word = match.group(0)!;
      if (!_commonWordsLower.contains(word.toLowerCase())) {
        issues.add('Möglicher Eigenname: "$word" – bitte manuell prüfen');
      }
    }

    return issues;
  }

  /// Namen des NameRecognizer als gelernt markieren
  void learnName(String name) => _nameRecognizer.learnName(name);

  // --- Private Hilfsmethoden ---

  String _replaceByRegex(
    String text,
    RegExp pattern,
    PseudonymCategory category,
  ) {
    return text.replaceAllMapped(pattern, (match) {
      final original = match.group(0)!;
      // ICD-10-Codes NICHT ersetzen
      if (category == PseudonymCategory.datum &&
          RegexPatterns.icd10.hasMatch(original) &&
          original.contains(RegExp(r'^[A-Z]\d'))) {
        return original;
      }
      _addMapping(
        original,
        category,
        ConfidenceLevel.high,
        match.start,
        match.end,
      );
      return _mappings.last.placeholder;
    });
  }

  String _replaceAddresses(String text) {
    final addressMatches = _addressRecognizer.findAddresses(text);
    // Ersetze von hinten nach vorne um Indizes stabil zu halten
    final sorted = List<AddressMatch>.from(addressMatches)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final match in sorted) {
      _addMapping(
        match.text,
        PseudonymCategory.adresse,
        match.confidence,
        match.start,
        match.end,
      );
      text = text.replaceRange(
        match.start,
        match.end,
        _mappings.last.placeholder,
      );
    }
    return text;
  }

  String _replaceNames(String text) {
    final nameMatches = _nameRecognizer.findNames(text);
    final sorted = List<NameMatch>.from(nameMatches)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final match in sorted) {
      final category = match.confidence == ConfidenceLevel.high &&
              match.text.contains(RegExp(
                r'Arzt|Ärztin|Betreuer|Therapeut|Psychiater|Psycholog|Sozial',
              ))
          ? PseudonymCategory.behandler
          : PseudonymCategory.person;

      if (match.confidence == ConfidenceLevel.low) {
        _warnings.add(
          'Möglicher Name erkannt: "${match.text}" – bitte prüfen',
        );
      }

      _addMapping(
        match.text,
        category,
        match.confidence,
        match.start,
        match.end,
      );
      text = text.replaceRange(
        match.start,
        match.end,
        _mappings.last.placeholder,
      );
    }
    return text;
  }

  String _replaceInstitutions(String text) {
    // Sortiere nach Länge (längste zuerst) für korrekte Ersetzung
    final sortedInstitutions = kBerlinInstitutions.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final institution in sortedInstitutions) {
      final pattern = RegExp(
        '\\b${RegExp.escape(institution)}\\b',
        caseSensitive: false,
      );
      text = text.replaceAllMapped(pattern, (match) {
        _addMapping(
          match.group(0)!,
          PseudonymCategory.einrichtung,
          ConfidenceLevel.high,
          match.start,
          match.end,
        );
        return _mappings.last.placeholder;
      });
    }
    return text;
  }

  void _validateRemainingPii(String cleanText) {
    // Übrige Validierung
    final issues = validateAnonymization(cleanText);
    _warnings.addAll(issues);
  }
}
