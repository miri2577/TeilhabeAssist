import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:teilhabe_assist/app.dart';
import 'package:teilhabe_assist/core/storage/settings_storage.dart';
import 'package:teilhabe_assist/features/api/providers/api_providers.dart';
import 'package:teilhabe_assist/features/pseudonymization/engine/learned_names_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Gespeicherte Einstellungen laden
  final settingsStorage = SettingsStorage();
  await settingsStorage.init();

  // Gelernte Namen laden
  final learnedNames = LearnedNamesStore();
  await learnedNames.init();

  runApp(
    ProviderScope(
      overrides: [
        // API-Keys aus Hive laden
        apiKeyProvider.overrideWith(
          (ref) => settingsStorage.anthropicApiKey ?? '',
        ),
        openaiApiKeyProvider.overrideWith(
          (ref) => settingsStorage.openaiApiKey ?? '',
        ),
        // Provider aus Hive laden
        if (settingsStorage.selectedProvider != null)
          selectedProviderProvider.overrideWith(
            (ref) => LLMProvider.values.byName(
              settingsStorage.selectedProvider!,
            ),
          ),
      ],
      child: const TeilhabeAssistApp(),
    ),
  );
}
