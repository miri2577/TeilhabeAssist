import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.description_outlined,
      title: 'Willkommen bei FEGH-Bericht',
      description: 'KI-gestützte Berichterstellung für die '
          'Eingliederungshilfe Berlin.\n\n'
          'Erstelle Informationsberichte (Berlin v1.01) in einem '
          'Bruchteil der bisherigen Zeit.',
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'Datenschutz zuerst',
      description: 'Personenbezogene Daten verlassen niemals dein Gerät.\n\n'
          'Die Pseudonymisierungs-Engine erkennt automatisch Namen, '
          'Adressen, Telefonnummern und ersetzt sie durch Platzhalter. '
          'Du prüfst den Text vor jedem API-Aufruf.',
    ),
    _OnboardingPage(
      icon: Icons.drag_indicator,
      title: 'Drag & Drop Baukasten',
      description: 'Stelle deinen Bericht aus Modulkarten zusammen:\n\n'
          '• ICF-Lebensbereiche (d1–d9)\n'
          '• Teilhabeziele\n'
          '• FLS-Übersicht\n'
          '• Kontextfaktoren\n\n'
          'Gib Stichpunkte pro Modul ein – die KI formuliert den Fließtext.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'KI-Generierung',
      description: 'Der pseudonymisierte Text wird an die API gesendet.\n\n'
          'Die KI generiert einen ICF-konformen Bericht nach der Struktur '
          'des Informationsberichts v1.01.\n\n'
          'Nach der Generierung werden die Platzhalter automatisch '
          'durch die Originaldaten ersetzt.',
    ),
    _OnboardingPage(
      icon: Icons.vpn_key,
      title: 'API-Key einrichten',
      description: 'Du brauchst einen API-Key von Anthropic oder OpenAI.\n\n'
          'Gehe nach dem Onboarding in die Einstellungen und hinterlege '
          'deinen Key. Die Kosten pro Bericht liegen bei ca. 0,08 €.',
    ),
  ];

  void _complete() async {
    final box = await Hive.openBox<bool>('app_flags');
    await box.put('onboarding_completed', true);
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              page.icon,
                              size: 80,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              page.title,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dots + Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _complete,
                        child: const Text('Überspringen'),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentPage
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                      _currentPage == _pages.length - 1
                          ? FilledButton(
                              onPressed: _complete,
                              child: const Text('Fertig'),
                            )
                          : FilledButton.tonal(
                              onPressed: () => _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: const Text('Weiter'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
