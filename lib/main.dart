import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:teilhabe_assist/app.dart';
import 'package:teilhabe_assist/core/storage/audit_log.dart';
import 'package:teilhabe_assist/core/storage/settings_storage.dart';
import 'package:teilhabe_assist/core/theme/app_settings_provider.dart';
import 'package:teilhabe_assist/features/api/providers/api_providers.dart';
import 'package:teilhabe_assist/features/auth/auth_service.dart';
import 'package:teilhabe_assist/features/privacy/signature_store.dart';
import 'package:teilhabe_assist/features/privacy/privacy_signature_screen.dart';
import 'package:teilhabe_assist/features/pseudonymization/engine/user_dictionary.dart';
import 'package:teilhabe_assist/features/pseudonymization/providers/pseudonym_providers.dart';
import 'package:teilhabe_assist/features/report_editor/providers/report_providers.dart';
import 'package:teilhabe_assist/features/report_editor/services/draft_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final settingsStorage = SettingsStorage();
  await settingsStorage.init();

  final userDictionary = UserDictionary();
  await userDictionary.init();

  final signatureStore = SignatureStore();
  await signatureStore.init();

  final authService = AuthService();
  await authService.init();

  final draftStorage = DraftStorage();
  await draftStorage.init();

  final auditLog = AuditLog();
  await auditLog.init();

  final appSettingsNotifier = AppSettingsNotifier();
  await appSettingsNotifier.init();

  runApp(
    ProviderScope(
      overrides: [
        apiKeyProvider.overrideWith(
          (ref) => settingsStorage.anthropicApiKey ?? '',
        ),
        openaiApiKeyProvider.overrideWith(
          (ref) => settingsStorage.openaiApiKey ?? '',
        ),
        if (settingsStorage.selectedProvider != null)
          selectedProviderProvider.overrideWith(
            (ref) => LLMProvider.values.byName(
              settingsStorage.selectedProvider!,
            ),
          ),
        userDictionaryProvider.overrideWithValue(userDictionary),
        draftStorageProvider.overrideWithValue(draftStorage),
        auditLogProvider.overrideWithValue(auditLog),
        authServiceProvider.overrideWithValue(authService),
        signatureStoreProvider.overrideWithValue(signatureStore),
        appSettingsProvider.overrideWith((ref) => appSettingsNotifier),
      ],
      child: const TeilhabeAssistApp(),
    ),
  );
}
