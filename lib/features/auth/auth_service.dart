import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart';

/// Passwortschutz mit starker Verschlüsselung.
/// Jeder Mitarbeiter vergibt beim Erststart ein eigenes Passwort.
/// Das Passwort wird NICHT gespeichert – nur ein Hash zur Validierung.
class AuthService {
  static const _boxName = 'auth_data';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Prüft ob bereits ein Passwort vergeben wurde
  bool get hasPassword {
    if (!isInitialized) return false;
    return _box!.get('password_hash') != null;
  }

  /// Neues Passwort setzen (Erststart)
  Future<void> setPassword(String password) async {
    if (!isInitialized) return;
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    await _box!.put('password_salt', base64Encode(salt));
    await _box!.put('password_hash', hash);
  }

  // Rate-Limiting
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  /// Prüft ob Account gesperrt ist
  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      return false;
    }
    return true;
  }

  /// Verbleibende Sperrzeit in Sekunden
  int get lockoutSeconds {
    if (_lockoutUntil == null) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 300);
  }

  /// Passwort prüfen (mit Rate-Limiting)
  bool validatePassword(String password) {
    if (!isInitialized || !hasPassword) return false;
    if (isLockedOut) return false;

    final saltBase64 = _box!.get('password_salt')!;
    final salt = base64Decode(saltBase64);
    final storedHash = _box!.get('password_hash')!;
    final inputHash = _hashPassword(password, salt);
    final valid = storedHash == inputHash;

    if (valid) {
      _failedAttempts = 0;
      _lockoutUntil = null;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 10) {
        _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      } else if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
      }
    }

    return valid;
  }

  /// Passwort ändern (altes muss stimmen)
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!validatePassword(oldPassword)) return false;
    await setPassword(newPassword);
    return true;
  }

  /// Passwort-Stärke prüfen
  static PasswordStrength checkStrength(String password) {
    if (password.length < 8) return PasswordStrength.tooShort;
    int score = 0;
    if (password.length >= 10) score++;
    if (password.length >= 14) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// PBKDF2 + SHA-256 Hash
  String _hashPassword(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, 100000, 32));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return base64Encode(key);
  }

  /// Zufälliger Salt (32 Byte)
  Uint8List _generateSalt() {
    final random = FortunaRandom();
    random.seed(KeyParameter(
      Uint8List.fromList(
        List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256),
      ),
    ));
    return random.nextBytes(32);
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}

enum PasswordStrength {
  tooShort('Zu kurz (mind. 8 Zeichen)'),
  weak('Schwach'),
  medium('Mittel'),
  strong('Stark');

  const PasswordStrength(this.label);
  final String label;
}
