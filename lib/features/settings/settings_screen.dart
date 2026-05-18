import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/audit/audit_keys.dart';
import '../../core/storage/audit_log.dart';
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
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Validierung: '
                '${msg.length > 200 ? '${msg.substring(0, 200)}...' : msg}'),
            duration: const Duration(seconds: 5),
          ),
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

              // === BRANDING ===
              _sectionTitle('Branding / Träger-Logo', theme),
              _buildLogoCard(theme),
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
                      onTap: () => context.push('/dictionary'),
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

              // === KI-PROMPTS ===
              _sectionTitle('KI-Prompts', theme),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('System-Prompt bearbeiten'),
                  subtitle: const Text(
                      'Anweisungen an die KI für den Informationsbericht anpassen'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/prompts'),
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
                      onTap: () => context.push('/privacy'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Audit-Log ansehen'),
                      subtitle: const Text(
                          'Alle protokollierten Aktionen mit Filter & '
                          'Kettenprüfung'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => context.push('/audit-log'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Audit-Log exportieren'),
                      subtitle: const Text(
                          'JSON-Export für DSB / Aufsichtsbehörde '
                          '(Ed25519-signiert falls Schlüssel eingerichtet)'),
                      onTap: _exportAuditLog,
                    ),
                    const Divider(height: 1),
                    _AuditKeysTile(),
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
    final hasKey = await AuditKeys.hasKeyPair();
    final String json;
    final bool signed;
    try {
      if (hasKey) {
        json = await auditLog.exportSigned();
        signed = true;
      } else {
        json = auditLog.exportToJson();
        signed = false;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')),
      );
      return;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Audit-Log exportieren',
      fileName: 'teilhabe_audit_'
          '${DateTime.now().toIso8601String().substring(0, 10)}.json',
    );
    if (path == null) return;
    await File(path).writeAsString(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            signed
                ? 'Signierter Audit-Log exportiert (${auditLog.entryCount} '
                    'Einträge, Ed25519)'
                : 'Audit-Log exportiert (${auditLog.entryCount} Einträge, '
                    'unsigniert — Audit-Schlüssel nicht eingerichtet)',
          ),
        ),
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
          'Erhalten bleibt:\n'
          '• Das Audit-Log (forensischer Nachweis, gesetzlich erforderlich) '
          '— wird mit einem Eintrag „Daten zurückgesetzt" fortgeschrieben.\n\n'
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
              // Audit-Event ZUERST schreiben — danach könnte der Schreib-
              // Zugriff fehlschlagen, falls Hive-State unklar ist.
              final auditLog = ref.read(auditLogProvider);
              await auditLog.log(const AuditEvent(
                action: 'data_reset',
                details: {
                  'protectedBoxes': ['audit_log'],
                },
              ));
              final deletedCount = await DataResetService.resetAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$deletedCount Datenspeicher gelöscht. Audit-Log '
                    'erhalten. Bitte App neu starten.',
                  ),
                ),
              );
            },
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoCard(ThemeData theme) {
    final logoBytes = ref.watch(customLogoProvider);
    final logoName = ref.watch(customLogoNameProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wird oben im PDF-Header angezeigt. Empfohlen: PNG/JPG, '
              'transparent, mindestens 200×200 Pixel.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: logoBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.memory(
                            logoBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        )
                      : Icon(
                          Icons.image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        logoName ??
                            (logoBytes != null ? 'Eigenes Logo' : 'Kein Logo'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (logoBytes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${(logoBytes.length / 1024).toStringAsFixed(1)} KB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.upload, size: 18),
                            label: Text(
                                logoBytes == null ? 'Logo wählen' : 'Ersetzen'),
                          ),
                          if (logoBytes != null)
                            OutlinedButton.icon(
                              onPressed: _removeLogo,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Entfernen'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei konnte nicht gelesen werden.')),
        );
      }
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Logo > 2 MB. Bitte kleineres Bild wählen (PNG, transparent, '
              '≤ 500 px).',
            ),
          ),
        );
      }
      return;
    }
    _settingsStorage.customLogo = bytes;
    _settingsStorage.customLogoName = file.name;
    ref.read(customLogoProvider.notifier).state = bytes;
    ref.read(customLogoNameProvider.notifier).state = file.name;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo "${file.name}" gespeichert')),
      );
    }
  }

  void _removeLogo() {
    _settingsStorage.customLogo = null;
    _settingsStorage.customLogoName = null;
    ref.read(customLogoProvider.notifier).state = null;
    ref.read(customLogoNameProvider.notifier).state = null;
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


class _AuditKeysTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AuditKeysTile> createState() => _AuditKeysTileState();
}

class _AuditKeysTileState extends ConsumerState<_AuditKeysTile> {
  bool _loading = true;
  bool _hasKey = false;
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await AuditKeys.hasKeyPair();
    final fp = await AuditKeys.getFingerprint();
    if (!mounted) return;
    setState(() {
      _hasKey = has;
      _fingerprint = fp;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        leading: Icon(Icons.verified_user_outlined),
        title: Text('Audit-Schlüssel'),
        subtitle: Text('Status wird geprüft…'),
      );
    }
    if (!_hasKey) {
      return ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Audit-Schlüssel einrichten'),
        subtitle: const Text(
            'Ed25519-Signatur für externe Verifikation des Audit-Logs '
            '(empfohlen vom DSB)'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await context.push('/audit-setup');
          if (!mounted) return;
          _refresh();
        },
      );
    }
    return ListTile(
      leading: Icon(Icons.verified_user, color: Colors.green.shade700),
      title: const Text('Audit-Schlüssel aktiv'),
      subtitle: Text('Fingerprint: ${_fingerprint ?? "—"}'),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) async {
          switch (action) {
            case 'export_pub':
              await _exportPublicPem();
            case 'rotate':
              await _confirmRotate();
            case 'remove':
              await _confirmRemove();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'export_pub',
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Public Key exportieren'),
            ),
          ),
          PopupMenuItem(
            value: 'rotate',
            child: ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Schlüssel rotieren'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Schlüssel entfernen',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPublicPem() async {
    final pem = await AuditKeys.getPublicKeyPem();
    if (pem == null) return;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Public Key speichern',
      fileName: 'traeger_public.pem',
      type: FileType.custom,
      allowedExtensions: ['pem'],
    );
    if (path == null) return;
    await File(path).writeAsString(pem);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public Key gespeichert.')),
    );
  }

  Future<void> _confirmRotate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.refresh, color: Colors.orange.shade700, size: 48),
        title: const Text('Schlüssel rotieren?'),
        content: const Text(
          'Der bestehende private Schlüssel wird durch einen neuen ersetzt. '
          'Alte Exports bleiben mit dem alten Public Key prüfbar — neue '
          'Exports werden mit dem neuen Schlüssel signiert.\n\n'
          'Empfohlen nur bei Verdacht auf Kompromittierung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rotieren'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final oldFp = await AuditKeys.getFingerprint() ?? '';
    final result = await AuditKeys.rotate();
    final auditLog = ref.read(auditLogProvider);
    await auditLog.log(AuditEvent.keyRotated(
      oldFingerprint: oldFp,
      newFingerprint: result.fingerprint,
    ));
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Neuer Fingerprint: ${result.fingerprint}')),
    );
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 48),
        title: const Text('Schlüssel entfernen?'),
        content: const Text(
          'Künftige Exports werden nicht mehr signiert. Alte signierte '
          'Exports bleiben prüfbar — vorausgesetzt der Public Key wurde '
          'separat gesichert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuditKeys.delete();
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audit-Schlüssel entfernt.')),
    );
  }
}
