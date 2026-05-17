import '../../report_editor/models/report_draft.dart';

/// Erzeugt aus einem strukturierten Bericht (Map aus JSON) den
/// Markdown-Text, der in der UI angezeigt, als TXT exportiert und in den
/// "freien" PDF-Generator gefüttert wird. Pro `ReportType` × `ReportSchema`
/// ein eigenes Layout.
///
/// Der Code arbeitet defensiv: fehlende Felder werden übersprungen,
/// statt zu crashen. Damit ist die Ausgabe auch dann brauchbar, wenn das
/// LLM einzelne Optional-Felder leer gelassen hat.
class ReportMarkdownRenderer {
  ReportMarkdownRenderer._();

  static String render(
    Map<String, dynamic> data,
    ReportType type,
    ReportSchema schema,
  ) {
    return switch ((type, schema)) {
      (ReportType.informationsbericht, ReportSchema.ausfuehrlichTib) =>
        _renderInfoTib(data),
      (ReportType.informationsbericht, ReportSchema.kompaktOffiziell) =>
        _renderInfoKompakt(data),
      (ReportType.brp, _) => _renderBrp(data),
    };
  }

  // ────────────────────────────────────────────────────────────────────
  //   Informationsbericht — kompakt (Berliner Vorlage 1.01)
  // ────────────────────────────────────────────────────────────────────

  static String _renderInfoKompakt(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('# Informationsbericht (Version 1.01)');
    buf.writeln();

    _renderAllgemeineInfo(buf, data['allgemeine_informationen']);

    buf.writeln('## 2. Bericht zu vereinbarten Teilhabezielen');
    buf.writeln();

    final ziele = (data['teilhabeziele'] as List?) ?? const [];
    for (var i = 0; i < ziele.length; i++) {
      final z = ziele[i] as Map<String, dynamic>;
      buf.writeln('### Teilhabeziel ${i + 1}');
      buf.writeln();
      _kv(buf, 'Leitziel', z['leitziel']);
      _kv(buf, 'Teilhabeziel aus ZLP', z['teilhabeziel_zlp']);
      _kv(buf, 'Indikator', z['indikator']);
      _kv(buf, 'Zielerreichungsgrad',
          _readableZielerreichung(z['zielerreichungsgrad']));
      buf.writeln('- **Erläuterung zur Zielerreichung:**');
      buf.writeln('  ${(z['erlaeuterung_zielerreichung'] ?? '').toString().trim()}');
      final abw = (z['abweichende_einschaetzung_klient'] ?? '').toString().trim();
      _kv(buf, 'Abweichende Einschätzung der leistungsberechtigten Person',
          abw.isEmpty ? 'nein' : abw);
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }

    _renderAssistenz(buf, data['assistenzleistungen']);
    _renderZusammenfassung(buf, data['zusammenfassung']);
    return buf.toString().trim();
  }

  // ────────────────────────────────────────────────────────────────────
  //   Informationsbericht — TIB ausführlich (ICF a–h)
  // ────────────────────────────────────────────────────────────────────

  static String _renderInfoTib(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('# Informationsbericht (Version 1.01)');
    buf.writeln();

    _renderAllgemeineInfo(buf, data['allgemeine_informationen']);

    buf.writeln('## 2. Bericht zu vereinbarten Teilhabezielen');
    buf.writeln();

    final ziele = (data['teilhabeziele'] as List?) ?? const [];
    for (var i = 0; i < ziele.length; i++) {
      final z = ziele[i] as Map<String, dynamic>;
      buf.writeln('### Teilhabeziel ${i + 1}');
      buf.writeln();
      buf.writeln('**a) Leitziel**  ');
      buf.writeln('${z['leitziel'] ?? ''}');
      buf.writeln();
      buf.writeln('**b) Sichtweise der leistungsberechtigten Person**  ');
      buf.writeln('${z['sicht_klient'] ?? ''}');
      buf.writeln();
      buf.writeln('**c) Sichtweise des Leistungserbringers**  ');
      buf.writeln('${z['sicht_leistungserbringer'] ?? ''}');
      buf.writeln();
      _renderKontextliste(
        buf,
        'd) Förderliche Kontextfaktoren',
        z['foerderliche_kontextfaktoren'],
      );
      _renderKontextliste(
        buf,
        'e) Hinderliche Kontextfaktoren',
        z['hinderliche_kontextfaktoren'],
      );
      buf.writeln('**f) Umfang und Art der Unterstützung**  ');
      buf.writeln('${z['umfang_unterstuetzung'] ?? ''}');
      buf.writeln();
      final zg = _readableZielerreichung(z['zielerreichungsgrad']);
      buf.writeln('**g) Zielerreichungsgrad: $zg**  ');
      buf.writeln('${z['zielerreichungs_begruendung'] ?? ''}');
      buf.writeln();
      buf.writeln('**h) Veränderungsbedarf**  ');
      buf.writeln('${z['veraenderungsbedarf'] ?? ''}');
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
    }

    _renderAssistenz(buf, data['assistenzleistungen']);
    _renderZusammenfassung(buf, data['zusammenfassung']);
    return buf.toString().trim();
  }

