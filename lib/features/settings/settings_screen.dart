import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/settings_storage.dart';
import '../api/providers/api_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _anthropicKeyController;
  late final TextEditingController _openaiKeyController;
  final _settingsStorage = SettingsStorage();
  bool _obscureKey = true;
  bool _validating = false;
  bool? _keyValid;

  @override
  void initState() {
    super.initState();
    _anthropicKeyController = TextEditingController(
      text: ref.read(apiKeyProvider),
    );
    _openaiKeyController = TextEditingController(
      text: ref.read(openaiApiKeyProvider),
    );
    _initStorage();
  }

  Future<void> _initStorage() async {
    await _settingsStorage.init();
  }

  @override
  void dispose() {
    _anthropicKeyController.dispose();
    _openaiKeyController.dispose();
    super.dispose();
  }

  Future<void> _validateKey() async {
    final provider = ref.read(selectedProviderProvider);
    final key = provider == LLMProvider.anthropic
        ? _anthropicKeyController.text.trim()
        : _openaiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _validating = true;
      _keyValid = null;
    });

    try {
      final adapter = ref.read(llmAdapterProvider);
      final valid = await adapter.validateApiKey(key);
      if (mounted) {
        setState(() {
          _keyValid = valid;
          _validating = false;
        });
        if (valid) {
          if (provider == LLMProvider.anthropic) {
            ref.read(apiKeyProvider.notifier).state = key;
            _settingsStorage.anthropicApiKey = key;
          } else {
            ref.read(openaiApiKeyProvider.notifier).state = key;
            _settingsStorage.openaiApiKey = key;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _keyValid = false;
          _validating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedProvider = ref.watch(selectedProviderProvider);
    final adapter = ref.watch(llmAdapterProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Provider-Auswahl
              Text('API-Provider', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      for (final provider in LLMProvider.values) ...[
                        Expanded(
                          child: ChoiceChip(
                            label: Text(provider.label),
                            selected: selectedProvider == provider,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(selectedProviderProvider.notifier)
                                    .state = provider;
                                _settingsStorage.selectedProvider = provider.name;
                                // Modell auf Default des neuen Providers setzen
                                final newModel = ref.read(llmAdapterProvider).defaultModel;
                                ref
                                    .read(selectedModelProvider.notifier)
                                    .state = newModel;
                                _settingsStorage.selectedModel = newModel;
                                setState(() => _keyValid = null);
                              }
                            },
                          ),
                        ),
                        if (provider != LLMProvider.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // API-Key
              Text('API-Key (${adapter.name})',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: selectedProvider == LLMProvider.anthropic
                            ? _anthropicKeyController
                            : _openaiKeyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'API-Key',
                          hintText: selectedProvider == LLMProvider.anthropic
                              ? 'sk-ant-...'
                              : 'sk-...',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(_obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscureKey = !_obscureKey),
                              ),
                              if (_keyValid == true)
                                const Icon(Icons.check_circle,
                                    color: Colors.green)
                              else if (_keyValid == false)
                                const Icon(Icons.error, color: Colors.red),
                            ],
                          ),
                        ),
                        onChanged: (_) => setState(() => _keyValid = null),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _validating ? null : _validateKey,
                        icon: _validating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.vpn_key),
                        label: Text(
                            _validating ? 'Prüfe...' : 'API-Key prüfen'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Modellauswahl
              Text('Modell', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final model in adapter.availableModels) ...[
                        ListTile(
                          leading: selectedModel == model
                              ? Icon(Icons.radio_button_checked,
                                  color: theme.colorScheme.primary)
                              : const Icon(Icons.radio_button_unchecked),
                          title: Text(model),
                          subtitle: Text(_modelDescription(model)),
                          onTap: () => ref
                              .read(selectedModelProvider.notifier)
                              .state = model,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info
              Card(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'API-Keys werden nur lokal gespeichert. '
                          'Nur pseudonymisierte Texte werden an die API gesendet.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modelDescription(String model) {
    if (model.contains('sonnet')) {
      return 'Empfohlen – bestes Preis-Leistungs-Verhältnis (~0,08 €/Bericht)';
    }
    if (model.contains('haiku')) {
      return 'Budget-Option (~0,03 €/Bericht)';
    }
    if (model.contains('opus')) {
      return 'Premium – für komplexe BRP-Erstberichte (~0,13 €/Bericht)';
    }
    if (model == 'gpt-4o') {
      return 'OpenAI Flagship (~0,06 €/Bericht)';
    }
    if (model == 'gpt-4o-mini') {
      return 'OpenAI Budget-Option (~0,02 €/Bericht)';
    }
    return model;
  }
}
