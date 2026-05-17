import 'dart:convert';

import 'package:hive/hive.dart';

/// Persistentes Benutzer-Wörterbuch.
/// Enthält Wörter die von der Fachkraft als "kein Name" markiert wurden.
/// Diese werden bei zukünftigen Pseudonymisierungen nicht mehr geflaggt.
class UserDictionary {
  static const _excludeBoxName = 'user_excluded_words';
  static const _includeBoxName = 'user_learned_names';
  Box<String>? _excludeBox;
  Box<String>? _includeBox;

  Future<void> init() async {
    _excludeBox = await Hive.openBox<String>(_excludeBoxName);
    _includeBox = await Hive.openBox<String>(_includeBoxName);
  }

  bool get isInitialized =>
      _excludeBox != null &&
      _excludeBox!.isOpen &&
      _includeBox != null &&
      _includeBox!.isOpen;

  // --- Ausgeschlossene Wörter (kein Name) ---

  /// Original-Schreibweise der ausgeschlossenen Wörter.
  /// Der NameRecognizer normalisiert für den Lookup selbst auf lowercase.
  Set<String> get excludedWords {
    if (!isInitialized) return {};
    return _excludeBox!.values.toSet();
  }

  List<String> get excludedWordsList {
    if (!isInitialized) return [];
    return _excludeBox!.values.toList()..sort();
  }

  Future<void> excludeWord(String word) async {
    if (!isInitialized) return;
    final normalized = word.trim();
    if (normalized.isEmpty) return;
    if (!_excludeBox!.values.contains(normalized)) {
      await _excludeBox!.add(normalized);
    }
  }

  Future<void> removeExcludedWord(String word) async {
    if (!isInitialized) return;
    final key = _excludeBox!.keys.firstWhere(
      (k) => _excludeBox!.get(k)?.toLowerCase() == word.toLowerCase(),
      orElse: () => null,
    );
    if (key != null) await _excludeBox!.delete(key);
  }

  // --- Gelernte Namen (ist ein Name) ---

  /// Original-Schreibweise der gelernten Namen.
  /// Wichtig für das Phrase-Matching (z.B. "DASI Berlin gGmbH" als ganzes).
  /// Der NameRecognizer normalisiert für den Lookup selbst auf lowercase.
  Set<String> get learnedNames {
    if (!isInitialized) return {};
    return _includeBox!.values.toSet();
  }

  List<String> get learnedNamesList {
    if (!isInitialized) return [];
    return _includeBox!.values.toList()..sort();
  }

  Future<void> learnName(String name) async {
    if (!isInitialized) return;
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    if (!_includeBox!.values.contains(normalized)) {
      await _includeBox!.add(normalized);
    }
  }

  Future<void> removeLearnedName(String name) async {
    if (!isInitialized) return;
    final key = _includeBox!.keys.firstWhere(
      (k) => _includeBox!.get(k)?.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );
    if (key != null) await _includeBox!.delete(key);
  }

  /// Exportiert das gesamte Wörterbuch als JSON-String
  String exportToJson() {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'excludedWords': excludedWordsList,
      'learnedNames': learnedNamesList,
    });
  }

  /// Importiert ein Wörterbuch aus einem JSON-String (merged mit bestehendem)
  Future<int> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    int imported = 0;

    final excluded = (data['excludedWords'] as List?)?.cast<String>() ?? [];
    for (final word in excluded) {
      if (!excludedWords.contains(word.toLowerCase())) {
        await excludeWord(word);
        imported++;
      }
    }

    final names = (data['learnedNames'] as List?)?.cast<String>() ?? [];
    for (final name in names) {
      if (!learnedNames.contains(name.toLowerCase())) {
        await learnName(name);
        imported++;
      }
    }

    return imported;
  }

  Future<void> close() async {
    await _excludeBox?.close();
    await _includeBox?.close();
  }
}
