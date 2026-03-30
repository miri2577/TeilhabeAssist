import 'package:hive/hive.dart';

/// Persistente Speicherung von App-Einstellungen (API-Keys, Modell, Provider).
class SettingsStorage {
  static const _boxName = 'app_settings';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
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

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
