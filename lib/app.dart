import 'package:flutter/material.dart';
import 'package:teilhabe_assist/core/routing/app_router.dart';
import 'package:teilhabe_assist/core/theme/app_theme.dart';

class TeilhabeAssistApp extends StatelessWidget {
  const TeilhabeAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TeilhabeAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
