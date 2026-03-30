import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:teilhabe_assist/features/export/pdf_export_screen.dart';
import 'package:teilhabe_assist/features/onboarding/onboarding_screen.dart';
import 'package:teilhabe_assist/features/pseudonymization/ui/pseudonym_preview_screen.dart';
import 'package:teilhabe_assist/features/report_editor/generate_screen.dart';
import 'package:teilhabe_assist/features/report_editor/report_editor_screen.dart';
import 'package:teilhabe_assist/features/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    if (state.matchedLocation == '/onboarding') return null;
    final box = await Hive.openBox<bool>('app_flags');
    final completed = box.get('onboarding_completed', defaultValue: false)!;
    if (!completed) return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const _HomeScreen(),
    ),
    GoRoute(
      path: '/editor',
      builder: (context, state) => const ReportEditorScreen(),
    ),
    GoRoute(
      path: '/generate',
      builder: (context, state) => const GenerateScreen(),
    ),
    GoRoute(
      path: '/export',
      builder: (context, state) => const PdfExportScreen(),
    ),
    GoRoute(
      path: '/pseudonymize',
      builder: (context, state) => const PseudonymPreviewScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeilhabeAssist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Pseudonymisierung testen',
            onPressed: () => context.go('/pseudonymize'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'TeilhabeAssist',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'KI-gestützte Berichterstellung\nfür Eingliederungshilfe Berlin',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: () => context.go('/editor'),
                  icon: const Icon(Icons.add),
                  label: const Text('Neuen Bericht erstellen'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('API-Key einrichten'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
