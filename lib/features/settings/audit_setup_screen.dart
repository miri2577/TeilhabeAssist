import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_keys.dart';
import '../../core/storage/audit_log.dart';
import '../api/providers/api_providers.dart';

/// Setup-Wizard für den Träger-Signaturschlüssel.
///
/// Zwei Wege:
///   1. Neuen Schlüssel generieren (App erzeugt Ed25519-Paar; User
///      bestätigt Backup)
///   2. Bestehenden Schlüssel importieren (DSB hat per OpenSSL ein
///      PEM-File erzeugt)
///
/// Nach Setup wird ein `key_generated` bzw. `key_imported` Audit-
/// Event geschrieben.
class AuditSetupScreen extends ConsumerStatefulWidget {
  const AuditSetupScreen({super.key});

  @override
  ConsumerState<AuditSetupScreen> createState() => _AuditSetupScreenState();
}

class _AuditSetupScreenState extends ConsumerState<AuditSetupScreen> {
  _Mode _mode = _Mode.choice;
  String? _generatedPrivatePem;
  String? _generatedPublicPem;
  String? _generatedFingerprint;
  bool _backupConfirmed = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Audit-Schlüssel einrichten'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(theme),
              const SizedBox(height: 20),
              if (_mode == _Mode.choice) _choiceView(theme),
              if (_mode == _Mode.generated) _generatedView(theme),
              if (_mode == _Mode.imported) _importedView(theme),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Forensische Audit-Signatur',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mit einem Träger-Signaturschlüssel werden Audit-Log-Exporte '
            'kryptografisch signiert. Aufsichtsbehörden oder Datenschutz-'
            'Auditoren können dadurch ohne Vertrauen in die App nachweisen, '
            'dass die Daten unverändert von Ihrem Träger stammen.\n\n'
            'Der private Schlüssel verlässt das Gerät nicht — er wird im '
            'OS-Keystore (DPAPI / Keychain) abgelegt. Sie sollten beim '
            'Setup ein Backup an einem sicheren Ort hinterlegen.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _choiceView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.add_circle_outline,
                color: theme.colorScheme.primary),
            title: const Text('Neuen Schlüssel generieren'),
            subtitle: const Text(
              'Die App erzeugt ein Ed25519-Paar. Sie erhalten den privaten '
              'Schlüssel einmalig zum Sichern (PEM-Text + Download).',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _busy ? null : _generate,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.upload_file, color: theme.colorScheme.primary),
            title: const Text('Bestehenden Schlüssel importieren'),
            subtitle: const Text(
              'PEM-File auswählen, das Ihr DSB per OpenSSL erzeugt hat. '
              'Empfohlen, wenn Sie mehrere FEGH-Apps mit demselben Schlüssel '
              'betreiben.',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _busy ? null : _importFromFile,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hinweis: Auch ohne Schlüssel funktioniert der Audit-Log '
          '(SHA-256-Hash-Chain). Die externe Verifikation wird dann aber '
          'nur in Grenzen möglich sein.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _generatedView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wichtig: Der private Schlüssel wird Ihnen NUR EINMAL '
                  'angezeigt. Sichern Sie ihn jetzt — ohne Backup ist eine '
                  'spätere Wiederherstellung unmöglich.',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _labelRow('Fingerprint', _generatedFingerprint ?? ''),
        const SizedBox(height: 12),
        _pemBlock(
          label: 'PRIVATER SCHLÜSSEL (geheim)',
          color: Colors.red.shade700,
          pem: _generatedPrivatePem!,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(_generatedPrivatePem!),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Privat-PEM kopieren'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _savePem(
                content: _generatedPrivatePem!,
                fileName: 'traeger_private.pem',
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Privat-PEM speichern'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _pemBlock(
          label: 'ÖFFENTLICHER SCHLÜSSEL (darf geteilt werden)',
          color: theme.colorScheme.primary,
          pem: _generatedPublicPem!,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(_generatedPublicPem!),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Public-PEM kopieren'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _savePem(
                content: _generatedPublicPem!,
                fileName: 'traeger_public.pem',
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Public-PEM speichern'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _backupConfirmed,
          onChanged: (v) => setState(() => _backupConfirmed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'Ich habe den privaten Schlüssel an einem sicheren Ort gesichert '
            '(Passwort-Manager, Tresor oder ausgedruckte Backup-Karte).',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _backupConfirmed && !_busy ? _completeSetup : null,
          icon: const Icon(Icons.check),
          label: const Text('Setup abschließen'),
        ),
      ],
    );
  }

  Widget _importedView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Schlüssel importiert und im OS-Keystore abgelegt.',
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _labelRow('Fingerprint', _generatedFingerprint ?? ''),
        const SizedBox(height: 12),
        _pemBlock(
          label: 'ÖFFENTLICHER SCHLÜSSEL',
          color: theme.colorScheme.primary,
          pem: _generatedPublicPem!,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.check),
          label: const Text('Fertig'),
        ),
      ],
    );
  }

  Widget _labelRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pemBlock({
    required String label,
    required Color color,
    required String pem,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            pem,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AuditKeys.generate();
      setState(() {
        _generatedPrivatePem = result.privatePem;
        _generatedPublicPem = result.publicPem;
        _generatedFingerprint = result.fingerprint;
        _mode = _Mode.generated;
      });
    } catch (e) {
      setState(() => _error = 'Generierung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Privaten Schlüssel (PEM-Datei) auswählen',
        type: FileType.custom,
        allowedExtensions: ['pem', 'key', 'txt'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final path = result.files.first.path;
      if (path == null) {
        setState(() => _error = 'Datei konnte nicht gelesen werden.');
        return;
      }
      final pem = await File(path).readAsString();
      final imported = await AuditKeys.importPrivatePem(pem);
      // Audit-Event direkt schreiben — keine Backup-Bestätigung nötig
      // (der DSB hat den Schlüssel ja schon im Original).
      final auditLog = ref.read(auditLogProvider);
      await auditLog.log(
          AuditEvent.keyImported(fingerprint: imported.fingerprint));
      setState(() {
        _generatedPublicPem = imported.publicPem;
        _generatedFingerprint = imported.fingerprint;
        _mode = _Mode.imported;
      });
    } catch (e) {
      setState(() => _error = 'Import fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeSetup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auditLog = ref.read(auditLogProvider);
      await auditLog.log(AuditEvent.keyGenerated(
          fingerprint: _generatedFingerprint!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audit-Schlüssel ist aktiv.')),
      );
      context.pop();
    } catch (e) {
      setState(() => _error = 'Setup konnte nicht abgeschlossen werden: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('In die Zwischenablage kopiert.')),
    );
  }

  Future<void> _savePem({
    required String content,
    required String fileName,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'PEM-Datei speichern',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pem'],
    );
    if (path == null) return;
    await File(path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gespeichert: ${path.split(Platform.pathSeparator).last}')),
    );
  }
}

enum _Mode { choice, generated, imported }
