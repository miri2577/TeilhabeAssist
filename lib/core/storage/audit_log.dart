import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../audit/audit_context.dart';
import '../audit/audit_keys.dart';

/// Audit-Log für sicherheitsrelevante Aktionen.
///
/// Jeder Eintrag enthält einen `prev_hash` und einen `hash` über
/// `SHA-256(prev_hash || canonical_json(payload))`. Damit ist nachträgliche
/// Manipulation einzelner Einträge erkennbar — das Re-Berechnen der Kette
/// schlägt fehl, sobald ein Eintrag editiert oder gelöscht wurde.
///
/// Enthält KEINE personenbezogenen Daten — nur Metadaten und Zeitstempel.
class AuditLog {
  static const _boxName = 'audit_log';
  static const _genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Neuen Log-Eintrag schreiben — bildet die Hash-Chain fort.
  ///
  /// Kontextfelder (`deviceId`, `appVersion`, `hostname`, `userName`)
  /// werden automatisch aus `AuditContext` ergänzt — sie sind für die
  /// forensische Auswertung essentiell und gehören in JEDEN Eintrag.
  Future<void> log(AuditEvent event) async {
    if (!isInitialized) return;
    final prevHash = _lastHash();
    final payload = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'action': event.action,
      'details': event.details,
      'userName': event.userName ??
          (AuditContext.currentUserName.isEmpty
              ? null
              : AuditContext.currentUserName),
      'deviceId': AuditContext.deviceId,
      'appVersion': AuditContext.appVersion,
      'hostname': AuditContext.hostname,
      'prev_hash': prevHash,
    };
    final hash = _hashPayload(payload);
    payload['hash'] = hash;
    await _box!.add(jsonEncode(payload));
  }

  /// Alle Log-Einträge (neueste zuerst).
  List<Map<String, dynamic>> getAll() {
    if (!isInitialized) return [];
    return _box!.values
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList()
        .reversed
        .toList();
  }

  /// Prüft die komplette Hash-Chain. `null` = OK, sonst Fehler-Beschreibung.
  String? verifyChain() {
    if (!isInitialized) return null;
    String prev = _genesisHash;
    var index = 0;
    for (final raw in _box!.values) {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final storedHash = entry.remove('hash') as String?;
      if (storedHash == null) {
        return 'Eintrag $index ohne Hash (Legacy-Format)';
      }
      if (entry['prev_hash'] != prev) {
        return 'Eintrag $index: prev_hash bricht die Kette';
      }
      final expected = _hashPayload(entry);
      if (expected != storedHash) {
        return 'Eintrag $index: Hash stimmt nicht — Manipulation möglich';
      }
      prev = storedHash;
      index++;
    }
    return null;
  }

  /// Log als JSON exportieren (für Datenschutzbeauftragte).
  String exportToJson() {
    return jsonEncode({
      'appName': 'FEGH-Bericht',
      'appVersion': AuditContext.appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'chainValid': verifyChain() == null,
      'entries': getAll(),
    });
  }

  /// Signierter JSON-Export — Detached-Ed25519-Signatur über das
  /// kanonisch serialisierte Payload-JSON.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "appName": "...", "appVersion": "...", "exportedAt": "...",
  ///   "chainValid": true, "entries": [...],
  ///   "algorithm": "Ed25519", "publicKey": "<b64>",
  ///   "publicKeyFingerprint": "AA:BB:...",
  ///   "signature": "<b64>"
  /// }
  /// ```
  ///
  /// Wirft `StateError` wenn kein Audit-Schlüssel konfiguriert ist —
  /// dann muss der Caller auf `exportToJson()` (unsigniert) ausweichen.
  Future<String> exportSigned() async {
    final pubB64 = await AuditKeys.getPublicKeyB64();
    final fingerprint = await AuditKeys.getFingerprint();
    if (pubB64 == null || fingerprint == null) {
      throw StateError('Kein Audit-Schlüssel konfiguriert.');
    }
    final payload = <String, dynamic>{
      'appName': 'FEGH-Bericht',
      'appVersion': AuditContext.appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'chainValid': verifyChain() == null,
      'algorithm': 'Ed25519',
      'publicKey': pubB64,
      'publicKeyFingerprint': fingerprint,
      'entries': getAll(),
    };
    final canonical = _canonicalJson(payload);
    final signature = await AuditKeys.sign(
      Uint8List.fromList(utf8.encode(canonical)),
    );
    payload['signature'] = base64Encode(signature);
    return jsonEncode(payload);
  }

  int get entryCount => _box?.length ?? 0;

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  String _lastHash() {
    if (_box!.isEmpty) return _genesisHash;
    final lastRaw = _box!.getAt(_box!.length - 1);
    if (lastRaw == null) return _genesisHash;
    final last = jsonDecode(lastRaw) as Map<String, dynamic>;
    return (last['hash'] as String?) ?? _genesisHash;
  }

  static String _hashPayload(Map<String, dynamic> payload) {
    // Kanonische JSON-Serialisierung: Keys sortiert, damit Hash deterministisch.
    final canonical = _canonicalJson(payload);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final parts = keys.map(
        (k) => '${jsonEncode(k)}:${_canonicalJson(value[k])}',
      );
      return '{${parts.join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
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
    int? inputTokens,
    int? outputTokens,
    double? costUsd,
  }) => AuditEvent(
    action: 'report_generated',
    details: {
      'mappingCount': mappingCount,
      'model': model,
      'reportType': reportType,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (costUsd != null) 'costUsd': costUsd,
    },
  );

  static AuditEvent signatureCreated({
    required String userName,
    String? policyHash,
  }) =>
      AuditEvent(
        action: 'signature_created',
        userName: userName,
        details: policyHash == null ? null : {'policyHash': policyHash},
      );

  static AuditEvent keyRotated({
    required String oldFingerprint,
    required String newFingerprint,
  }) =>
      AuditEvent(
        action: 'key_rotated',
        details: {
          'oldFingerprint': oldFingerprint,
          'newFingerprint': newFingerprint,
        },
      );

  static AuditEvent keyImported({required String fingerprint}) =>
      AuditEvent(
        action: 'key_imported',
        details: {'fingerprint': fingerprint},
      );

  static AuditEvent keyGenerated({required String fingerprint}) =>
      AuditEvent(
        action: 'key_generated',
        details: {'fingerprint': fingerprint},
      );

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

  static AuditEvent pseudonymizationRun({
    required int replacements,
    required int warnings,
  }) => AuditEvent(
    action: 'pseudonymization_run',
    details: {'replacements': replacements, 'warnings': warnings},
  );
}
