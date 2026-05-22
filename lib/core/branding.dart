/// Zentrale Branding-Konstanten — werden im gesamten UI verwendet.
///
/// Class-Namen wie `TeilhabeAssistApp` bleiben aus historischen Gründen
/// im Dart-Code stehen (kein Refactor-Risiko); der nach außen sichtbare
/// Name ist [displayName].
class AppBranding {
  AppBranding._();

  static const String displayName = 'FEGH-Bericht';
  static const String tagline = 'Eingliederungshilfe nach SGB IX';
  static const String suiteName = 'FEGH-Suite';
  static const String repoUrl = 'https://github.com/miri2577/TeilhabeAssist';
  static const String licenseUrl =
      'https://www.gnu.org/licenses/agpl-3.0.html';
}
