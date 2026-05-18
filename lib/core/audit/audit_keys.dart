import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import 'audit_pem.dart';

/// Verwaltet das Ed25519-Schlüsselpaar für signierte Audit-Exports.
///
/// - Privater Schlüssel: in `flutter_secure_storage` (DPAPI / Keychain /
///   Keystore) — niemals in Hive oder als Klartext irgendwo sonst.
/// - Öffentlicher Schlüssel: in der Hive-Box `audit_keys` als Base64 —
///   wird für Anzeige (Fingerprint) und im Export-JSON gebraucht.
///
/// API ist `static`, der Zustand wird einmal pro App-Lauf gehalten;
/// `init()` wird bei Bedarf lazy aufgerufen.
class AuditKeys {
  AuditKeys._();

  static const _boxName = 'audit_keys';
  static const _privSecureKey = 'fegh_audit_priv_v1';
  static const _publicHiveKey = 'public_key_b64';
  static const _fingerprintHiveKey = 'fingerprint';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static final Ed25519 _ed25519 = Ed25519();

  static Box? _box;

  static Future<void> _ensureBox() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// True wenn ein Schlüsselpaar konfiguriert ist (Public + Private da).
  static Future<bool> hasKeyPair() async {
    await _ensureBox();
    final pub = _box!.get(_publicHiveKey);
    if (pub is! String || pub.isEmpty) return false;
    final priv = await _secure.read(key: _privSecureKey);
    return priv != null && priv.isNotEmpty;
  }

  /// Public-Key als Base64. `null` wenn nicht konfiguriert.
  static Future<String?> getPublicKeyB64() async {
    await _ensureBox();
    final v = _box!.get(_publicHiveKey);
    return v is String && v.isNotEmpty ? v : null;
  }

  /// Public-Key als PEM. `null` wenn nicht konfiguriert.
  static Future<String?> getPublicKeyPem() async {
    final b64 = await getPublicKeyB64();
    if (b64 == null) return null;
    return AuditPem.encodePublic(base64Decode(b64));
  }

  /// Privaten Key als PEM für Backup-Anzeige im Setup-Wizard.
  /// **NUR** direkt nach Generierung aufrufen — verlangt explizite
  /// Bestätigung des User, dass er den Schlüssel sichert.
  static Future<String?> getPrivateKeyPem() async {
    final raw = await _secure.read(key: _privSecureKey);
    if (raw == null || raw.isEmpty) return null;
    return AuditPem.encodePrivate(base64Decode(raw));
  }

  /// SHA-256-Fingerprint des Public Key, Hex, gekürzt (für UI).
  /// Format: `AA:BB:CC:DD:…` (16 Hex-Zeichen + Doppelpunkte).
  static Future<String?> getFingerprint() async {
    await _ensureBox();
    final cached = _box!.get(_fingerprintHiveKey);
    if (cached is String && cached.isNotEmpty) return cached;
    final pubB64 = await getPublicKeyB64();
    if (pubB64 == null) return null;
    final hash = sha256.convert(base64Decode(pubB64)).bytes;
    final hex = hash
        .sublist(0, 8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
    await _box!.put(_fingerprintHiveKey, hex);
    return hex;
  }

  /// Generiert ein frisches Ed25519-Schlüsselpaar und speichert es.
  /// Liefert ([privatePem], [publicPem]) — der Caller MUSS dem User
  /// den privaten PEM-Text einmal anzeigen, damit er ein Backup
  /// erstellt.
  static Future<({String privatePem, String publicPem, String fingerprint})>
      generate() async {
    final keyPair = await _ed25519.newKeyPair();
    final priv = await keyPair.extractPrivateKeyBytes();
    final pub = await keyPair.extractPublicKey();
    final pubBytes = Uint8List.fromList(pub.bytes);
    await _storePair(
      privateSeed: Uint8List.fromList(priv),
      publicKey: pubBytes,
    );
    return (
      privatePem: AuditPem.encodePrivate(Uint8List.fromList(priv)),
      publicPem: AuditPem.encodePublic(pubBytes),
      fingerprint: (await getFingerprint())!,
    );
  }

  /// Importiert ein vom DSB bereitgestelltes PEM-File (PKCS#8 Ed25519).
  /// Leitet den Public Key aus dem privaten ab und speichert beide.
  static Future<({String publicPem, String fingerprint})> importPrivatePem(
      String pem) async {
    final seed = AuditPem.decodePrivate(pem);
    if (seed.length != 32) {
      throw FormatException('Ed25519-Seed muss 32 Byte sein.');
    }
    final keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final pub = await keyPair.extractPublicKey();
    final pubBytes = Uint8List.fromList(pub.bytes);
    await _storePair(privateSeed: seed, publicKey: pubBytes);
    return (
      publicPem: AuditPem.encodePublic(pubBytes),
      fingerprint: (await getFingerprint())!,
    );
  }

  /// Schlüssel rotieren — alten löschen, neuen generieren.
  /// Caller sollte vor + nach Rotation ein `key_rotated`-Audit-Event
  /// schreiben.
  static Future<({String privatePem, String publicPem, String fingerprint})>
      rotate() async {
    await delete();
    return generate();
  }

  /// Beide Schlüssel löschen (nur für Tests / Wizard-Reset).
  static Future<void> delete() async {
    await _ensureBox();
    await _secure.delete(key: _privSecureKey);
    await _box!.delete(_publicHiveKey);
    await _box!.delete(_fingerprintHiveKey);
  }

  /// Signiert die übergebenen Bytes mit dem privaten Schlüssel.
  /// Wirft `StateError` wenn kein Schlüssel konfiguriert ist.
  static Future<Uint8List> sign(Uint8List payload) async {
    final raw = await _secure.read(key: _privSecureKey);
    if (raw == null || raw.isEmpty) {
      throw StateError('Kein Audit-Schlüssel konfiguriert.');
    }
    final seed = base64Decode(raw);
    final keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final sig = await _ed25519.sign(payload, keyPair: keyPair);
    return Uint8List.fromList(sig.bytes);
  }

  static Future<void> _storePair({
    required Uint8List privateSeed,
    required Uint8List publicKey,
  }) async {
    await _ensureBox();
    await _secure.write(
      key: _privSecureKey,
      value: base64Encode(privateSeed),
    );
    await _box!.put(_publicHiveKey, base64Encode(publicKey));
    // Fingerprint neu berechnen
    await _box!.delete(_fingerprintHiveKey);
    await getFingerprint();
  }
}
