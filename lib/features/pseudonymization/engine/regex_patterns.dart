class RegexPatterns {
  RegexPatterns._();

  /// Datumsformate: 01.01.2024, 01/01/2024, 1.1.24
  static final date = RegExp(
    r'\b(\d{1,2})[./](\d{1,2})[./](\d{2,4})\b',
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

  /// ICD-10-Codes: F20.0, G40.9 etc. – werden erkannt aber NICHT ersetzt
  static final icd10 = RegExp(
    r'\b[A-Z]\d{2}(?:\.\d{1,2})?\b',
  );

  /// Berliner Postleitzahlen im Adresskontext: 10115–14199
  static final berlinPlz = RegExp(
    r'\b(1(?:0[0-9]{3}|1[0-9]{3}|2[0-9]{3}|3[0-9]{3}|4[01][0-9]{2}))\b',
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
