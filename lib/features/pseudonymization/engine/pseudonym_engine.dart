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

  /// Fügt ein Mapping hinzu oder gibt das bestehende zurück, wenn das
  /// gleiche (original, category) bereits gemappt ist. Liefert in beiden
  /// Fällen den **richtigen** Platzhalter — wichtig, damit Aufrufer nicht
  /// `_mappings.last.placeholder` lesen müssen (das wäre nach einem
  /// Duplikat-Skip falsch, siehe Regression "Herr Frisch" → EINRICHTUNG).
  String _addMapping(
    String original,
    PseudonymCategory category,
    ConfidenceLevel confidence,
    int start,
    int end,
  ) {
    for (final m in _mappings) {
      if (m.original == original && m.category == category) {
        return m.placeholder;
      }
    }
    final placeholder = _nextPlaceholder(category);
    _mappings.add(PseudonymMapping(
      placeholder: placeholder,
      original: original,
      category: category,
      confidence: confidence,
      startIndex: start,
      endIndex: end,
    ));
    return placeholder;
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

    // 3. Datumsformate (numerisch, mit Monatsname, Geburtsjahr im Kontext)
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.date,
      PseudonymCategory.datum,
    );
    cleanText = _replaceByRegex(
      cleanText,
      RegexPatterns.dateWithMonthName,
      PseudonymCategory.datum,
    );
    cleanText = _replaceBirthYears(cleanText);

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

    // Prüfe auf übrig gebliebene Datumsformate (numerisch + Monatsname)
    for (final match in RegexPatterns.date.allMatches(cleanText)) {
      issues.add(
        'Mögliches Datum gefunden: "${match.group(0)}" – bitte prüfen',
      );
    }
    for (final match in RegexPatterns.dateWithMonthName.allMatches(cleanText)) {
      issues.add(
        'Mögliches Datum gefunden: "${match.group(0)}" – bitte prüfen',
      );
    }
    for (final match in RegexPatterns.birthYear.allMatches(cleanText)) {
      issues.add(
        'Mögliches Geburtsjahr: "${match.group(0)}" – bitte prüfen',
      );
    }

    // Prüfe auf übrig gebliebene Telefonnummern
    for (final match in RegexPatterns.phone.allMatches(cleanText)) {
      issues.add(
        'Mögliche Telefonnummer: "${match.group(0)}" – bitte prüfen',
      );
    }

    // Namens-Heuristik deaktiviert – produziert bei deutschem Fachtext
    // zu viele False Positives. Stattdessen: Wörterbuch + Lernfunktion.

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
      return _addMapping(
        original,
        category,
        ConfidenceLevel.high,
        match.start,
        match.end,
      );
    });
  }

  /// Ersetzt das Jahr (Capture-Gruppe 1) im "geboren 1985"-Kontext durch
  /// einen Platzhalter — der umgebende Anker ("geboren", "Jg.") bleibt
  /// erhalten, damit der Bericht lesbar bleibt.
  String _replaceBirthYears(String text) {
    final matches = RegexPatterns.birthYear.allMatches(text).toList();
    if (matches.isEmpty) return text;

    final buffer = StringBuffer();
    var cursor = 0;
    for (final m in matches) {
      buffer.write(text.substring(cursor, m.start));
      final yearStart = m.start + m.group(0)!.indexOf(m.group(1)!);
      final yearEnd = yearStart + m.group(1)!.length;
      // Prefix (z.B. "geboren ") unverändert übernehmen
      buffer.write(text.substring(m.start, yearStart));
      final placeholder = _addMapping(
        m.group(1)!,
        PseudonymCategory.datum,
        ConfidenceLevel.high,
        yearStart,
        yearEnd,
      );
      buffer.write(placeholder);
      cursor = m.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  String _replaceAddresses(String text) {
    final addressMatches = _addressRecognizer.findAddresses(text);
    // Ersetze von hinten nach vorne um Indizes stabil zu halten
    final sorted = List<AddressMatch>.from(addressMatches)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final match in sorted) {
      final placeholder = _addMapping(
        match.text,
        PseudonymCategory.adresse,
        match.confidence,
        match.start,
        match.end,
      );
      text = text.replaceRange(match.start, match.end, placeholder);
    }
    return text;
  }

  String _replaceNames(String text) {
    final nameMatches = _nameRecognizer.findNames(text);
    final sorted = List<NameMatch>.from(nameMatches)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final match in sorted) {
      final category = _categorize(match);

      if (match.confidence == ConfidenceLevel.low) {
        _warnings.add(
          'Möglicher Name erkannt: "${match.text}" – bitte prüfen',
        );
      }

      final placeholder = _addMapping(
        match.text,
        category,
        match.confidence,
        match.start,
        match.end,
      );
      text = text.replaceRange(match.start, match.end, placeholder);
    }
    return text;
  }

  /// Wählt die passende Kategorie für einen Namen-Match.
  ///
  /// - Sieht der Match wie eine Organisation/Einrichtung aus
  ///   (GmbH, gGmbH, AG, e.V., Stiftung, Werkstatt, Gesellschaft, GbR, …),
  ///   wird er als `einrichtung` markiert. Das ist für gelernte Phrasen
  ///   wie "DASI Berlin gGmbH" entscheidend, damit sie als
  ///   `[EINRICHTUNG_NNN]` und nicht als `[PERSON_NNN]` erscheinen.
  /// - Steht im Match eine berufliche Rolle (Arzt, Therapeut, Sozial…),
  ///   wird er als `behandler` markiert.
  /// - Sonst: `person`.
  PseudonymCategory _categorize(NameMatch match) {
    final text = match.text;
    if (RegExp(
      r'\b(?:g?GmbH|AG|KGaA|UG|OHG|GbR|e\.\s*V\.?|gAG|'
      r'Stiftung|Werkstatt|Werkstätten|Gesellschaft|Verein|'
      r'Träger|Diakonie|Caritas|Klinik|Klinikum|Krankenhaus|'
      r'Lebenshilfe)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return PseudonymCategory.einrichtung;
    }
    if (match.confidence == ConfidenceLevel.high &&
        text.contains(RegExp(
          r'Arzt|Ärztin|Betreuer|Therapeut|Psychiater|Psycholog|Sozial',
        ))) {
      return PseudonymCategory.behandler;
    }
    return PseudonymCategory.person;
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
        return _addMapping(
          match.group(0)!,
          PseudonymCategory.einrichtung,
          ConfidenceLevel.high,
          match.start,
          match.end,
        );
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
