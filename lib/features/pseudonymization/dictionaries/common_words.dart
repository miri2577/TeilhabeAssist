/// Deutsche Wörter die großgeschrieben werden, aber keine Eigennamen sind.
/// Verhindert False Positives bei der Namens-Erkennung.
/// WICHTIG: Im Deutschen sind ALLE Substantive großgeschrieben.
/// Diese Liste muss deshalb sehr umfangreich sein.
const kCommonWords = <String>{
  // Wochentage
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag',
  'Sonnabend', 'Sonntag',

  // Monate
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
  'September', 'Oktober', 'November', 'Dezember',

  // Häufige Substantive in Berichten der Eingliederungshilfe
  'Teilhabe', 'Assistenz', 'Eingliederungshilfe', 'Leistung', 'Leistungen',
  'Bedarfsermittlung', 'Gesamtplan', 'Gesamtplanverfahren', 'Hilfebedarf',
  'Hilfeplan', 'Behandlung', 'Rehabilitation', 'Therapie', 'Betreuung',
  'Unterstützung', 'Förderung', 'Begleitung', 'Anleitung', 'Motivation',
  'Aktivität', 'Partizipation', 'Inklusion', 'Selbstbestimmung',
  'Selbstversorgung', 'Mobilität', 'Kommunikation', 'Interaktion',
  'Gemeinschaft', 'Gesundheit', 'Wohlbefinden', 'Lebensqualität',
  'Berichtszeitraum', 'Leistungstyp', 'Leistungsbescheid',

  // ICF-Begriffe
  'Körperfunktion', 'Körperstruktur', 'Aktivitäten',
  'Umweltfaktoren', 'Kontextfaktoren', 'Förderfaktoren', 'Barrieren',
  'Ressourcen', 'Einschränkungen', 'Beeinträchtigungen',

  // Medizinische / psychiatrische Fachbegriffe
  'Diagnose', 'Diagnosen', 'Episode', 'Episoden', 'Schizophrenie',
  'Depression', 'Persönlichkeitsstörung', 'Störung', 'Syndrom',
  'Borderline', 'Psychose', 'Sucht', 'Abhängigkeit', 'Angst',
  'Zwang', 'Trauma', 'Demenz', 'Autismus', 'Symptom', 'Symptome',
  'Medikation', 'Nebenwirkungen', 'Remission', 'Rezidiv', 'Krise',
  'Krisenintervention', 'Stabilisierung', 'Dekompensation',
  'Compliance', 'Adhärenz', 'Krankheitseinsicht',
  'Antrieb', 'Antriebslosigkeit', 'Stimmung', 'Affekt', 'Wahn',
  'Halluzination', 'Dissoziation', 'Flashback',

  // Entwicklungs- und Verlaufsbegriffe
  'Entwicklung', 'Entwicklungen', 'Fortschritt', 'Fortschritte',
  'Verbesserung', 'Verschlechterung', 'Veränderung', 'Veränderungen',
  'Stagnation', 'Rückschritt', 'Rückfall', 'Erholung',

  // Ortsbezeichnungen / Himmelsrichtungen
  'Norden', 'Süden', 'Osten', 'Westen', 'Mitte', 'Berlin',
  'Deutschland', 'Europa',

  // Bezirke als Bezeichnung (nicht als Name)
  'Charlottenburg', 'Wilmersdorf', 'Spandau', 'Steglitz', 'Zehlendorf',
  'Tempelhof', 'Schöneberg', 'Neukölln', 'Treptow', 'Köpenick',
  'Marzahn', 'Hellersdorf', 'Lichtenberg', 'Reinickendorf', 'Pankow',
  'Weißensee', 'Friedrichshain', 'Kreuzberg', 'Prenzlauer', 'Wedding',
  'Moabit', 'Tiergarten',

  // Berichts-Fachbegriffe
  'Bericht', 'Informationsbericht', 'Verlauf', 'Zusammenfassung',
  'Empfehlung', 'Ziel', 'Ziele', 'Leitziel', 'Handlungsziel',
  'Maßnahme', 'Maßnahmen', 'Evaluation', 'Dokumentation', 'Planung',
  'Fachleistungsstunde', 'Fachleistungsstunden', 'Kostenübernahme',
  'Leistungserbringer', 'Kostenträger', 'Bezugsbetreuer',
  'Bezugsbetreuerin', 'Aktenzeichen', 'Vorgang',

  // Allgemeine häufige Substantive
  'Alltag', 'Arbeit', 'Ausbildung', 'Auto', 'Arzt', 'Ärztin',
  'Behörde', 'Besuch', 'Bruder', 'Büro', 'Chef', 'Dienst', 'Eltern',
  'Familie', 'Firma', 'Freund', 'Freundin', 'Garten', 'Geld',
  'Gespräch', 'Gruppe', 'Haus', 'Hausarzt', 'Haushalt', 'Hilfe',
  'Internet', 'Kind', 'Kinder', 'Kirche', 'Klinik', 'Kontakt',
  'Küche', 'Medikament', 'Medikamente', 'Mensch', 'Menschen',
  'Mutter', 'Nachbar', 'Nacht', 'Partei', 'Partner', 'Partnerin',
  'Person', 'Pflege', 'Polizei', 'Praxis', 'Problem', 'Probleme',
  'Regel', 'Regeln', 'Reise', 'Rente', 'Schule', 'Schwester',
  'Sport', 'Staat', 'Stadt', 'Stress', 'Stunde', 'Termin', 'Termine',
  'Tochter', 'Typ', 'Vater', 'Verein', 'Wohnung', 'Zeit',

  // Weitere häufige Substantive die in Berichten vorkommen
  'Angehörige', 'Angehöriger', 'Angebot', 'Angebote', 'Aufgabe',
  'Aufgaben', 'Bedarf', 'Bedürfnis', 'Bedürfnisse', 'Beispiel',
  'Beratung', 'Bereich', 'Bereiche', 'Beschäftigung', 'Bewilligung',
  'Bewohner', 'Bewohnerin', 'Bezirk', 'Eigenständigkeit', 'Einkauf',
  'Einkommen', 'Entlassung', 'Ergebnis', 'Fähigkeit', 'Fähigkeiten',
  'Fall', 'Fehler', 'Freizeit', 'Gefühl', 'Gefühle', 'Grund',
  'Grundlage', 'Hausbesuch', 'Herausforderung', 'Hygiene',
  'Interesse', 'Interessen', 'Jahr', 'Jahre', 'Kleidung',
  'Konflikt', 'Konflikte', 'Konzept', 'Lage', 'Leben',
  'Lebensbereich', 'Lebensbereiche', 'Lebenslage',
  'Mitarbeiter', 'Mitarbeiterin', 'Monat', 'Monate', 'Nachbarschaft',
  'Perspektive', 'Phase', 'Programm', 'Projekt', 'Rahmen',
  'Raum', 'Recht', 'Richtung', 'Risiko', 'Rolle',
  'Schwierigkeit', 'Schwierigkeiten', 'Sicherheit', 'Situation',
  'Sitzung', 'Sorge', 'Struktur', 'Tagesstruktur', 'Tätigkeit',
  'Teil', 'Thema', 'Themen', 'Umfeld', 'Umgang',
  'Umzug', 'Verhalten', 'Vermeidung', 'Versorgung', 'Verständnis',
  'Vertrauen', 'Verwaltung', 'Wille', 'Wirkung', 'Wunsch', 'Wünsche',
  'Zeitraum', 'Zugang', 'Zustand',

  // Adjektive die substantiviert vorkommen können
  'Betroffene', 'Betroffener', 'Bekannte', 'Bekannter',
  'Verwandte', 'Verwandter', 'Anwesende',
};
