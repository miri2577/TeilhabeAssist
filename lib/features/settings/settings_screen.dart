import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/data_reset_service.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/theme/app_settings_provider.dart';
import '../api/providers/api_providers.dart';
import '../pseudonymization/providers/pseudonym_providers.dart';

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
    _anthropicKeyController =
        TextEditingController(text: ref.read(apiKeyProvider));
    _openaiKeyController =
        TextEditingController(text: ref.read(openaiApiKeyProvider));
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

  Future<void> _exportDictionary() async {
    final dictionary = ref.read(userDictionaryProvider);
    final json = dictionary.exportToJson();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Wörterbuch exportieren',
      fileName: 'teilhabe_woerterbuch.json',
    );
    if (path == null) return;
    await File(path).writeAsString(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wörterbuch exportiert')),
      );
    }
  }

  Future<void> _importDictionary() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    try {
      final json = utf8.decode(bytes);
      final dictionary = ref.read(userDictionaryProvider);
      final count = await dictionary.importFromJson(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count Einträge importiert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedProvider = ref.watch(selectedProviderProvider);
    final adapter = ref.watch(llmAdapterProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/'),
        ),
        title: const Text('Einstellungen'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // === DARSTELLUNG ===
              _sectionTitle('Darstellung', theme),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Theme
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('Erscheinungsbild'),
                        trailing: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.settings_brightness, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode, size: 18),
                            ),
                          ],
                          selected: {appSettings.themeMode},
                          onSelectionChanged: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setThemeMode(v.first),
                        ),
                      ),
                      const Divider(),
                      // Textgröße
                      ListTile(
                        leading: const Icon(Icons.text_fields),
                        title: const Text('Textgröße'),
                        subtitle: Slider(
                          value: appSettings.textScaleFactor,
                          min: 0.8,
                          max: 1.4,
                          divisions: 6,
                          label:
                              '${(appSettings.textScaleFactor * 100).round()}%',
                          onChanged: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setTextScaleFactor(v),
                        ),
                        trailing: Text(
                          '${(appSettings.textScaleFactor * 100).round()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // === API ===
              _sectionTitle('API-Konfiguration', theme),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider-Dropdown
                      DropdownButtonFormField<LLMProvider>(
                        initialValue: selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'API-Provider',
                          prefixIcon: Icon(Icons.cloud_outlined),
                        ),
                        items: LLMProvider.values
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          ref.read(selectedProviderProvider.notifier).state = v;
                          _settingsStorage.selectedProvider = v.name;
                          final newModel =
                              ref.read(llmAdapterProvider).defaultModel;
                          ref.read(selectedModelProvider.notifier).state =
                              newModel;
                          _settingsStorage.selectedModel = newModel;
                          setState(() => _keyValid = null);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Modell-Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: adapter.availableModels.contains(selectedModel)
                            ? selectedModel
                            : adapter.defaultModel,
                        decoration: const InputDecoration(
                          labelText: 'Modell',
                          prefixIcon: Icon(Icons.memory),
                        ),
                        items: adapter.availableModels
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          ref.read(selectedModelProvider.notifier).state = v;
                          _settingsStorage.selectedModel = v;
                        },
                      ),
                      const SizedBox(height: 16),

                      // API-Key
                      TextField(
                        controller:
                            selectedProvider == LLMProvider.anthropic
                                ? _anthropicKeyController
                                : _openaiKeyController,
                        obscureText: _obscureKey,
                        decoration: InputDecoration(
                          labelText: 'API-Key',
                          hintText:
                              selectedProvider == LLMProvider.anthropic
                                  ? 'sk-ant-...'
                                  : 'sk-...',
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(_obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscureKey = !_obscureKey),
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
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.vpn_key),
                        label: Text(
                            _validating ? 'Prüfe...' : 'API-Key prüfen'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // === WÖRTERBUCH ===
              _sectionTitle('Wörterbuch', theme),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Wörterbuch bearbeiten'),
                      subtitle: const Text(
                          'Ausgeschlossene Wörter und gelernte Namen'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => context.go('/dictionary'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Wörterbuch exportieren'),
                      subtitle: const Text('Als JSON-Datei speichern'),
                      onTap: _exportDictionary,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('Wörterbuch importieren'),
                      subtitle: const Text(
                          'JSON-Datei laden (wird zusammengeführt)'),
                      onTap: _importDictionary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // === DATENSCHUTZ ===
              _sectionTitle('Datenschutz & Recht', theme),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: const Text('Datenschutzerklärung & Unterschrift'),
                      subtitle: const Text(
                          'Datenschutzerklärung lesen und rechtssicher unterzeichnen'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => context.go('/privacy'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Audit-Log exportieren'),
                      subtitle: const Text(
                          'Protokoll aller sicherheitsrelevanten Aktionen'),
                      onTap: _exportAuditLog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // === INFO ===
              _sectionTitle('Info & Daten', theme),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Über TeilhabeAssist'),
                      onTap: () => _showAbout(context, theme),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_forever,
                          color: Colors.red.shade700),
                      title: Text('Alle App-Daten löschen',
                          style: TextStyle(color: Colors.red.shade700)),
                      subtitle: const Text(
                          'API-Keys, Wörterbücher, Unterschriften, Vorlagen – alles'),
                      onTap: () => _confirmDeleteAll(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Datenschutz-Hinweis
              Card(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Alle Daten (API-Keys, Wörterbücher, Berichte) '
                          'werden ausschließlich lokal auf diesem Gerät gespeichert. '
                          'Nur pseudonymisierte Texte verlassen das Gerät.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAuditLog() async {
    final auditLog = ref.read(auditLogProvider);
    final json = auditLog.exportToJson();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Audit-Log exportieren',
      fileName: 'teilhabe_audit_${DateTime.now().toIso8601String().substring(0, 10)}.json',
    );
    if (path == null) return;
    await File(path).writeAsString(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit-Log exportiert (${auditLog.entryCount} Einträge)')),
      );
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning, color: Colors.red.shade700, size: 48),
        title: const Text('Alle Daten löschen?'),
        content: const Text(
          'Dies löscht unwiderruflich:\n\n'
          '• Alle API-Keys\n'
          '• Alle Wörterbücher (ausgeschlossene Wörter, gelernte Namen)\n'
          '• Alle gespeicherten Vorlagen\n'
          '• Die Datenschutz-Unterschrift\n'
          '• Alle Einstellungen\n\n'
          'Die App wird danach neu gestartet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DataResetService.resetAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alle Daten gelöscht. Bitte App neu starten.')),
              );
            },
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleMedium),
    );
  }

  void _showAbout(BuildContext context, ThemeData theme) {
    showAboutDialog(
      context: context,
      applicationName: 'TeilhabeAssist',
      applicationVersion: '0.2.0-beta',
      applicationIcon: Icon(
        Icons.description_outlined,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      applicationLegalese: '© 2026 Mirko Richter\n\n'
          'KI-gestützte Berichterstellung für die Eingliederungshilfe Berlin.\n\n'
          'Personenbezogene Daten verlassen niemals das Gerät. '
          'Es werden ausschließlich pseudonymisierte Texte an die API übermittelt.\n\n'
          'Basiert auf dem Teilhabeinstrument Berlin (TIB), '
          'ICF-Klassifikation und dem Berliner Rahmenvertrag '
          'Eingliederungshilfe (BRV EGH).',
    );
  }
}
