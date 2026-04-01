/// Erkennung und Blockierung von BRP Seite 4 (Psychiatrische Anamnese).
///
/// Seite 4 des BRP enthält die Krankengeschichte und darf gemäß Berliner
/// Rahmenvertrag NICHT an den Kostenträger weitergeleitet werden.
/// Diese Daten werden auch NICHT pseudonymisiert an die API gesendet.
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
        severity: BrpPage4Severity.blocked,
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

    // Bewertung
    if (keywordHits >= 3 && hasBrpContext) {
      warnings.add(BrpPage4Warning(
        message: 'Text enthält wahrscheinlich Inhalte aus BRP Seite 4 '
            '(Psychiatrische Anamnese/Krankengeschichte). '
            'Gefundene Schlüsselwörter: ${foundKeywords.join(", ")}',
        severity: BrpPage4Severity.blocked,
      ));
    } else if (keywordHits >= 2) {
      warnings.add(BrpPage4Warning(
        message: 'Text enthält möglicherweise Inhalte aus BRP Seite 4. '
            'Bitte prüfen: ${foundKeywords.join(", ")}',
        severity: BrpPage4Severity.warning,
      ));
    } else if (keywordHits >= 1 && hasBrpContext) {
      warnings.add(BrpPage4Warning(
        message: 'Im BRP-Kontext gefunden: ${foundKeywords.join(", ")} '
            '– bitte prüfen ob dies Seite 4 betrifft',
        severity: BrpPage4Severity.warning,
      ));
    }

    return warnings;
  }

  /// Prüft ob der Text blockiert werden sollte (nicht an API senden)
  static bool shouldBlock(String text) {
    return detect(text).any((w) => w.severity == BrpPage4Severity.blocked);
  }

  /// Entfernt erkannte Seite-4-Abschnitte aus dem Text.
  /// Gibt den bereinigten Text und die Anzahl entfernter Abschnitte zurück.
  static ({String cleanText, int removedSections}) removePage4Content(String text) {
    final lines = text.split('\n');
    final cleanLines = <String>[];
    var inPage4Section = false;
    var removedSections = 0;

    for (final line in lines) {
      final lower = line.toLowerCase().trim();

      // Abschnitt beginnt mit Seite-4-Überschrift
      if (_isPage4SectionStart(lower)) {
        inPage4Section = true;
        removedSections++;
        continue;
      }

      // Nächster Abschnitt (neue Überschrift) beendet Seite-4-Bereich
      if (inPage4Section && _isNewSectionStart(line)) {
        inPage4Section = false;
      }

      if (!inPage4Section) {
        cleanLines.add(line);
      }
    }

    return (cleanText: cleanLines.join('\n'), removedSections: removedSections);
  }

  static bool _isPage4SectionStart(String lowerLine) {
    const starters = [
      'krankengeschichte',
      'psychiatrische anamnese',
      'psychiatrische vorgeschichte',
      'familienanamnese',
      'substanzanamnese',
      'drogenanamnese',
      'alkoholanamnese',
      'psychopathologischer befund',
      'seite 4',
      'vertraulicher teil',
    ];
    for (final s in starters) {
      if (lowerLine.contains(s)) return true;
    }
    return false;
  }

  static bool _isNewSectionStart(String line) {
    final trimmed = line.trim();
    // Markdown-Überschriften oder nummerierte Abschnitte
    if (trimmed.startsWith('#')) return true;
    if (RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed)) return true;
    // Großbuchstaben-Überschriften (z.B. "AKTUELLE LEBENSSITUATION")
    if (trimmed.length > 5 &&
        trimmed == trimmed.toUpperCase() &&
        trimmed.contains(RegExp(r'[A-ZÄÖÜ]'))) return true;
    return false;
  }
}

enum BrpPage4Severity { warning, blocked }

class BrpPage4Warning {
  final String message;
  final BrpPage4Severity severity;

  const BrpPage4Warning({
    required this.message,
    required this.severity,
  });
}
