import 'package:hive/hive.dart';

/// Persistente Speicherung gelernter Namen.
/// Wenn eine Fachkraft einen unerkannten Namen manuell markiert,
/// wird er hier gespeichert und in zukünftigen Durchläufen erkannt.
class LearnedNamesStore {
  static const _boxName = 'learned_names';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Alle gelernten Namen
  Set<String> get names {
    if (!isInitialized) return {};
    return _box!.values.toSet();
  }

  /// Name hinzufügen
  Future<void> addName(String name) async {
    if (!isInitialized) return;
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    // Prüfe Duplikat
    if (!_box!.values.contains(normalized)) {
      await _box!.add(normalized);
    }
  }

  /// Name entfernen
  Future<void> removeName(String name) async {
    if (!isInitialized) return;
    final key = _box!.keys.firstWhere(
      (k) => _box!.get(k) == name.trim(),
      orElse: () => null,
    );
    if (key != null) await _box!.delete(key);
  }

  /// Alle gelernten Namen löschen
  Future<void> clearAll() async {
    if (!isInitialized) return;
    await _box!.clear();
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
