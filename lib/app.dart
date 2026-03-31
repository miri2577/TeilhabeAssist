import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teilhabe_assist/core/routing/app_router.dart';
import 'package:teilhabe_assist/core/theme/app_settings_provider.dart';
import 'package:teilhabe_assist/core/theme/app_theme.dart';

class TeilhabeAssistApp extends ConsumerWidget {
  const TeilhabeAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(settings.textScaleFactor),
      ),
      child: MaterialApp.router(
        title: 'TeilhabeAssist',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
