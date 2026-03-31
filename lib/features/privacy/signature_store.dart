import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:hive/hive.dart';

/// Speichert die elektronische Unterschrift der Datenschutzerklärung.
/// Einfache elektronische Signatur (EES) nach eIDAS:
/// - Handschriftliche Signatur als PNG-Bytes
/// - Vollständiger Name
/// - Zeitstempel
/// - SHA-256-Hash des unterzeichneten Textes (Integritätsbeweis)
class SignatureRecord {
  final String fullName;
  final DateTime signedAt;
  final String policyTextHash;
  final String signatureBase64; // PNG-Bild als Base64

  const SignatureRecord({
    required this.fullName,
    required this.signedAt,
    required this.policyTextHash,
    required this.signatureBase64,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'signedAt': signedAt.toIso8601String(),
        'policyTextHash': policyTextHash,
        'signatureBase64': signatureBase64,
      };

  factory SignatureRecord.fromJson(Map<String, dynamic> json) {
    return SignatureRecord(
      fullName: json['fullName'] as String,
      signedAt: DateTime.parse(json['signedAt'] as String),
      policyTextHash: json['policyTextHash'] as String,
      signatureBase64: json['signatureBase64'] as String,
    );
  }

  Uint8List get signatureBytes => base64Decode(signatureBase64);
}

class SignatureStore {
  static const _boxName = 'privacy_signatures';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Gibt die aktuelle gültige Unterschrift zurück (falls vorhanden)
  SignatureRecord? get currentSignature {
    if (!isInitialized) return null;
    final json = _box?.get('current');
    if (json == null) return null;
    return SignatureRecord.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// Prüft ob eine gültige Unterschrift vorliegt
  bool get hasSigned => currentSignature != null;

  /// Prüft ob die Unterschrift zum aktuellen Policy-Text passt
  bool isSignatureValid(String policyText) {
    final sig = currentSignature;
    if (sig == null) return false;
    return sig.policyTextHash == _hashText(policyText);
  }

  /// Speichert eine neue Unterschrift
  Future<void> saveSignature({
    required String fullName,
    required Uint8List signaturePng,
    required String policyText,
  }) async {
    if (!isInitialized) return;
    final record = SignatureRecord(
      fullName: fullName,
      signedAt: DateTime.now(),
      policyTextHash: _hashText(policyText),
      signatureBase64: base64Encode(signaturePng),
    );
    await _box!.put('current', jsonEncode(record.toJson()));
  }

  /// Löscht die Unterschrift
  Future<void> clearSignature() async {
    if (!isInitialized) return;
    await _box!.delete('current');
  }

  /// SHA-256-Hash des Policy-Textes
  static String _hashText(String text) {
    final bytes = utf8.encode(text);
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
