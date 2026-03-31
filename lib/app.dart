import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teilhabe_assist/core/routing/app_router.dart';
import 'package:teilhabe_assist/core/theme/app_settings_provider.dart';
import 'package:teilhabe_assist/core/theme/app_theme.dart';
import 'package:teilhabe_assist/features/auth/auth_service.dart';
import 'package:teilhabe_assist/features/auth/lock_screen.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

class TeilhabeAssistApp extends ConsumerWidget {
  const TeilhabeAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final authService = ref.watch(authServiceProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(settings.textScaleFactor),
      ),
      child: isAuthenticated
          ? MaterialApp.router(
              title: 'TeilhabeAssist',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.themeMode,
              routerConfig: appRouter,
            )
          : MaterialApp(
              title: 'TeilhabeAssist',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.themeMode,
              home: LockScreen(
                authService: authService,
                onAuthenticated: () {
                  ref.read(isAuthenticatedProvider.notifier).state = true;
                },
              ),
            ),
    );
  }
}
