import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../adapters/anthropic_adapter.dart';
import '../adapters/llm_adapter.dart';
import '../adapters/openai_adapter.dart';

enum LLMProvider {
  anthropic('Anthropic Claude'),
  openai('OpenAI GPT');

  const LLMProvider(this.label);
  final String label;
}

final selectedProviderProvider =
    StateProvider<LLMProvider>((ref) => LLMProvider.anthropic);

final llmAdapterProvider = Provider<LLMAdapter>((ref) {
  final provider = ref.watch(selectedProviderProvider);
  return switch (provider) {
    LLMProvider.anthropic => AnthropicAdapter(),
    LLMProvider.openai => OpenAIAdapter(),
  };
});

final apiKeyProvider = StateProvider<String>((ref) => '');

/// Separater OpenAI-Key (falls anderer Provider als Anthropic)
final openaiApiKeyProvider = StateProvider<String>((ref) => '');

final selectedModelProvider = StateProvider<String>((ref) {
  return ref.read(llmAdapterProvider).defaultModel;
});

/// Gibt den korrekten API-Key für den aktuellen Provider zurück
final activeApiKeyProvider = Provider<String>((ref) {
  final provider = ref.watch(selectedProviderProvider);
  return switch (provider) {
    LLMProvider.anthropic => ref.watch(apiKeyProvider),
    LLMProvider.openai => ref.watch(openaiApiKeyProvider),
  };
});
