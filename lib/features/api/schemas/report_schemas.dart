import '../../report_editor/models/report_draft.dart';

/// JSON-Schemas für strukturierten Bericht-Output.
///
/// Beide LLM-Provider unterstützen schema-gezwungene Ausgabe:
/// - Anthropic via `tools` + `tool_choice` mit `input_schema`
/// - OpenAI via `response_format: { type: "json_schema", json_schema: ... }`
///
/// Damit ist die Output-Struktur deterministisch und muss nicht mehr aus
/// Markdown geparst werden. Die Markdown-Ansicht wird **lokal** aus dem
/// strukturierten Objekt gerendert (siehe `report_markdown_renderer.dart`).
class ReportSchemas {
  ReportSchemas._();

  /// Tool-Name, der bei Anthropic für Tool-Use verwendet wird.
  static const toolName = 'submit_bericht';
  static const toolDescription =
      'Liefert den Informationsbericht in strukturierter Form. '
      'Pflichtfelder müssen vollständig ausgefüllt sein.';

  /// Schema-Variante für den User-Output-Wunsch (ausführlich vs. kompakt).
  static Map<String, dynamic> jsonSchemaFor(
    ReportType type,
    ReportSchema schema,
  ) {
    return switch ((type, schema)) {
      (ReportType.informationsbericht, ReportSchema.ausfuehrlichTib) =>
        _informationsberichtTib,
      (ReportType.informationsbericht, ReportSchema.kompaktOffiziell) =>
        _informationsberichtKompakt,
    };
  }

  // ────────────────────────────────────────────────────────────────────
  //   Gemeinsame Sub-Schemas
  // ────────────────────────────────────────────────────────────────────

