import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_draft.dart';
import '../models/report_module.dart';
import '../models/report_template.dart';
import '../models/icf_domain.dart';
import '../services/draft_storage.dart';

final draftStorageProvider = Provider<DraftStorage>((ref) => DraftStorage());

final currentDraftProvider = StateProvider<ReportDraft?>((ref) => null);

final isGeneratingProvider = StateProvider<bool>((ref) => false);

final streamedTextProvider = StateProvider<String>((ref) => '');

class ReportDraftNotifier extends StateNotifier<ReportDraft?> {
  final DraftStorage? _storage;

  ReportDraftNotifier([this._storage]) : super(null) {
    addListener(_onStateChanged);
  }

  void _onStateChanged(ReportDraft? draft) {
    if (draft != null) {
      _storage?.saveDraft(draft);
    }
  }

  void restoreFromStorage() {
    final saved = _storage?.loadDraft();
    if (saved != null) state = saved;
  }

  void clearDraft() {
    state = null;
    _storage?.clearDraft();
  }

  void createNew(ReportType type) {
    state = ReportDraft(type: type);
  }

  void loadFromTemplate(ReportTemplate template) {
    state = template.toDraft();
  }

  void updatePreviousReport(String text) {
    state = state?.copyWith(previousReport: text);
  }

  void updateReferenceReport(String text) {
    state = state?.copyWith(referenceReport: text);
  }

  void updateCurrentNotes(String notes) {
    state = state?.copyWith(currentNotes: notes);
  }

  void updateModuleNotes(String moduleId, String notes) {
    if (state == null) return;
    final modules = state!.modules.map((m) {
      if (m.id == moduleId) return m.copyWith(notes: notes);
      return m;
    }).toList();
    state = state!.copyWith(modules: modules);
  }

  void reorderModules(int oldIndex, int newIndex) {
    if (state == null) return;
    final modules = List<ReportModule>.from(state!.modules);
    if (newIndex > oldIndex) newIndex--;
    final item = modules.removeAt(oldIndex);
    modules.insert(newIndex, item);
    state = state!.copyWith(modules: modules);
  }

  void addModule(ReportModule module) {
    if (state == null) return;
    state = state!.copyWith(modules: [...state!.modules, module]);
  }

  void removeModule(String moduleId) {
    if (state == null) return;
    final module = state!.modules.firstWhere((m) => m.id == moduleId);
    if (module.type.required) return; // Pflichtmodule nicht entfernbar
    state = state!.copyWith(
      modules: state!.modules.where((m) => m.id != moduleId).toList(),
    );
  }

  void addGoal() {
    if (state == null) return;
    final goalCount =
        state!.modules.where((m) => m.type == ModuleType.teilhabeziel).length;
    addModule(ReportModule(
      type: ModuleType.teilhabeziel,
      goalNumber: goalCount + 1,
    ));
  }

  void addIcfDomain(IcfDomain domain) {
    addModule(ReportModule(
      type: ModuleType.icfDomain,
      icfDomain: domain,
    ));
  }

  void setGeneratedText(String text) {
    state = state?.copyWith(generatedText: text);
  }

  /// Speichert einen generierten Text für eine bestimmte Schema-Variante.
  /// Setzt zusätzlich `generatedText` für Rückwärtskompatibilität auf den
  /// Text der aktuell ausgewählten Variante.
  void setGeneratedTextForSchema(ReportSchema schema, String text) {
    if (state == null) return;
    final updated = Map<ReportSchema, String>.from(state!.generatedTexts);
    updated[schema] = text;
    state = state!.copyWith(
      generatedText: updated[state!.selectedSchema] ?? state!.generatedText,
      generatedTexts: updated,
    );
  }

  /// Speichert die strukturierte Map für eine Schema-Variante.
  void setStructuredReportForSchema(
    ReportSchema schema,
    Map<String, dynamic> data,
  ) {
    if (state == null) return;
    final updated =
        Map<ReportSchema, Map<String, dynamic>>.from(state!.structuredReports);
    updated[schema] = data;
    state = state!.copyWith(structuredReports: updated);
  }

  /// Setzt einen einzelnen Stammdaten-Wert.
  void updateStammdatenField(String key, String value) {
    if (state == null) return;
    final updated = Map<String, String>.from(state!.stammdaten);
    if (value.trim().isEmpty) {
      updated.remove(key);
    } else {
      updated[key] = value;
    }
    state = state!.copyWith(stammdaten: updated);
  }

  /// Mergt importierte Stammdaten (z.B. aus PDF-Import) in den Draft —
  /// **ohne** bestehende Werte zu überschreiben.
  int mergeStammdaten(Map<String, String> incoming) {
    if (state == null || incoming.isEmpty) return 0;
    final updated = Map<String, String>.from(state!.stammdaten);
    var applied = 0;
    incoming.forEach((k, v) {
      final t = v.trim();
      if (t.isEmpty) return;
      if ((updated[k] ?? '').trim().isEmpty) {
        updated[k] = t;
        applied++;
      }
    });
    if (applied == 0) return 0;
    state = state!.copyWith(stammdaten: updated);
    return applied;
  }

  void selectSchema(ReportSchema schema) {
    if (state == null) return;
    state = state!.copyWith(
      selectedSchema: schema,
      generatedText: state!.generatedTexts[schema] ?? state!.generatedText,
    );
  }
}

final reportDraftNotifierProvider =
    StateNotifierProvider<ReportDraftNotifier, ReportDraft?>((ref) {
  final storage = ref.watch(draftStorageProvider);
  return ReportDraftNotifier(storage);
});
