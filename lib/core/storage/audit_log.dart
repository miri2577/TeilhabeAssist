import 'dart:convert';
import 'package:hive/hive.dart';

/// Verschlüsseltes Audit-Log für alle sicherheitsrelevanten Aktionen.
/// Enthält KEINE personenbezogenen Daten – nur Metadaten.
/// Dient als Nachweis für Datenschutz-Audits und Compliance.
class AuditLog {
  static const _boxName = 'audit_log';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Neuen Log-Eintrag schreiben
  Future<void> log(AuditEvent event) async {
    if (!isInitialized) return;
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'action': event.action,
      'details': event.details,
      'userName': event.userName,
    };
    await _box!.add(jsonEncode(entry));
  }

  /// Alle Log-Einträge (neueste zuerst)
  List<Map<String, dynamic>> getAll() {
    if (!isInitialized) return [];
    return _box!.values
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList()
        .reversed
        .toList();
  }

  /// Log als JSON exportieren (für Datenschutzbeauftragte)
  String exportToJson() {
    return jsonEncode({
      'appName': 'TeilhabeAssist',
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': getAll(),
    });
  }

  int get entryCount => _box?.length ?? 0;

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}

class AuditEvent {
  final String action;
  final Map<String, dynamic>? details;
  final String? userName;

  const AuditEvent({
    required this.action,
    this.details,
    this.userName,
  });

  // Vordefinierte Events
  static AuditEvent reportGenerated({
    required int mappingCount,
    required String model,
    required String reportType,
  }) => AuditEvent(
    action: 'report_generated',
    details: {
      'mappingCount': mappingCount,
      'model': model,
      'reportType': reportType,
    },
  );

  static AuditEvent signatureCreated({required String userName}) =>
      AuditEvent(action: 'signature_created', userName: userName);

  static AuditEvent passwordSet() =>
      const AuditEvent(action: 'password_set');

  static AuditEvent loginSuccess() =>
      const AuditEvent(action: 'login_success');

  static AuditEvent loginFailed() =>
      const AuditEvent(action: 'login_failed');

  static AuditEvent loginLocked({required int seconds}) =>
      AuditEvent(action: 'login_locked', details: {'lockSeconds': seconds});

  static AuditEvent apiKeyValidated({required String provider}) =>
      AuditEvent(action: 'api_key_validated', details: {'provider': provider});

  static AuditEvent dataReset() =>
      const AuditEvent(action: 'data_reset');

  static AuditEvent dictionaryExported({required int entryCount}) =>
      AuditEvent(action: 'dictionary_exported', details: {'entries': entryCount});

  static AuditEvent dictionaryImported({required int importedCount}) =>
      AuditEvent(action: 'dictionary_imported', details: {'imported': importedCount});

  static AuditEvent brpPage4Blocked() =>
      const AuditEvent(action: 'brp_page4_blocked');

  static AuditEvent pseudonymizationRun({
    required int replacements,
    required int warnings,
  }) => AuditEvent(
    action: 'pseudonymization_run',
    details: {'replacements': replacements, 'warnings': warnings},
  );
}
