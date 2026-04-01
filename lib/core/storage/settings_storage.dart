import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart';

/// Persistente Speicherung von App-Einstellungen.
/// API-Keys werden mit AES-256 verschlüsselt in Hive gespeichert.
class SettingsStorage {
  static const _boxName = 'app_settings_encrypted';
  static const _keyBoxName = 'app_settings_key';
  Box<String>? _box;

  Future<void> init() async {
    final encryptionKey = await _getOrCreateEncryptionKey();
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  /// Generiert oder lädt den Box-Verschlüsselungskey.
  /// Der Key wird in einer separaten unverschlüsselten Box gespeichert,
  /// die durch das App-Passwort (Lock-Screen) geschützt ist.
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    final keyBox = await Hive.openBox<String>(_keyBoxName);
    final existingKey = keyBox.get('enc_key');

    if (existingKey != null) {
      return base64Decode(existingKey);
    }

    // Neuen zufälligen 256-Bit Key generieren
    final random = FortunaRandom();
    final seed = Uint8List.fromList(
      List.generate(32, (i) =>
        (DateTime.now().microsecondsSinceEpoch + i * 37) % 256),
    );
    random.seed(KeyParameter(seed));
    final key = random.nextBytes(32);

    await keyBox.put('enc_key', base64Encode(key));
    await keyBox.close();
    return key;
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  String? get anthropicApiKey => _box?.get('anthropic_api_key');
  set anthropicApiKey(String? value) =>
      value != null ? _box?.put('anthropic_api_key', value) : _box?.delete('anthropic_api_key');

  String? get openaiApiKey => _box?.get('openai_api_key');
  set openaiApiKey(String? value) =>
      value != null ? _box?.put('openai_api_key', value) : _box?.delete('openai_api_key');

  String? get selectedProvider => _box?.get('selected_provider');
  set selectedProvider(String? value) =>
      value != null ? _box?.put('selected_provider', value) : _box?.delete('selected_provider');

  String? get selectedModel => _box?.get('selected_model');
  set selectedModel(String? value) =>
      value != null ? _box?.put('selected_model', value) : _box?.delete('selected_model');

  /// Benutzerdefinierter System-Prompt für Informationsberichte
  String? get customInfoPrompt => _box?.get('custom_info_prompt');
  set customInfoPrompt(String? value) =>
      value != null && value.isNotEmpty
          ? _box?.put('custom_info_prompt', value)
          : _box?.delete('custom_info_prompt');

  /// Benutzerdefinierter System-Prompt für BRP
  String? get customBrpPrompt => _box?.get('custom_brp_prompt');
  set customBrpPrompt(String? value) =>
      value != null && value.isNotEmpty
          ? _box?.put('custom_brp_prompt', value)
          : _box?.delete('custom_brp_prompt');

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
