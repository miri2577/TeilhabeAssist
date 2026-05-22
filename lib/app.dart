import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teilhabe_assist/core/routing/app_router.dart';
import 'package:teilhabe_assist/core/theme/app_settings_provider.dart';
import 'package:teilhabe_assist/core/theme/app_theme.dart';
import 'package:teilhabe_assist/features/auth/auth_service.dart';
import 'package:teilhabe_assist/features/auth/lock_screen.dart';
import 'package:teilhabe_assist/features/privacy/privacy_policy_text.dart';
import 'package:teilhabe_assist/features/privacy/privacy_signature_screen.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Drei Stufen: locked → needsSignature → ready
enum AppGateState { locked, needsSignature, ready }

final appGateProvider = StateProvider<AppGateState>((ref) => AppGateState.locked);

class TeilhabeAssistApp extends ConsumerWidget {
  const TeilhabeAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final gate = ref.watch(appGateProvider);
    final authService = ref.watch(authServiceProvider);
    final signatureStore = ref.watch(signatureStoreProvider);

    Widget home;

    switch (gate) {
      case AppGateState.locked:
        home = LockScreen(
          authService: authService,
          onAuthenticated: () {
            // Nach Passwort: Prüfe ob Datenschutz unterschrieben
            if (signatureStore.isSignatureValid(kPrivacyPolicyText)) {
              ref.read(appGateProvider.notifier).state = AppGateState.ready;
            } else {
              ref.read(appGateProvider.notifier).state = AppGateState.needsSignature;
            }
          },
        );

      case AppGateState.needsSignature:
        // Datenschutzerklärung muss unterschrieben werden
        home = _PrivacyGateScreen(
          onSigned: () {
            ref.read(appGateProvider.notifier).state = AppGateState.ready;
          },
        );

      case AppGateState.ready:
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.textScaleFactor),
          ),
          child: MaterialApp.router(
            title: 'FEGH-Bericht',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            routerConfig: appRouter,
          ),
        );
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(settings.textScaleFactor),
      ),
      child: MaterialApp(
        title: 'FEGH-Bericht',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: home,
      ),
    );
  }
}

/// Wrapper-Screen der die PrivacySignatureScreen inline zeigt
/// (ohne go_router, da die App noch nicht freigeschaltet ist)
class _PrivacyGateScreen extends ConsumerStatefulWidget {
  final VoidCallback onSigned;
  const _PrivacyGateScreen({required this.onSigned});

  @override
  ConsumerState<_PrivacyGateScreen> createState() => _PrivacyGateScreenState();
}

class _PrivacyGateScreenState extends ConsumerState<_PrivacyGateScreen> {
  final _nameController = TextEditingController();
  bool _hasReadPolicy = false;
  bool _saving = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _hasReadPolicy && _nameController.text.trim().length >= 3;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);

    try {
      final store = ref.read(signatureStoreProvider);
      await store.saveConfirmation(
        fullName: _nameController.text.trim(),
        policyText: kPrivacyPolicyText,
      );
      widget.onSigned();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenschutzerklärung'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vor der Nutzung der App muss die Datenschutzerklärung '
                        'gelesen und bestätigt werden. Dies ist einmalig erforderlich.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      kPrivacyPolicyText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: _hasReadPolicy,
                      onChanged: (v) =>
                          setState(() => _hasReadPolicy = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Ich habe die Datenschutzerklärung vollständig '
                        'gelesen und verstanden.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vollständiger Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _canConfirm && !_saving ? _confirm : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Gelesen und bestätigt'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