  // ────────────────────────────────────────────────────────────────────
  //   BRP
  // ────────────────────────────────────────────────────────────────────

  static String _renderBrp(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('# Behandlungs- und Rehabilitationsplan');
    buf.writeln();

    final ls = data['aktuelle_lebenssituation'] as Map<String, dynamic>?;
    if (ls != null) {
      buf.writeln('## 1. Aktuelle Lebenssituation');
      buf.writeln();
      _kv(buf, 'Wohnsituation', ls['wohnsituation']);
      _kv(buf, 'Finanzielle Situation', ls['finanzielle_situation']);
      _kv(buf, 'Soziale Einbindung', ls['soziale_einbindung']);
      _kv(buf, 'Tagesstruktur', ls['tagesstruktur']);
      buf.writeln();
    }

    final hilfebedarf = (data['hilfebedarf'] as List?) ?? const [];
    if (hilfebedarf.isNotEmpty) {
      buf.writeln('## 2. Hilfebedarf');
      buf.writeln();
      for (final h in hilfebedarf) {
        final m = h as Map<String, dynamic>;
        buf.writeln('### ${m['lebensbereich'] ?? 'Lebensbereich'}');
        buf.writeln();
        _kv(buf, 'Aktuelle Situation', m['aktuelle_situation']);
        _kv(buf, 'Ressourcen', m['ressourcen']);
        _kv(buf, 'Einschränkungen', m['einschraenkungen']);
        _renderKontextliste(
          buf,
          'Förderliche Kontextfaktoren',
          m['foerderliche_kontextfaktoren'],
        );
        _renderKontextliste(
          buf,
          'Hinderliche Kontextfaktoren',
          m['hinderliche_kontextfaktoren'],
        );
        _kv(buf, 'Konkreter Hilfebedarf', m['konkreter_hilfebedarf']);
        buf.writeln();
      }
    }

    final hbb = data['hilfebedarfsbemessung'] as Map<String, dynamic>?;
    if (hbb != null) {
      buf.writeln('## 3. Hilfebedarfsbemessung');
      buf.writeln();
      _kv(buf, 'Hilfebedarfsgruppe', hbb['hilfebedarfsgruppe']);
      _kv(buf, 'Begründung', hbb['begruendung']);
      _kv(buf, 'Empfohlener Leistungstyp', hbb['empfohlener_leistungstyp']);
      _kv(buf, 'Empfohlene FLS', hbb['empfohlene_fls']);
      buf.writeln();
    }

    final ziele = (data['ziele_und_massnahmen'] as List?) ?? const [];
    if (ziele.isNotEmpty) {
      buf.writeln('## 4. Ziele und Maßnahmen');
      buf.writeln();
      for (var i = 0; i < ziele.length; i++) {
        final z = ziele[i] as Map<String, dynamic>;
        buf.writeln('### Ziel ${i + 1}');
        buf.writeln();
        _kv(buf, 'Leitziel', z['leitziel']);
        _kv(buf, 'Handlungsziel (SMART)', z['handlungsziel_smart']);
        final ms = (z['massnahmen'] as List?) ?? const [];
        if (ms.isNotEmpty) {
          buf.writeln('- **Maßnahmen:**');
          for (final m in ms) {
            buf.writeln('  - ${m.toString().trim()}');
          }
        }
        buf.writeln();
      }
    }

    final zus = (data['zusammenfassung'] ?? '').toString().trim();
    if (zus.isNotEmpty) {
      buf.writeln('## 5. Zusammenfassung');
      buf.writeln();
      buf.writeln(zus);
    }
    return buf.toString().trim();
  }

