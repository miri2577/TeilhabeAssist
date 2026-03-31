import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class AppSettings {
  final ThemeMode themeMode;
  final double textScaleFactor;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScaleFactor = 1.0,
  });

  AppSettings copyWith({ThemeMode? themeMode, double? textScaleFactor}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  Box<String>? _box;

  AppSettingsNotifier() : super(const AppSettings());

  Future<void> init() async {
    _box = await Hive.openBox<String>('app_display_settings');
    final mode = _box?.get('themeMode');
    final scale = _box?.get('textScaleFactor');
    state = AppSettings(
      themeMode: mode != null
          ? ThemeMode.values.byName(mode)
          : ThemeMode.system,
      textScaleFactor: scale != null ? double.parse(scale) : 1.0,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _box?.put('themeMode', mode.name);
  }

  void setTextScaleFactor(double factor) {
    state = state.copyWith(textScaleFactor: factor);
    _box?.put('textScaleFactor', factor.toString());
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
