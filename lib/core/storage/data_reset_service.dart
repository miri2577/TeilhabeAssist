import 'package:hive_flutter/hive_flutter.dart';

/// Löscht alle App-Daten aus Hive (Factory Reset).
///
/// **WICHTIG — Audit-Log bleibt absichtlich erhalten.**
///
/// Forensische Anforderung: Wenn der Audit-Log gemeinsam mit den Daten
/// gelöscht werden könnte, wäre er als Nachweis wertlos — jeder Angreifer
/// könnte seine Spuren tilgen, und auch versehentliche Löschungen wären
/// nicht nachvollziehbar. Der Log überlebt deshalb jeden Reset und führt
/// die SHA-256-Hash-Kette unterbrechungsfrei fort.
///
/// Der Reset selbst wird durch den Aufrufer als Audit-Event protokolliert,
/// bevor `resetAll()` aufgerufen wird (Settings-Screen).
class DataResetService {
  /// Boxen die beim Reset gelöscht werden.
  /// `audit_log` ist hier ABSICHTLICH NICHT enthalten — siehe Klassen-Doc.
  static const List<String> _boxesToDelete = [
    'app_settings',
    'app_display_settings',
    'app_flags',
    'pseudonym_mappings',
    'user_excluded_words',
    'user_learned_names',
    'learned_names',
    'report_templates',
    'privacy_signatures',
    'feedback',
  ];

  /// Boxen die NIEMALS gelöscht werden dürfen (defensiv).
  /// - `audit_log`: forensischer Nachweis, gesetzlich erforderlich
  /// - `audit_context`: Device-ID muss persistent bleiben, damit Logs
  ///   nach dem Reset noch dem selben Gerät zugeordnet werden können
  /// - `audit_keys`: Träger-Signatur-Schlüsselpaar (Public-Key-Teil)
  static const List<String> _protectedBoxes = [
    'audit_log',
    'audit_context',
    'audit_keys',
  ];

  /// Anzahl der zu löschenden Boxen (für die UI).
  static int get boxesToDeleteCount => _boxesToDelete.length;

  static Future<int> resetAll() async {
    // Defensiv: prüfen dass protected boxes nicht versehentlich in der
    // Lösch-Liste landen, falls jemand sie ergänzt.
    for (final p in _protectedBoxes) {
      assert(!_boxesToDelete.contains(p),
          'Protected box "$p" darf nicht in _boxesToDelete stehen.');
    }

    var deletedCount = 0;
    for (final name in _boxesToDelete) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
        await Hive.box(name).close();
      }
      if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
        deletedCount++;
      }
    }
    return deletedCount;
  }
}
