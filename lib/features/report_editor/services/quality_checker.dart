import '../models/report_draft.dart';
import '../models/report_module.dart';

enum QualityIssueSeverity { error, warning, info }

class QualityIssue {
  final String message;
  final QualityIssueSeverity severity;
  final String? moduleId;

  const QualityIssue({
    required this.message,
    required this.severity,
    this.moduleId,
  });
}

/// Automatische Qualitätsprüfung für generierte Berichte.
class QualityChecker {
  QualityChecker._();

  /// Prüft einen Berichtsentwurf VOR der Generierung
  static List<QualityIssue> checkDraft(ReportDraft draft) {
    final issues = <QualityIssue>[];

    // 1. Vollständigkeitsprüfung: Pflichtmodule mit Inhalt?
    for (final module in draft.modules) {
      if (module.type.required && module.notes.trim().isEmpty) {
        issues.add(QualityIssue(
          message: 'Pflichtmodul "${module.title}" hat keine Stichpunkte.',
          severity: QualityIssueSeverity.warning,
          moduleId: module.id,
        ));
      }
    }

    // 2. Mindestens ein Teilhabeziel?
    if (draft.type == ReportType.informationsbericht) {
      final goals =
          draft.modules.where((m) => m.type == ModuleType.teilhabeziel);
      if (goals.isEmpty) {
        issues.add(const QualityIssue(
          message: 'Kein Teilhabeziel angelegt. '
              'Der Informationsbericht erfordert mindestens ein Ziel.',
          severity: QualityIssueSeverity.error,
        ));
      } else {
        for (final goal in goals) {
          if (goal.notes.trim().isEmpty) {
            issues.add(QualityIssue(
              message: '"${goal.title}" hat keine Stichpunkte.',
              severity: QualityIssueSeverity.warning,
              moduleId: goal.id,
            ));
          }
        }
      }
    }

    // 3. FLS-Daten vorhanden?
    final flsModule =
        draft.modules.where((m) => m.type == ModuleType.flsUebersicht);
    if (flsModule.isNotEmpty && flsModule.first.notes.trim().isEmpty) {
      issues.add(const QualityIssue(
        message: 'FLS-Übersicht ist leer. Angaben zu Fachleistungsstunden '
            'sind für den Bericht wichtig.',
        severity: QualityIssueSeverity.warning,
      ));
    }

    return issues;
  }

  /// Prüft den generierten Berichtstext NACH der Generierung
  static List<QualityIssue> checkGeneratedText(
    String text,
    ReportType type,
  ) {
    final issues = <QualityIssue>[];
    final textLower = text.toLowerCase();

    // 1. ICF-Konsistenz: Kontextfaktoren als Förder-/Barriere markiert?
    if (textLower.contains('kontextfaktor') &&
        !textLower.contains('förderfaktor') &&
        !textLower.contains('barriere')) {
      issues.add(const QualityIssue(
        message: 'Kontextfaktoren werden erwähnt, aber nicht als '
            'Förderfaktor oder Barriere klassifiziert.',
        severity: QualityIssueSeverity.warning,
      ));
    }

    // 2. Perspektiven-Check: Sichtweisen vorhanden?
    if (type == ReportType.informationsbericht) {
      if (!textLower.contains('sichtweise') &&
          !textLower.contains('perspektive') &&
          !textLower.contains('aus sicht')) {
        issues.add(const QualityIssue(
          message: 'Keine Sichtweisen (Person / Leistungserbringer) erkennbar. '
              'Der Informationsbericht v1.01 erfordert beide Perspektiven pro Ziel.',
          severity: QualityIssueSeverity.warning,
        ));
      }
    }

    // 3. Sprachprüfung: Defizitorientierte Formulierungen erkennen
    final deficitPatterns = [
      RegExp(r'\bkann nicht\b', caseSensitive: false),
      RegExp(r'\bist nicht in der lage\b', caseSensitive: false),
      RegExp(r'\bist unfähig\b', caseSensitive: false),
      RegExp(r'\bversagt\b', caseSensitive: false),
      RegExp(r'\bdefizit\b', caseSensitive: false),
      RegExp(r'\bschwäche\b', caseSensitive: false),
      RegExp(r'\bverweigert\b', caseSensitive: false),
      RegExp(r'\bmanipulativ\b', caseSensitive: false),
      RegExp(r'\buneinsichtig\b', caseSensitive: false),
      RegExp(r'\bnon-?compliant\b', caseSensitive: false),
    ];

    for (final pattern in deficitPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        issues.add(QualityIssue(
          message: 'Möglicherweise defizitorientierte Formulierung: '
              '"${match.group(0)}". Ressourcenorientiert umformulieren?',
          severity: QualityIssueSeverity.info,
        ));
      }
    }

    // 4. Platzhalter-Reste prüfen
    final placeholderPattern = RegExp(r'\[[A-Z]+_\d{3}\]');
    if (placeholderPattern.hasMatch(text)) {
      issues.add(const QualityIssue(
        message: 'Der Text enthält noch Platzhalter. '
            'Die Rekonstruktion war möglicherweise unvollständig.',
        severity: QualityIssueSeverity.error,
      ));
    }

    // 5. Mindestlänge prüfen
    if (text.split(' ').length < 200) {
      issues.add(const QualityIssue(
        message: 'Der Bericht ist sehr kurz (< 200 Wörter). '
            'Prüfe ob alle relevanten Inhalte enthalten sind.',
        severity: QualityIssueSeverity.warning,
      ));
    }

    return issues;
  }
}
