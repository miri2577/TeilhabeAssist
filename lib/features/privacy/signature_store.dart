import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:hive/hive.dart';

/// Speichert die Bestätigung der Datenschutzerklärung.
/// User muss die Erklärung als gelesen markieren bevor Berichte generiert werden.
class SignatureRecord {
  final String fullName;
  final DateTime signedAt;
  final String policyTextHash;

  const SignatureRecord({
    required this.fullName,
    required this.signedAt,
    required this.policyTextHash,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'signedAt': signedAt.toIso8601String(),
        'policyTextHash': policyTextHash,
      };

  factory SignatureRecord.fromJson(Map<String, dynamic> json) {
    return SignatureRecord(
      fullName: json['fullName'] as String,
      signedAt: DateTime.parse(json['signedAt'] as String),
      policyTextHash: json['policyTextHash'] as String,
    );
  }
}

class SignatureStore {
  static const _boxName = 'privacy_signatures';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  SignatureRecord? get currentSignature {
    if (!isInitialized) return null;
    final json = _box?.get('current');
    if (json == null) return null;
    try {
      return SignatureRecord.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  bool get hasSigned => currentSignature != null;

  bool isSignatureValid(String policyText) {
    final sig = currentSignature;
    if (sig == null) return false;
    return sig.policyTextHash == _hashText(policyText);
  }

  /// Bestätigung speichern (Datenschutzerklärung als gelesen markiert)
  Future<void> saveConfirmation({
    required String fullName,
    required String policyText,
  }) async {
    if (!isInitialized) return;
    final record = SignatureRecord(
      fullName: fullName,
      signedAt: DateTime.now(),
      policyTextHash: _hashText(policyText),
    );
    await _box!.put('current', jsonEncode(record.toJson()));
  }

  Future<void> clearSignature() async {
    if (!isInitialized) return;
    await _box!.delete('current');
  }

  static String _hashText(String text) {
    final bytes = utf8.encode(text);
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
