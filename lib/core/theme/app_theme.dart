import 'package:flutter/material.dart';

class AppTheme {
  /// FEGH-Suite-Markenfarbe (Petrol) — identisch zur Webapp
  /// FEGH-Leistungsnachweis (`--brand: #0e7490`), einheitliche Optik der Suite.
  static const _seedColor = Color(0xFF0E7490);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seedColor,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seedColor,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      );
}
