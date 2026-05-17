import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/audit_log.dart';
import '../adapters/anthropic_adapter.dart';
import '../adapters/llm_adapter.dart';
import '../adapters/openai_adapter.dart';

final auditLogProvider = Provider<AuditLog>((ref) => AuditLog());

enum LLMProvider {
  anthropic('Anthropic Claude'),
  openai('OpenAI GPT');

  const LLMProvider(this.label);
  final String label;
}

final selectedProviderProvider =
    StateProvider<LLMProvider>((ref) => LLMProvider.anthropic);

/// Stabile Adapter-Instanzen pro Provider, damit Dio Connection-Pooling
/// und HTTP-Keep-Alive nutzen kann. `keepAlive: true` verhindert, dass der
/// Provider zerstört wird, sobald kein Listener aktiv ist.
final _anthropicAdapterProvider = Provider<AnthropicAdapter>((ref) {
  ref.keepAlive();
  return AnthropicAdapter();
});

final _openaiAdapterProvider = Provider<OpenAIAdapter>((ref) {
  ref.keepAlive();
  return OpenAIAdapter();
});

final llmAdapterProvider = Provider<LLMAdapter>((ref) {
  final provider = ref.watch(selectedProviderProvider);
  return switch (provider) {
    LLMProvider.anthropic => ref.watch(_anthropicAdapterProvider),
    LLMProvider.openai => ref.watch(_openaiAdapterProvider),
  };
});

final apiKeyProvider = StateProvider<String>((ref) => '');

/// Separater OpenAI-Key (falls anderer Provider als Anthropic)
final openaiApiKeyProvider = StateProvider<String>((ref) => '');

final selectedModelProvider = StateProvider<String>((ref) {
  return ref.read(llmAdapterProvider).defaultModel;
});

/// Benutzerdefiniertes Logo (PNG/JPG-Bytes) für den PDF-Header.
/// Wird beim App-Start aus `SettingsStorage.customLogo` initialisiert.
/// Beim Setzen über die Einstellungen sollte gleichzeitig auch
/// `SettingsStorage.customLogo` aktualisiert werden, damit das Logo
/// persistent bleibt.
final customLogoProvider = StateProvider<Uint8List?>((ref) => null);

final customLogoNameProvider = StateProvider<String?>((ref) => null);

/// Gibt den korrekten API-Key für den aktuellen Provider zurück
final activeApiKeyProvider = Provider<String>((ref) {
  final provider = ref.watch(selectedProviderProvider);
  return switch (provider) {
    LLMProvider.anthropic => ref.watch(apiKeyProvider),
    LLMProvider.openai => ref.watch(openaiApiKeyProvider),
  };
});
