import 'package:uuid/uuid.dart';
import 'report_module.dart';

const _uuid = Uuid();

enum ReportType {
  informationsbericht('Informationsbericht (Berlin v1.01)'),
  brp('BRP (4. Berliner Fassung)');

  const ReportType(this.label);
  final String label;
}

class ReportDraft {
  final String id;
  final ReportType type;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Alter Bericht (Copy & Paste)
  String previousReport;

  /// Module in der Reihenfolge des Berichts
  List<ReportModule> modules;

  /// Generierter Berichtstext (nach API-Aufruf)
  String? generatedText;

  /// Pseudonymisierter Text (der an die API ging)
  String? pseudonymizedText;

  ReportDraft({
    String? id,
    required this.type,
    DateTime? createdAt,
    this.previousReport = '',
    List<ReportModule>? modules,
    this.generatedText,
    this.pseudonymizedText,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = DateTime.now(),
        modules = modules ?? _defaultModules(type);

  static List<ReportModule> _defaultModules(ReportType type) {
    return switch (type) {
      ReportType.informationsbericht => [
        ReportModule(type: ModuleType.kopfdaten),
        ReportModule(type: ModuleType.persondaten),
        ReportModule(type: ModuleType.allgemeineInfos),
        ReportModule(type: ModuleType.teilhabeziel, goalNumber: 1),
        ReportModule(type: ModuleType.flsUebersicht),
        ReportModule(type: ModuleType.kontextfaktoren),
        ReportModule(type: ModuleType.zusammenfassung),
      ],
      ReportType.brp => [
        ReportModule(type: ModuleType.kopfdaten),
        ReportModule(type: ModuleType.persondaten),
        ReportModule(type: ModuleType.brpLebenssituation),
        ReportModule(type: ModuleType.brpHilfebedarf),
        ReportModule(type: ModuleType.brpHilfebedarfsbemessung),
        ReportModule(type: ModuleType.brpZieleMassnahmen),
        ReportModule(type: ModuleType.flsUebersicht),
        ReportModule(type: ModuleType.zusammenfassung),
      ],
    };
  }

  /// Alle Stichpunkte als zusammenhängenden Text
  String get allNotesAsText {
    final buffer = StringBuffer();
    for (final module in modules) {
      if (module.notes.trim().isNotEmpty) {
        buffer.writeln('## ${module.title}');
        buffer.writeln(module.notes.trim());
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}
