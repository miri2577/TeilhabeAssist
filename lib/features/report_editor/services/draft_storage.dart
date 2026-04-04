import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/report_draft.dart';
import '../models/report_module.dart';
import '../models/icf_domain.dart';

/// Persistente Speicherung von Berichtsentwürfen.
/// Autosave bei jeder Änderung, Restore bei App-Start.
class DraftStorage {
  static const _boxName = 'report_drafts';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  /// Aktuellen Entwurf speichern
  Future<void> saveDraft(ReportDraft draft) async {
    if (!isInitialized) return;
    await _box!.put('current_draft', _encode(draft));
  }

  /// Aktuellen Entwurf laden (falls vorhanden)
  ReportDraft? loadDraft() {
    if (!isInitialized) return null;
    final json = _box!.get('current_draft');
    if (json == null) return null;
    try {
      return _decode(json);
    } catch (_) {
      return null;
    }
  }

  /// Aktuellen Entwurf löschen
  Future<void> clearDraft() async {
    if (!isInitialized) return;
    await _box!.delete('current_draft');
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  String _encode(ReportDraft draft) {
    return jsonEncode({
      'id': draft.id,
      'type': draft.type.name,
      'createdAt': draft.createdAt.toIso8601String(),
      'previousReport': draft.previousReport,
      'currentNotes': draft.currentNotes,
      'referenceReport': draft.referenceReport,
      'generatedText': draft.generatedText,
      'modules': draft.modules.map((m) => {
        'id': m.id,
        'type': m.type.name,
        'icfDomain': m.icfDomain?.code,
        'title': m.title,
        'notes': m.notes,
        'goalNumber': m.goalNumber,
      }).toList(),
    });
  }

  ReportDraft _decode(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final modules = (data['modules'] as List).map((m) {
      final map = m as Map<String, dynamic>;
      IcfDomain? domain;
      if (map['icfDomain'] != null) {
        domain = IcfDomain.values.firstWhere(
          (d) => d.code == map['icfDomain'],
          orElse: () => IcfDomain.d1,
        );
      }
      return ReportModule(
        id: map['id'] as String,
        type: ModuleType.values.byName(map['type'] as String),
        icfDomain: domain,
        title: map['title'] as String?,
        notes: map['notes'] as String? ?? '',
        goalNumber: map['goalNumber'] as int?,
      );
    }).toList();

    return ReportDraft(
      id: data['id'] as String,
      type: ReportType.values.byName(data['type'] as String),
      createdAt: DateTime.parse(data['createdAt'] as String),
      previousReport: data['previousReport'] as String? ?? '',
      currentNotes: data['currentNotes'] as String? ?? '',
      referenceReport: data['referenceReport'] as String? ?? '',
      modules: modules,
      generatedText: data['generatedText'] as String?,
    );
  }
}
