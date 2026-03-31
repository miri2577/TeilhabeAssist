import 'package:hive_flutter/hive_flutter.dart';

/// Löscht ALLE App-Daten aus Hive (Factory Reset).
class DataResetService {
  static Future<void> resetAll() async {
    // Alle bekannten Boxen löschen
    final boxNames = [
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

    for (final name in boxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
        await Hive.box(name).close();
      }
      await Hive.deleteBoxFromDisk(name);
    }
  }
}
