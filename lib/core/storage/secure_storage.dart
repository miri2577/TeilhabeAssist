import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart';
import 'package:teilhabe_assist/features/pseudonymization/models/pseudonym_mapping.dart';

class SecureStorage {
  Box<String>? _encryptedBox;

  bool get isInitialized => _encryptedBox != null && _encryptedBox!.isOpen;

  /// Initialisierung mit Benutzer-Passphrase
  Future<void> init(String passphrase) async {
    final key = _deriveKey(passphrase);
    _encryptedBox = await Hive.openBox<String>(
      'pseudonym_mappings',
      encryptionCipher: HiveAesCipher(key),
    );
  }

  /// Zuordnungstabelle speichern
  Future<void> saveMappings(
    String reportId,
    List<PseudonymMapping> mappings,
  ) async {
    _ensureInitialized();
    final json = jsonEncode(mappings.map((m) => m.toJson()).toList());
    await _encryptedBox!.put(reportId, json);
  }

  /// Zuordnungstabelle laden
  List<PseudonymMapping>? loadMappings(String reportId) {
    _ensureInitialized();
    final json = _encryptedBox!.get(reportId);
    if (json == null) return null;
    final list = jsonDecode(json) as List;
    return list
        .map((e) => PseudonymMapping.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Zuordnungstabelle löschen
  Future<void> deleteMappings(String reportId) async {
    _ensureInitialized();
    await _encryptedBox!.delete(reportId);
  }

  /// Alle Report-IDs abrufen
  List<String> get reportIds {
    _ensureInitialized();
    return _encryptedBox!.keys.cast<String>().toList();
  }

  /// Alle Daten löschen
  Future<void> clearAll() async {
    _ensureInitialized();
    await _encryptedBox!.clear();
  }

  /// Schließen
  Future<void> close() async {
    await _encryptedBox?.close();
    _encryptedBox = null;
  }

  /// Export als verschlüsselter JSON-String (für .teilhabe-Dateien)
  String exportToJson(String reportId) {
    _ensureInitialized();
    final json = _encryptedBox!.get(reportId);
    if (json == null) throw StateError('Report $reportId not found');
    return json;
  }

  /// Import von JSON-String
  Future<void> importFromJson(String reportId, String jsonString) async {
    _ensureInitialized();
    // Validierung: Kann geparst werden?
    final list = jsonDecode(jsonString) as List;
    for (final item in list) {
      PseudonymMapping.fromJson(item as Map<String, dynamic>);
    }
    await _encryptedBox!.put(reportId, jsonString);
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError(
        'SecureStorage nicht initialisiert. Rufe init() mit Passphrase auf.',
      );
    }
  }

  /// PBKDF2-Schlüsselableitung: Passphrase → 32 Byte AES-Key
  Uint8List _deriveKey(String passphrase) {
    final salt = utf8.encode('TeilhabeAssist_v1');
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(
      Uint8List.fromList(salt),
      100000, // 100.000 Iterationen
      32, // 256 Bit
    ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
  }
}