  static const Map<String, dynamic> _allgemeineInformationen = {
    'type': 'object',
    'description': 'Allgemeine Informationen zu Lebenssituation und Sozialraum',
    'properties': {
      'ausbildung_arbeit_tagesstruktur': {
        'type': 'string',
        'description':
            'Ausbildung, Arbeit und sonstige Tagesstruktur als Fließtext (1–3 Absätze).',
      },
      'bedeutsame_kontakte': {
        'type': 'string',
        'description':
            'Regelmäßige und wichtige Kontakte der leistungsberechtigten Person (1–3 Absätze).',
      },
      'sozialraum_und_weiteres': {
        'type': 'string',
        'description':
            'Sozialräumliche Einschätzung und weitere relevante Informationen (Gesundheit, Wohnsituation, besondere Vorkommnisse).',
      },
    },
    'required': [
      'ausbildung_arbeit_tagesstruktur',
      'bedeutsame_kontakte',
      'sozialraum_und_weiteres',
    ],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> _zielerreichungsgrad = {
    'type': 'string',
    'enum': [
      'voll_erreicht',
      'teilweise_erreicht',
      'nicht_erreicht',
      'nicht_beurteilbar',
    ],
    'description': 'Vier-stufige Bewertung der Zielerreichung.',
  };

  static const Map<String, dynamic> _kontextfaktor = {
    'type': 'object',
    'properties': {
      'beschreibung': {
        'type': 'string',
        'description': 'Beschreibung des Faktors als Satz.',
      },
      'art': {
        'type': 'string',
        'enum': ['umweltfaktor', 'personenbezogen'],
        'description': 'ICF-Klassifikation des Kontextfaktors.',
      },
    },
    'required': ['beschreibung', 'art'],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> _assistenzleistungen = {
    'type': 'object',
    'properties': {
      'fachleistungsstunden_uebersicht': {
        'type': 'string',
        'description':
            'Übersicht der erbrachten Fachleistungsstunden (Beschreibung der Tätigkeitsschwerpunkte). Bei fehlenden konkreten Stundenangaben Hinweis "[ANGABE FEHLT]" ergänzen.',
      },
      'erreichbarkeit_nacht': {
        'type': 'boolean',
        'description':
            'Wurden Leistungen zur Erreichbarkeit in der Nacht erbracht?',
      },
      'besondere_vorkommnisse': {
        'type': 'string',
        'description': 'Besondere Vorkommnisse im Berichtszeitraum.',
      },
    },
    'required': [
      'fachleistungsstunden_uebersicht',
      'erreichbarkeit_nacht',
      'besondere_vorkommnisse',
    ],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> _zusammenfassung = {
    'type': 'object',
    'properties': {
      'gesamteinschaetzung': {
        'type': 'string',
        'description':
            'Gesamteinschätzung der Teilhabesituation, ICF-orientiert.',
      },
      'empfehlung_kommender_zeitraum': {
        'type': 'string',
        'description': 'Empfehlung für den kommenden Leistungszeitraum.',
      },
      'fls_empfehlung': {
        'type': 'string',
        'enum': ['erhoehung', 'beibehaltung', 'reduktion', 'keine_aussage'],
        'description':
            'Empfehlung zur Anpassung der Fachleistungsstunden.',
      },
      'fls_begruendung': {
        'type': 'string',
        'description': 'Kurze fachliche Begründung der FLS-Empfehlung.',
      },
    },
    'required': [
      'gesamteinschaetzung',
      'empfehlung_kommender_zeitraum',
      'fls_empfehlung',
      'fls_begruendung',
    ],
    'additionalProperties': false,
  };

  // ────────────────────────────────────────────────────────────────────
  //   Informationsbericht — Kompakt (Berliner Vorlage 1.01)
  // ────────────────────────────────────────────────────────────────────

  static const Map<String, dynamic> _teilhabezielKompakt = {
    'type': 'object',
    'properties': {
      'leitziel': {
        'type': 'string',
        'description':
            'Leitziel (genaue Formulierung aus Gesamtplan/ZLP, Tippfehler still korrigiert).',
      },
      'teilhabeziel_zlp': {
        'type': 'string',
        'description': 'Operationalisierung des Teilhabeziels.',
      },
      'indikator': {
        'type': 'string',
        'description':
            'Indikator: woran ist die Erreichung des Ziels erkennbar (1–2 Sätze).',
      },
      'zielerreichungsgrad': _zielerreichungsgrad,
      'erlaeuterung_zielerreichung': {
        'type': 'string',
        'description':
            'Fließtext aus Sicht des Leistungserbringers: Methodik, Verlauf, Bewertung. Keine a–h-Aufgliederung.',
      },
      'abweichende_einschaetzung_klient': {
        'type': 'string',
        'description':
            'Abweichende Einschätzung der leistungsberechtigten Person — leerer String wenn keine Abweichung besteht.',
      },
    },
    'required': [
      'leitziel',
      'teilhabeziel_zlp',
      'indikator',
      'zielerreichungsgrad',
      'erlaeuterung_zielerreichung',
      'abweichende_einschaetzung_klient',
    ],
    'additionalProperties': false,
  };

  static final Map<String, dynamic> _informationsberichtKompakt = {
    'type': 'object',
    'description':
        'Informationsbericht für Leistungen der Eingliederungshilfe '
        '(Berliner Vorlage 1.01, kompakte Variante)',
    'properties': {
      'allgemeine_informationen': _allgemeineInformationen,
      'teilhabeziele': {
        'type': 'array',
        'description': 'Ein Eintrag pro vereinbartem Teilhabeziel.',
        'items': _teilhabezielKompakt,
      },
      'assistenzleistungen': _assistenzleistungen,
      'zusammenfassung': _zusammenfassung,
    },
    'required': [
      'allgemeine_informationen',
      'teilhabeziele',
      'assistenzleistungen',
      'zusammenfassung',
    ],
    'additionalProperties': false,
  };

  // ────────────────────────────────────────────────────────────────────
  //   Informationsbericht — TIB ausführlich (ICF a–h)
  // ────────────────────────────────────────────────────────────────────

  static final Map<String, dynamic> _teilhabezielTib = {
    'type': 'object',
    'properties': {
      'leitziel': {'type': 'string'},
      'sicht_klient': {
        'type': 'string',
        'description': 'Sichtweise der leistungsberechtigten Person.',
      },
      'sicht_leistungserbringer': {
        'type': 'string',
        'description': 'Sichtweise des Leistungserbringers.',
      },
      'foerderliche_kontextfaktoren': {
        'type': 'array',
        'minItems': 1,
        'items': _kontextfaktor,
      },
      'hinderliche_kontextfaktoren': {
        'type': 'array',
        'minItems': 1,
        'items': _kontextfaktor,
      },
      'umfang_unterstuetzung': {
        'type': 'string',
        'description':
            'Umfang und Art der Unterstützung (qualifizierte vs. einfache Assistenz, FLS-Bezug).',
      },
      'zielerreichungsgrad': _zielerreichungsgrad,
      'zielerreichungs_begruendung': {
        'type': 'string',
        'description': 'Kurze Begründung des Zielerreichungsgrades.',
      },
      'veraenderungsbedarf': {
        'type': 'string',
        'description': 'Veränderungsbedarf für den kommenden Zeitraum.',
      },
    },
    'required': [
      'leitziel',
      'sicht_klient',
      'sicht_leistungserbringer',
      'foerderliche_kontextfaktoren',
      'hinderliche_kontextfaktoren',
      'umfang_unterstuetzung',
      'zielerreichungsgrad',
      'zielerreichungs_begruendung',
      'veraenderungsbedarf',
    ],
    'additionalProperties': false,
  };

  static final Map<String, dynamic> _informationsberichtTib = {
    'type': 'object',
    'description':
        'Informationsbericht für Leistungen der Eingliederungshilfe '
        '(ausführliche TIB-Variante mit ICF-Kontextfaktoren)',
    'properties': {
      'allgemeine_informationen': _allgemeineInformationen,
      'teilhabeziele': {
        'type': 'array',
        'minItems': 1,
        'maxItems': 10,
        'items': _teilhabezielTib,
      },
      'assistenzleistungen': _assistenzleistungen,
      'zusammenfassung': _zusammenfassung,
    },
    'required': [
      'allgemeine_informationen',
      'teilhabeziele',
      'assistenzleistungen',
      'zusammenfassung',
    ],
    'additionalProperties': false,
  };

}
