class RegexPatterns {
  RegexPatterns._();

  /// Numerische Datumsformate: 01.01.2024, 01/01/2024, 1.1.24, 2024-03-15.
  static final date = RegExp(
    r'\b('
    // dd.MM.yyyy oder dd/MM/yyyy oder dd.MM.yy
    r'\d{1,2}[./]\d{1,2}[./]\d{2,4}'
    // ISO: yyyy-MM-dd
    r'|\d{4}-\d{1,2}-\d{1,2}'
    r')\b',
  );

  /// Datum mit Monatsnamen: "15. März 2024", "März 2024", "15 März 2024".
  static final dateWithMonthName = RegExp(
    r'\b(?:\d{1,2}\.?\s+)?'
    r'(?:Januar|Februar|März|April|Mai|Juni|Juli|August|'
    r'September|Oktober|November|Dezember|'
    r'Jan|Feb|Mär|Mrz|Apr|Jun|Jul|Aug|Sep|Sept|Okt|Nov|Dez)'
    r'\s+\d{2,4}\b',
  );

  /// Geburtsjahr im Kontext: "geboren 1985", "Jg. 1985", "Jahrgang 1985".
  /// Reine Jahreszahlen außerhalb dieses Kontexts werden nicht erkannt,
  /// um False Positives in Fließtext zu vermeiden.
  static final birthYear = RegExp(
    r'\b(?:geb(?:oren|\.|\s)|Jg\.|Jahrgang|geb\sam|Geburtsjahr[:\s])\s*'
    r'(?:im\s+Jahr\s+)?'
    r'(\d{4})\b',
    caseSensitive: false,
  );

  /// Deutsche Telefonnummern: +49, 030, 0170, etc.
  static final phone = RegExp(
    r'(?:\+49[\s\-]?|0)[\s\-]?'
    r'(?:\(?\d{2,5}\)?[\s\-]?)'
    r'[\d\s\-/]{4,12}\d',
  );

  /// E-Mail-Adressen
  static final email = RegExp(
    r'\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b',
  );

  /// Berliner Kostenübernahme-IDs: EH-2024-12345, EGH/2024/12345 etc.
  static final aktenzeichen = RegExp(
    r'\b(?:EH|EGH|SGB|TH|GPV)[\-/]\d{4}[\-/]\d{3,6}(?:[\-/][A-Z]{1,3})?\b',
    caseSensitive: false,
  );

  /// ICD-10-Codes: F20.0, G40.9, F33.1a — werden erkannt aber NICHT ersetzt.
  /// Unterstützt optionale 4. Stelle (z.B. F33.1a) sowie reine 3-stellige
  /// Codes ohne Punkt (z.B. M54).
  static final icd10 = RegExp(
    r'\b[A-TV-Z]\d{2}(?:\.\d{1,2}[a-z]?)?\b',
  );

  /// Adress-Pattern: "Straßenname Nr., PLZ Ort"
  static final addressFull = RegExp(
    r'[A-ZÄÖÜ][a-zäöüß]+(?:[\s\-][A-Za-zäöüßÄÖÜ]+)*'
    r'(?:str\.|straße|weg|platz|allee|damm|ring|ufer|zeile|gasse|pfad|chaussee|promenade)'
    r'\s*\d+[a-zA-Z]?'
    r'(?:\s*,?\s*\d{5}\s+[A-ZÄÖÜ][a-zäöüß]+)?',
    caseSensitive: false,
  );

  /// Anrede + Name: "Herr Müller", "Herrn Dode", "Frau Dr. Schmidt"
  static final anredeName = RegExp(
    r'\b(?:Herrn?|Frau|Hr\.|Fr\.)\s+'
    r'(?:(?:Dr\.|Prof\.|Dipl\.\-?\w+\.?)\s+)?'
    r'[A-ZÄÖÜ][a-zäöüß]+(?:\s+[A-ZÄÖÜ][a-zäöüß]+)?',
  );

  /// Potenzielle Eigennamen: Großgeschriebenes Wort, nicht am Satzanfang
  static final potentialName = RegExp(
    r'(?<=[a-zäöüß,;:]\s)[A-ZÄÖÜ][a-zäöüß]{2,}',
  );
}
