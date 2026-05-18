import 'dart:io';

import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Trägt Kontextfelder, die in jedem Audit-Log-Eintrag stehen.
///
/// Wird einmal beim App-Start initialisiert. Die Werte werden in der
/// `app_settings`-Hive-Box persistiert (außer `appVersion`, die kommt
/// jedes Mal frisch aus dem Build).
class AuditContext {
  AuditContext._();

  // Eigene Box, damit kein Konflikt mit der AES-verschlüsselten
  // `app_settings`-Box von SettingsStorage entsteht. DeviceID ist
  // keine sensitive Information — Klartext-Box reicht.
  static const _boxName = 'audit_context';
  static const _deviceIdKey = 'device_id';

  static String _deviceId = '';
  static String _appVersion = 'unknown';
  static String _hostname = 'unknown';
  static String _currentUserName = '';

  static String get deviceId => _deviceId;
  static String get appVersion => _appVersion;
  static String get hostname => _hostname;
  static String get currentUserName => _currentUserName;

  /// Beim App-Start aufrufen — sobald Hive initialisiert ist.
  static Future<void> init() async {
    // Device-ID — beim ersten Start generieren, dann fest.
    final box = await Hive.openBox(_boxName);
    final stored = box.get(_deviceIdKey);
    if (stored is String && stored.isNotEmpty) {
      _deviceId = stored;
    } else {
      _deviceId = const Uuid().v4();
      await box.put(_deviceIdKey, _deviceId);
    }

    // App-Version aus pubspec.
    try {
      final pi = await PackageInfo.fromPlatform();
      _appVersion = '${pi.version}+${pi.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }

    // Hostname — Platform.localHostname kann auf manchen Plattformen
    // werfen, daher abgesichert.
    try {
      _hostname = Platform.localHostname;
    } catch (_) {
      _hostname = 'unknown';
    }
  }

  /// Nach erfolgreichem Datenschutz-Signing setzen, damit alle weiteren
  /// Audit-Einträge den Nutzer kennen. Reset auf leer beim Logout.
  static void setCurrentUserName(String name) {
    _currentUserName = name.trim();
  }
}
