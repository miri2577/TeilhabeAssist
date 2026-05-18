import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/providers/api_providers.dart';

/// In-App-Viewer für das Audit-Log.
///
/// Zeigt alle protokollierten Aktionen mit Zeitstempel, Aktion und
/// Details. Filter nach Event-Typ und Datum. Kettenprüfung und Export
/// im AppBar.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _activeAction;
  _DateFilter _dateFilter = _DateFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auditLog = ref.watch(auditLogProvider);
    final all = auditLog.getAll();
    final actions = all
        .map((e) => (e['action'] ?? '').toString())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final cutoff = _dateFilter.cutoff;
    final filtered = all.where((e) {
      if (_activeAction != null && e['action'] != _activeAction) return false;
      if (cutoff != null) {
        final ts = DateTime.tryParse((e['timestamp'] ?? '').toString());
        if (ts == null || ts.isBefore(cutoff)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Audit-Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_outlined),
            tooltip: 'Chain prüfen',
            onPressed: _verifyChain,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportieren',
            onPressed: _export,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Status-Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${filtered.length} von ${all.length} Einträgen',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                _DateFilterDropdown(
                  value: _dateFilter,
                  onChanged: (v) => setState(() => _dateFilter = v),
                ),
              ],
            ),
          ),

          // Event-Filter-Chips
          if (actions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Alle'),
                      selected: _activeAction == null,
                      onSelected: (_) => setState(() => _activeAction = null),
                    ),
                    const SizedBox(width: 6),
                    for (final action in actions) ...[
                      FilterChip(
                        avatar: Icon(_iconForAction(action), size: 16),
                        label: Text(_labelForAction(action)),
                        selected: _activeAction == action,
                        onSelected: (_) => setState(
                          () => _activeAction =
                              _activeAction == action ? null : action,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),

          // Liste
          Expanded(
            child: filtered.isEmpty
                ? _emptyView(theme)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _EntryCard(entry: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Keine Einträge im aktuellen Filter',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyChain() async {
    final auditLog = ref.read(auditLogProvider);
    final result = auditLog.verifyChain();
    final ok = result == null;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          ok ? Icons.verified : Icons.gpp_bad,
          color: ok ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(ok ? 'Chain intakt' : 'Chain fehlerhaft'),
        content: Text(
          ok
              ? 'Die SHA-256-Hash-Kette aller ${auditLog.entryCount} Einträge '
                  'ist intakt. Es gibt keinen Hinweis auf nachträgliche '
                  'Manipulation.'
              : result,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final auditLog = ref.read(auditLogProvider);
    final json = auditLog.exportToJson();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Audit-Log exportieren',
      fileName: 'teilhabe_audit_'
          '${DateTime.now().toIso8601String().substring(0, 10)}.json',
    );
    if (path == null) return;
    await File(path).writeAsString(json);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Audit-Log exportiert (${auditLog.entryCount} Einträge)'),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = (entry['action'] ?? '').toString();
    final timestamp = (entry['timestamp'] ?? '').toString();
    final details = entry['details'] as Map?;
    final userName = (entry['userName'] ?? '').toString();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconForAction(action),
                    size: 18, color: _colorForAction(action, theme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForAction(action),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (userName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Nutzer: $userName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: details.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_labelForDetailKey(e.key.toString())}: '
                      '${_formatDetailValue(e.value)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateFilterDropdown extends StatelessWidget {
  const _DateFilterDropdown({required this.value, required this.onChanged});
  final _DateFilter value;
  final ValueChanged<_DateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<_DateFilter>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: _DateFilter.values
          .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
          .toList(),
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

enum _DateFilter {
  all('Alle Zeiten'),
  today('Heute'),
  week('Letzte 7 Tage'),
  month('Letzte 30 Tage');

  const _DateFilter(this.label);
  final String label;

  DateTime? get cutoff {
    final now = DateTime.now();
    return switch (this) {
      _DateFilter.all => null,
      _DateFilter.today =>
        DateTime(now.year, now.month, now.day),
      _DateFilter.week => now.subtract(const Duration(days: 7)),
      _DateFilter.month => now.subtract(const Duration(days: 30)),
    };
  }
}

String _labelForAction(String action) {
  return switch (action) {
    'report_generated' => 'Bericht generiert',
    'signature_created' => 'Datenschutz unterzeichnet',
    'password_set' => 'Passwort gesetzt',
    'login_success' => 'Anmeldung erfolgreich',
    'login_failed' => 'Anmeldung fehlgeschlagen',
    'login_locked' => 'Anmeldung gesperrt',
    'api_key_validated' => 'API-Key validiert',
    'data_reset' => 'Daten zurückgesetzt',
    'dictionary_exported' => 'Wörterbuch exportiert',
    'dictionary_imported' => 'Wörterbuch importiert',
    'pseudonymization_run' => 'Pseudonymisierung',
    _ => action,
  };
}

IconData _iconForAction(String action) {
  return switch (action) {
    'report_generated' => Icons.description_outlined,
    'signature_created' => Icons.draw_outlined,
    'password_set' => Icons.lock_outline,
    'login_success' => Icons.login,
    'login_failed' => Icons.error_outline,
    'login_locked' => Icons.block,
    'api_key_validated' => Icons.vpn_key_outlined,
    'data_reset' => Icons.delete_outline,
    'dictionary_exported' => Icons.upload_file,
    'dictionary_imported' => Icons.download,
    'pseudonymization_run' => Icons.shield_outlined,
    _ => Icons.event_note_outlined,
  };
}

Color _colorForAction(String action, ThemeData theme) {
  return switch (action) {
    'login_failed' || 'login_locked' || 'data_reset' => Colors.red,
    'login_success' || 'signature_created' || 'api_key_validated' =>
      Colors.green,
    'report_generated' || 'pseudonymization_run' => theme.colorScheme.primary,
    _ => theme.colorScheme.onSurfaceVariant,
  };
}

String _labelForDetailKey(String key) {
  return switch (key) {
    'model' => 'Modell',
    'reportType' => 'Typ',
    'inputTokens' => 'Input-Token',
    'outputTokens' => 'Output-Token',
    'costUsd' => 'Kosten (USD)',
    'mappingCount' => 'Pseudonyme',
    'replacements' => 'Ersetzungen',
    'warnings' => 'Warnungen',
    'entries' => 'Einträge',
    'imported' => 'Importiert',
    'provider' => 'Provider',
    'lockSeconds' => 'Sperrdauer (s)',
    _ => key,
  };
}

String _formatDetailValue(dynamic value) {
  if (value is double) return value.toStringAsFixed(4);
  return value.toString();
}

String _formatTimestamp(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