  // ────────────────────────────────────────────────────────────────────
  //   Gemeinsame Renderer
  // ────────────────────────────────────────────────────────────────────

  static void _renderAllgemeineInfo(StringBuffer buf, dynamic data) {
    if (data is! Map) return;
    buf.writeln('## 1. Allgemeine Informationen');
    buf.writeln();
    buf.writeln('### Ausbildung, Arbeit und sonstige Tagesstruktur');
    buf.writeln(data['ausbildung_arbeit_tagesstruktur'] ?? '');
    buf.writeln();
    buf.writeln('### Bedeutsame Kontakte');
    buf.writeln(data['bedeutsame_kontakte'] ?? '');
    buf.writeln();
    buf.writeln('### Weitere relevante Informationen (Sozialraum)');
    buf.writeln(data['sozialraum_und_weiteres'] ?? '');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }

  static void _renderAssistenz(StringBuffer buf, dynamic data) {
    if (data is! Map) return;
    buf.writeln('## 3. Assistenzleistungen');
    buf.writeln();
    buf.writeln('### Übersicht der erbrachten Fachleistungsstunden');
    buf.writeln(data['fachleistungsstunden_uebersicht'] ?? '');
    buf.writeln();
    buf.writeln('### Erreichbarkeit in der Nacht');
    buf.writeln(data['erreichbarkeit_nacht'] == true ? 'Ja' : 'Nein');
    buf.writeln();
    buf.writeln('### Besondere Vorkommnisse');
    buf.writeln(data['besondere_vorkommnisse'] ?? '');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }

  static void _renderZusammenfassung(StringBuffer buf, dynamic data) {
    if (data is! Map) return;
    buf.writeln('## 4. Zusammenfassung und Ausblick');
    buf.writeln();
    buf.writeln('### Gesamteinschätzung der Teilhabesituation');
    buf.writeln(data['gesamteinschaetzung'] ?? '');
    buf.writeln();
    buf.writeln('### Empfehlung für den kommenden Leistungszeitraum');
    buf.writeln(data['empfehlung_kommender_zeitraum'] ?? '');
    buf.writeln();
    buf.writeln('### Anpassung der FLS');
    buf.writeln(
      '**${_readableFls(data['fls_empfehlung'])}** — '
      '${data['fls_begruendung'] ?? ''}',
    );
  }

  static void _renderKontextliste(
    StringBuffer buf,
    String title,
    dynamic faktoren,
  ) {
    buf.writeln('**$title**  ');
    if (faktoren is List && faktoren.isNotEmpty) {
      for (final f in faktoren) {
        final m = f as Map<String, dynamic>;
        final art = m['art'] == 'umweltfaktor'
            ? 'Umweltfaktor'
            : 'personenbezogener Faktor';
        buf.writeln('- ${m['beschreibung'] ?? ''} ($art)');
      }
    } else {
      buf.writeln('- Keine Angaben');
    }
    buf.writeln();
  }

  static void _kv(StringBuffer buf, String label, dynamic value) {
    final v = (value ?? '').toString().trim();
    if (v.isEmpty) return;
    buf.writeln('- **$label:** $v');
  }

  static String _readableZielerreichung(dynamic v) {
    return switch (v?.toString()) {
      'voll_erreicht' => 'voll erreicht',
      'teilweise_erreicht' => 'teilweise erreicht',
      'nicht_erreicht' => 'nicht erreicht',
      'nicht_beurteilbar' => 'nicht beurteilbar',
      _ => (v ?? '').toString(),
    };
  }

  static String _readableFls(dynamic v) {
    return switch (v?.toString()) {
      'erhoehung' => 'Erhöhung empfohlen',
      'beibehaltung' => 'Beibehaltung empfohlen',
      'reduktion' => 'Reduktion empfohlen',
      'keine_aussage' => 'Keine Aussage möglich',
      _ => (v ?? '').toString(),
    };
  }
}
