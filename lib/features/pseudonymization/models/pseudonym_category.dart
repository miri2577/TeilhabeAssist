enum PseudonymCategory {
  person('PERSON'),
  datum('DATUM'),
  adresse('ADRESSE'),
  telefon('TELEFON'),
  email('EMAIL'),
  aktenzeichen('AKTENZEICHEN'),
  behandler('BEHANDLER'),
  einrichtung('EINRICHTUNG');

  const PseudonymCategory(this.prefix);
  final String prefix;
}
