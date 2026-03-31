import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import '../../report_editor/models/report_draft.dart';
import '../adapters/llm_adapter.dart';
import '../models/report_request.dart';

/// Offline-Queue: Speichert API-Aufrufe wenn kein Netzwerk verfügbar ist.
/// Bei Netzwerk-Rückkehr werden ausstehende Aufrufe automatisch gesendet.
class OfflineQueue {
  static const _boxName = 'offline_queue';
  Box<String>? _box;
  Timer? _retryTimer;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  int get pendingCount => _box?.length ?? 0;

  /// Prüft ob Netzwerk verfügbar ist
  static Future<bool> hasNetwork() async {
    try {
      final result = await InternetAddress.lookup('api.anthropic.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Fügt einen Aufruf zur Queue hinzu
  Future<void> enqueue(ReportRequest request) async {
    if (!isInitialized) return;
    final data = jsonEncode({
      'model': request.model,
      'reportType': request.reportType.name,
      'pseudonymizedNotes': request.pseudonymizedNotes,
      'pseudonymizedPreviousReport': request.pseudonymizedPreviousReport,
      'temperature': request.temperature,
      'enqueuedAt': DateTime.now().toIso8601String(),
    });
    await _box!.add(data);
  }

  /// Verarbeitet alle ausstehenden Aufrufe
  Future<List<ReportResponse>> processQueue(
    LLMAdapter adapter,
    String apiKey,
  ) async {
    if (!isInitialized || _box!.isEmpty) return [];

    final responses = <ReportResponse>[];
    final keys = _box!.keys.toList();

    for (final key in keys) {
      final json = _box!.get(key);
      if (json == null) continue;

      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final request = ReportRequest(
          apiKey: apiKey,
          model: data['model'] as String,
          reportType: ReportType.values.byName(data['reportType'] as String),
          pseudonymizedNotes: data['pseudonymizedNotes'] as String,
          pseudonymizedPreviousReport:
              data['pseudonymizedPreviousReport'] as String?,
          temperature: (data['temperature'] as num).toDouble(),
        );

        final response = await adapter.generateReport(request);
        responses.add(response);
        await _box!.delete(key);
      } catch (_) {
        break; // Bei Fehler: In Queue lassen für nächsten Versuch
      }
    }

    return responses;
  }

  /// Startet automatisches Retry (alle 60 Sekunden prüfen)
  void startAutoRetry(LLMAdapter adapter, String apiKey,
      {void Function(ReportResponse)? onProcessed}) {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (pendingCount == 0) return;
      if (!await hasNetwork()) return;

      final responses = await processQueue(adapter, apiKey);
      for (final r in responses) {
        onProcessed?.call(r);
      }
    });
  }

  void stopAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> clearQueue() async {
    if (!isInitialized) return;
    await _box!.clear();
  }

  Future<void> close() async {
    stopAutoRetry();
    await _box?.close();
    _box = null;
  }
}
