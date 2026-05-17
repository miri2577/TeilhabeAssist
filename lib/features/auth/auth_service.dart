import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart';

import '../../core/crypto/secure_random.dart';

/// Passwortschutz für Sozialdaten.
///
/// Jeder Mitarbeiter vergibt beim Erststart ein eigenes Passwort. Das Passwort
/// wird NICHT gespeichert — nur ein PBKDF2-SHA256-Hash zur Validierung.
class AuthService {
  static const _boxName = 'auth_data';

  /// OWASP 2023-Empfehlung für PBKDF2-HMAC-SHA256.
  static const _currentIterations = 600000;

  /// Alte Iteration-Anzahl (für Migration bestehender Installationen).
  static const _legacyIterations = 100000;

  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Prüft ob bereits ein Passwort vergeben wurde.
  bool get hasPassword {
    if (!isInitialized) return false;
    return _box!.get('password_hash') != null;
  }

  /// Neues Passwort setzen (Erststart oder Passwort-Wechsel).
  Future<void> setPassword(String password) async {
    if (!isInitialized) return;
    final salt = secureRandomBytes(32);
    final hash = _hashPassword(password, salt, _currentIterations);
    await _box!.put('password_salt', base64Encode(salt));
    await _box!.put('password_hash', hash);
    await _box!.put('password_iterations', _currentIterations.toString());
    // Failed-Counter zurücksetzen
    await _box!.delete('failed_attempts');
    await _box!.delete('lockout_until');
  }

  /// Prüft ob Account gesperrt ist (persistiert über App-Restart).
  bool get isLockedOut {
    final until = _lockoutUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _clearLockout();
      return false;
    }
    return true;
  }

  /// Verbleibende Sperrzeit in Sekunden.
  int get lockoutSeconds {
    final until = _lockoutUntil;
    if (until == null) return 0;
    return until.difference(DateTime.now()).inSeconds.clamp(0, 600);
  }

  DateTime? get _lockoutUntil {
    if (!isInitialized) return null;
    final raw = _box!.get('lockout_until');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  int get _failedAttempts {
    if (!isInitialized) return 0;
    return int.tryParse(_box!.get('failed_attempts') ?? '0') ?? 0;
  }

  Future<void> _clearLockout() async {
    if (!isInitialized) return;
    await _box!.delete('failed_attempts');
    await _box!.delete('lockout_until');
  }

  Future<void> _recordFailure() async {
    if (!isInitialized) return;
    final attempts = _failedAttempts + 1;
    await _box!.put('failed_attempts', attempts.toString());
    if (attempts >= 10) {
      await _box!.put(
        'lockout_until',
        DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      );
    } else if (attempts >= 5) {
      await _box!.put(
        'lockout_until',
        DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
      );
    }
  }

  /// Passwort prüfen.
  ///
  /// Bestehende 100k-Hashes werden bei erfolgreichem Login transparent
  /// auf 600k Iterationen hochgezogen.
  bool validatePassword(String password) {
    if (!isInitialized || !hasPassword) return false;
    if (isLockedOut) return false;

    final salt = base64Decode(_box!.get('password_salt')!);
    final storedHash = _box!.get('password_hash')!;
    final iterations =
        int.tryParse(_box!.get('password_iterations') ?? '') ??
            _legacyIterations;

    final inputHash = _hashPassword(password, salt, iterations);
    final valid = constantTimeEquals(
      utf8.encode(storedHash),
      utf8.encode(inputHash),
    );

    if (valid) {
      _clearLockout();
      if (iterations < _currentIterations) {
        _upgradeHash(password);
      }
    } else {
      _recordFailure();
    }

    return valid;
  }

  void _upgradeHash(String password) {
    final newSalt = secureRandomBytes(32);
    final newHash = _hashPassword(password, newSalt, _currentIterations);
    _box!.put('password_salt', base64Encode(newSalt));
    _box!.put('password_hash', newHash);
    _box!.put('password_iterations', _currentIterations.toString());
  }

  /// Passwort ändern (altes muss stimmen).
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!validatePassword(oldPassword)) return false;
    await setPassword(newPassword);
    return true;
  }

  /// Passwort-Stärke prüfen.
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

  /// PBKDF2 + SHA-256 Hash.
  String _hashPassword(String password, Uint8List salt, int iterations) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, 32));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return base64Encode(key);
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
