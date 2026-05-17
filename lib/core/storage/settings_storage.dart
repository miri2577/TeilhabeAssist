import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'package:teilhabe_assist/core/crypto/secure_random.dart';

/// Persistente Speicherung von App-Einstellungen inkl. API-Keys.
///
/// Der AES-256-Schlüssel für die verschlüsselte Hive-Box wird im
/// OS-Keystore (DPAPI / Keychain / AndroidKeystore) abgelegt — nicht mehr
/// im Klartext in einer separaten Hive-Box. Damit ist Filesystem-Zugriff
/// allein nicht ausreichend, um die API-Keys zu entschlüsseln.
class SettingsStorage {
  static const _boxName = 'app_settings_encrypted';
  static const _legacyKeyBoxName = 'app_settings_key';
  static const _keychainKey = 'teilhabe_assist.settings_box_key';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Box<String>? _box;

  Future<void> init() async {
    final encryptionKey = await _getOrCreateEncryptionKey();
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  /// Liefert den Box-Encryption-Key aus dem OS-Keystore.
  ///
  /// Beim ersten Start wird ein neuer 256-Bit-Key generiert und im
  /// Keystore abgelegt. Bestehende Installationen mit einem Legacy-Key
  /// in der unverschlüsselten `app_settings_key`-Box werden transparent
  /// migriert: alter Key wird in den Keystore übernommen, die alte Box
  /// gelöscht.
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    final existing = await _secure.read(key: _keychainKey);
    if (existing != null) {
      return base64Decode(existing);
    }

    final legacy = await _migrateLegacyKey();
    if (legacy != null) {
      await _secure.write(key: _keychainKey, value: base64Encode(legacy));
      return legacy;
    }

    final fresh = secureRandomBytes(32);
    await _secure.write(key: _keychainKey, value: base64Encode(fresh));
    return fresh;
  }

  Future<Uint8List?> _migrateLegacyKey() async {
    if (!await Hive.boxExists(_legacyKeyBoxName)) return null;
    final keyBox = await Hive.openBox<String>(_legacyKeyBoxName);
    final raw = keyBox.get('enc_key');
    if (raw == null) {
      await keyBox.close();
      await Hive.deleteBoxFromDisk(_legacyKeyBoxName);
      return null;
    }
    final bytes = base64Decode(raw);
    await keyBox.close();
    await Hive.deleteBoxFromDisk(_legacyKeyBoxName);
    return bytes;
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  String? get anthropicApiKey => _box?.get('anthropic_api_key');
  set anthropicApiKey(String? value) => value != null
      ? _box?.put('anthropic_api_key', value)
      : _box?.delete('anthropic_api_key');

  String? get openaiApiKey => _box?.get('openai_api_key');
  set openaiApiKey(String? value) => value != null
      ? _box?.put('openai_api_key', value)
      : _box?.delete('openai_api_key');

  String? get selectedProvider => _box?.get('selected_provider');
  set selectedProvider(String? value) => value != null
      ? _box?.put('selected_provider', value)
      : _box?.delete('selected_provider');

  String? get selectedModel => _box?.get('selected_model');
  set selectedModel(String? value) => value != null
      ? _box?.put('selected_model', value)
      : _box?.delete('selected_model');

  String? get customInfoPrompt => _box?.get('custom_info_prompt');
  set customInfoPrompt(String? value) =>
      value != null && value.isNotEmpty
          ? _box?.put('custom_info_prompt', value)
          : _box?.delete('custom_info_prompt');

  String? get customBrpPrompt => _box?.get('custom_brp_prompt');
  set customBrpPrompt(String? value) =>
      value != null && value.isNotEmpty
          ? _box?.put('custom_brp_prompt', value)
          : _box?.delete('custom_brp_prompt');

  /// Eigenes Träger-Logo (PNG/JPG/SVG-Bytes) für den PDF-Header.
  /// Gespeichert als Base64-String in der verschlüsselten Hive-Box.
  Uint8List? get customLogo {
    final s = _box?.get('custom_logo_b64');
    if (s == null || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  set customLogo(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      _box?.delete('custom_logo_b64');
      _box?.delete('custom_logo_name');
    } else {
      _box?.put('custom_logo_b64', base64Encode(bytes));
    }
  }

  String? get customLogoName => _box?.get('custom_logo_name');
  set customLogoName(String? name) {
    if (name == null || name.isEmpty) {
      _box?.delete('custom_logo_name');
    } else {
      _box?.put('custom_logo_name', name);
    }
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
