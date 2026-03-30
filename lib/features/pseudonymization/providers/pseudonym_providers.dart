import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/pseudonym_engine.dart';
import '../models/pseudonym_result.dart';

final pseudonymEngineProvider = Provider<PseudonymEngine>((ref) {
  return PseudonymEngine();
});

final inputTextProvider = StateProvider<String>((ref) => '');

final pseudonymResultProvider = StateProvider<PseudonymResult?>((ref) => null);

final isConfirmedProvider = StateProvider<bool>((ref) => false);
