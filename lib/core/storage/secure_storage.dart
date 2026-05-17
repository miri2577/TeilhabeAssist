import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'package:teilhabe_assist/core/crypto/secure_random.dart';
import 'package:teilhabe_assist/features/pseudonymization/models/pseudonym_mapping.dart';

/// Verschlüsselte Speicherung der Pseudonymisierungs-Zuordnungstabellen.
///
/// Der AES-256-Schlüssel wird im OS-Keystore (DPAPI auf Windows, Keychain auf
/// macOS/iOS, EncryptedSharedPreferences mit AndroidKeystore auf Android)
/// abgelegt — nicht mehr in einer unverschlüsselten Hive-Box neben den Daten.
class SecureStorage {
  static const _boxName = 'pseudonym_mappings';
  static const _keychainKey = 'teilhabe_assist.pseudonym_mappings_key';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Box<String>? _encryptedBox;

  bool get isInitialized => _encryptedBox != null && _encryptedBox!.isOpen;

  Future<void> init() async {
    final key = await _getOrCreateBoxKey();
    _encryptedBox = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  /// Holt den AES-Key aus dem OS-Keystore oder erzeugt einen neuen.
  ///
  /// Migration: Falls ein Legacy-Key in der alten `app_settings_key`-Hive-Box
  /// liegt, wird er übernommen und die alte Box gelöscht.
  Future<Uint8List> _getOrCreateBoxKey() async {
    final existing = await _secure.read(key: _keychainKey);
    if (existing != null) {
      return base64Decode(existing);
    }

    // Legacy-Migration: alter Key aus unverschlüsselter Box übernehmen
    final legacyKey = await _migrateLegacyMappingKey();
    if (legacyKey != null) {
      await _secure.write(
        key: _keychainKey,
        value: base64Encode(legacyKey),
      );
      return legacyKey;
    }

    final fresh = secureRandomBytes(32);
    await _secure.write(key: _keychainKey, value: base64Encode(fresh));
    return fresh;
  }

  Future<Uint8List?> _migrateLegacyMappingKey() async {
    // In der alten Implementierung gab es keinen separaten Key für die
    // Mapping-Box — Hive nutzte ihn aus der Passphrase. Daher nichts zu
    // migrieren. Diese Methode bleibt als Hook für zukünftige Migrationen.
    return null;
  }

  /// Zuordnungstabelle speichern.
  Future<void> saveMappings(
    String reportId,
    List<PseudonymMapping> mappings,
  ) async {
    _ensureInitialized();
    final json = jsonEncode(mappings.map((m) => m.toJson()).toList());
    await _encryptedBox!.put(reportId, json);
  }

  /// Zuordnungstabelle laden.
  List<PseudonymMapping>? loadMappings(String reportId) {
    _ensureInitialized();
    final json = _encryptedBox!.get(reportId);
    if (json == null) return null;
    final list = jsonDecode(json) as List;
    return list
        .map((e) => PseudonymMapping.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Zuordnungstabelle löschen.
  Future<void> deleteMappings(String reportId) async {
    _ensureInitialized();
    await _encryptedBox!.delete(reportId);
  }

  List<String> get reportIds {
    _ensureInitialized();
    return _encryptedBox!.keys.cast<String>().toList();
  }

  Future<void> clearAll() async {
    _ensureInitialized();
    await _encryptedBox!.clear();
  }

  /// Alle Daten UND den Encryption-Key löschen (für Vollreset).
  Future<void> destroy() async {
    if (isInitialized) {
      await _encryptedBox!.clear();
      await _encryptedBox!.close();
      _encryptedBox = null;
    }
    await _secure.delete(key: _keychainKey);
  }

  Future<void> close() async {
    await _encryptedBox?.close();
    _encryptedBox = null;
  }

  String exportToJson(String reportId) {
    _ensureInitialized();
    final json = _encryptedBox!.get(reportId);
    if (json == null) throw StateError('Report $reportId not found');
    return json;
  }

  Future<void> importFromJson(String reportId, String jsonString) async {
    _ensureInitialized();
    final list = jsonDecode(jsonString) as List;
    for (final item in list) {
      PseudonymMapping.fromJson(item as Map<String, dynamic>);
    }
    await _encryptedBox!.put(reportId, jsonString);
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError(
        'SecureStorage nicht initialisiert. Rufe init() auf.',
      );
    }
  }
}
