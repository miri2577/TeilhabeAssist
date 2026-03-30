import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:teilhabe_assist/app.dart';

void main() {
  setUpAll(() async {
    // Hive im Testmodus initialisieren
    Hive.init('/tmp/hive_test_${DateTime.now().millisecondsSinceEpoch}');
    final box = await Hive.openBox<bool>('app_flags');
    await box.put('onboarding_completed', true);
  });

  testWidgets('App startet und zeigt Titel', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TeilhabeAssistApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('TeilhabeAssist'), findsWidgets);
  });
}
