/// Fachleistungsstunden-Daten für einen Berichtszeitraum
class FlsData {
  /// Bewilligte wöchentliche FLS (laut Leistungsbescheid)
  double bewilligtProWoche;

  /// Davon qualifizierte Assistenz (in Stunden/Woche)
  double qualifiziertProWoche;

  /// Davon einfache (kompensatorische) Assistenz (in Stunden/Woche)
  double einfachProWoche;

  /// Berichtszeitraum in Wochen
  int berichtszeitraumWochen;

  /// Tatsächlich erbrachte FLS gesamt im Zeitraum
  double erbracht;

  /// Davon qualifizierte Assistenz erbracht
  double erbrachtQualifiziert;

  /// Davon einfache Assistenz erbracht
  double erbrachtEinfach;

  /// Ausfallstunden (dokumentiert)
  double ausfallstunden;

  /// Begründung für Abweichungen
  String abweichungsBegruendung;

  FlsData({
    this.bewilligtProWoche = 0,
    this.qualifiziertProWoche = 0,
    this.einfachProWoche = 0,
    this.berichtszeitraumWochen = 26,
    this.erbracht = 0,
    this.erbrachtQualifiziert = 0,
    this.erbrachtEinfach = 0,
    this.ausfallstunden = 0,
    this.abweichungsBegruendung = '',
  });

  /// Bewilligte FLS gesamt im Berichtszeitraum
  double get bewilligtGesamt => bewilligtProWoche * berichtszeitraumWochen;

  /// Auslastungsquote in Prozent
  double get auslastung =>
      bewilligtGesamt > 0 ? (erbracht / bewilligtGesamt * 100) : 0;

  /// Abweichung in Stunden
  double get abweichungStunden => erbracht - bewilligtGesamt;

  /// Fachkraftquote (qualifiziert / gesamt erbracht)
  double get fachkraftquote =>
      erbracht > 0 ? (erbrachtQualifiziert / erbracht * 100) : 0;

  /// Indirekte Assistenz nach 5:1-Regel
  double get indirekteAssistenz => erbracht / 5;

  /// Hat signifikante Abweichung (>10%)
  bool get hatAbweichung =>
      bewilligtGesamt > 0 && (auslastung - 100).abs() > 10;

  /// Fachkraftquote unter Berliner Orientierungsgröße (75%)
  bool get fachkraftquoteUnter75 => fachkraftquote < 75;

  /// Zusammenfassung als Text (für den Prompt)
  String toPromptText() {
    final buf = StringBuffer();
    buf.writeln('Bewilligte FLS: $bewilligtProWoche Std./Woche '
        '(${bewilligtGesamt.toStringAsFixed(1)} Std. im Berichtszeitraum)');
    buf.writeln('  - Qualifizierte Assistenz: $qualifiziertProWoche Std./Woche');
    buf.writeln('  - Einfache Assistenz: $einfachProWoche Std./Woche');
    buf.writeln('Erbrachte FLS: ${erbracht.toStringAsFixed(1)} Std. gesamt');
    buf.writeln('  - Qualifiziert: ${erbrachtQualifiziert.toStringAsFixed(1)} Std.');
    buf.writeln('  - Einfach: ${erbrachtEinfach.toStringAsFixed(1)} Std.');
    buf.writeln('Auslastung: ${auslastung.toStringAsFixed(1)}%');
    buf.writeln('Fachkraftquote: ${fachkraftquote.toStringAsFixed(1)}%');
    if (ausfallstunden > 0) {
      buf.writeln('Ausfallstunden: ${ausfallstunden.toStringAsFixed(1)} Std.');
    }
    if (abweichungsBegruendung.isNotEmpty) {
      buf.writeln('Begründung Abweichung: $abweichungsBegruendung');
    }
    return buf.toString();
  }
}
