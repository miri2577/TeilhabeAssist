import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_context.dart';
import '../../core/storage/audit_log.dart';
import '../api/providers/api_providers.dart';
import 'privacy_policy_text.dart';
import 'signature_store.dart';

final signatureStoreProvider = Provider<SignatureStore>((ref) {
  return SignatureStore();
});

class PrivacySignatureScreen extends ConsumerStatefulWidget {
  const PrivacySignatureScreen({super.key});

  @override
  ConsumerState<PrivacySignatureScreen> createState() =>
      _PrivacySignatureScreenState();
}

class _PrivacySignatureScreenState
    extends ConsumerState<PrivacySignatureScreen> {
  final _nameController = TextEditingController();
  bool _hasReadPolicy = false;
  bool _saving = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _hasReadPolicy && _nameController.text.trim().length >= 3;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);

    try {
      final store = ref.read(signatureStoreProvider);
      final fullName = _nameController.text.trim();
      await store.saveConfirmation(
        fullName: fullName,
        policyText: kPrivacyPolicyText,
      );

      // Audit-Kontext: User-Name in alle weiteren Logs übernehmen
      AuditContext.setCurrentUserName(fullName);

      // Audit-Event mit policyHash schreiben — beweist, welche Version
      // der Datenschutzerklärung unterzeichnet wurde.
      final policyHash = sha256
          .convert(utf8.encode(kPrivacyPolicyText))
          .toString();
      final auditLog = ref.read(auditLogProvider);
      await auditLog.log(AuditEvent.signatureCreated(
        userName: fullName,
        policyHash: policyHash,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datenschutzerklärung bestätigt'),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ref.watch(signatureStoreProvider);
    final existing = store.currentSignature;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Datenschutzerklärung'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              // Bestehende Bestätigung anzeigen
              if (existing != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bestätigt von ${existing.fullName} '
                          'am ${_formatDate(existing.signedAt)}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Policy Text (scrollbar)
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      kPrivacyPolicyText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

              // Bestätigungs-Bereich
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                        color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: _hasReadPolicy,
                      onChanged: (v) =>
                          setState(() => _hasReadPolicy = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Ich habe die Datenschutzerklärung vollständig '
                        'gelesen und verstanden.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      tileColor: _hasReadPolicy
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vollständiger Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          _canConfirm && !_saving ? _confirm : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Gelesen und bestätigt'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} um '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} Uhr';
  }
}
