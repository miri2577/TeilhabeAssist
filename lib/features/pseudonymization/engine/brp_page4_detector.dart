/// Erkennung von BRP Seite 4 (Psychiatrische Anamnese).
///
/// Seite 4 des BRP enthält die Krankengeschichte und darf gemäß Berliner
/// Rahmenvertrag NICHT an den Kostenträger weitergeleitet werden.
/// Diese Daten werden auch NICHT pseudonymisiert an die API gesendet.
///
/// Die Erkennung ist bewusst konservativ: nur WARNEN, nicht automatisch
/// entfernen – der Benutzer entscheidet im Review-Step.
class BrpPage4Detector {
  BrpPage4Detector._();

  /// Schlüsselwörter die auf Seite 4 (psychiatrische Anamnese) hinweisen
  static const _page4Keywords = [
    'krankengeschichte',
    'psychiatrische anamnese',
    'psychiatrische vorgeschichte',
    'ersterkrankung',
    'erstmanifestation',
    'krankheitsverlauf',
    'suizidversuch',
    'suizidversuche',
    'stationäre aufenthalte',
    'stationäre behandlungen',
    'psychiatrische behandlung',
    'forensische',
    'unterbringung',
    'zwangseinweisung',
    'psychopathologischer befund',
    'familienanamnese',
    'substanzanamnese',
    'drogenanamnese',
    'alkoholanamnese',
    'seite 4',
    'vertraulich',
  ];

  /// Kontextuelle Marker die zusammen mit Keywords auf Seite 4 hinweisen
  static const _contextMarkers = [
    'brp',
    'behandlungs- und rehabilitationsplan',
    'behandlungsplan',
    'rehabilitationsplan',
    'nicht weiterzuleiten',
    'darf nicht weitergeleitet',
    'vertraulicher teil',
  ];

  /// Prüft ob ein Text Inhalte von BRP Seite 4 enthält.
  /// Gibt eine Liste von Warnungen zurück. Leere Liste = kein Problem.
  static List<BrpPage4Warning> detect(String text) {
    final textLower = text.toLowerCase();
    final warnings = <BrpPage4Warning>[];

    // Direkte Seite-4-Referenz
    if (textLower.contains('seite 4') || textLower.contains('seite vier')) {
      warnings.add(BrpPage4Warning(
        message: 'Explizite Referenz auf "Seite 4" des BRP erkannt',
        severity: BrpPage4Severity.warning,
      ));
    }

    // Keyword-Zählung
    int keywordHits = 0;
    final foundKeywords = <String>[];
    for (final keyword in _page4Keywords) {
      if (textLower.contains(keyword)) {
        keywordHits++;
        foundKeywords.add(keyword);
      }
    }

    // BRP-Kontext prüfen
    bool hasBrpContext = false;
    for (final marker in _contextMarkers) {
      if (textLower.contains(marker)) {
        hasBrpContext = true;
        break;
      }
    }

    // Bewertung – nur Warnungen, nie automatisch blockieren
    if (keywordHits >= 3 && hasBrpContext) {
      warnings.add(BrpPage4Warning(
        message: 'Text enthält wahrscheinlich Inhalte aus BRP Seite 4 '
            '(Psychiatrische Anamnese/Krankengeschichte). '
            'Gefundene Schlüsselwörter: ${foundKeywords.join(", ")}',
        severity: BrpPage4Severity.warning,
      ));
    } else if (keywordHits >= 2) {
      warnings.add(BrpPage4Warning(
        message: 'Text enthält möglicherweise Inhalte aus BRP Seite 4. '
            'Bitte prüfen: ${foundKeywords.join(", ")}',
        severity: BrpPage4Severity.info,
      ));
    } else if (keywordHits >= 1 && hasBrpContext) {
      warnings.add(BrpPage4Warning(
        message: 'Im BRP-Kontext gefunden: ${foundKeywords.join(", ")} '
            '– bitte prüfen ob dies Seite 4 betrifft',
        severity: BrpPage4Severity.info,
      ));
    }

    return warnings;
  }
}

enum BrpPage4Severity { info, warning }

class BrpPage4Warning {
  final String message;
  final BrpPage4Severity severity;

  const BrpPage4Warning({
    required this.message,
    required this.severity,
  });
}
