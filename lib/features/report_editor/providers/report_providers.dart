import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_draft.dart';
import '../models/report_module.dart';
import '../models/icf_domain.dart';

final currentDraftProvider = StateProvider<ReportDraft?>((ref) => null);

final isGeneratingProvider = StateProvider<bool>((ref) => false);

final streamedTextProvider = StateProvider<String>((ref) => '');

class ReportDraftNotifier extends StateNotifier<ReportDraft?> {
  ReportDraftNotifier() : super(null);

  void createNew(ReportType type) {
    state = ReportDraft(type: type);
  }

  void updatePreviousReport(String text) {
    if (state == null) return;
    state!.previousReport = text;
    state!.updatedAt = DateTime.now();
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: text,
      modules: state!.modules,
      generatedText: state!.generatedText,
      pseudonymizedText: state!.pseudonymizedText,
    );
  }

  void updateModuleNotes(String moduleId, String notes) {
    if (state == null) return;
    final modules = state!.modules.map((m) {
      if (m.id == moduleId) return m.copyWith(notes: notes);
      return m;
    }).toList();
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: state!.previousReport,
      modules: modules,
      generatedText: state!.generatedText,
      pseudonymizedText: state!.pseudonymizedText,
    );
  }

  void reorderModules(int oldIndex, int newIndex) {
    if (state == null) return;
    final modules = List<ReportModule>.from(state!.modules);
    if (newIndex > oldIndex) newIndex--;
    final item = modules.removeAt(oldIndex);
    modules.insert(newIndex, item);
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: state!.previousReport,
      modules: modules,
      generatedText: state!.generatedText,
      pseudonymizedText: state!.pseudonymizedText,
    );
  }

  void addModule(ReportModule module) {
    if (state == null) return;
    final modules = [...state!.modules, module];
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: state!.previousReport,
      modules: modules,
      generatedText: state!.generatedText,
      pseudonymizedText: state!.pseudonymizedText,
    );
  }

  void removeModule(String moduleId) {
    if (state == null) return;
    final module = state!.modules.firstWhere((m) => m.id == moduleId);
    if (module.type.required) return; // Pflichtmodule nicht entfernbar
    final modules = state!.modules.where((m) => m.id != moduleId).toList();
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: state!.previousReport,
      modules: modules,
      generatedText: state!.generatedText,
      pseudonymizedText: state!.pseudonymizedText,
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
    if (state == null) return;
    state = ReportDraft(
      id: state!.id,
      type: state!.type,
      createdAt: state!.createdAt,
      previousReport: state!.previousReport,
      modules: state!.modules,
      generatedText: text,
      pseudonymizedText: state!.pseudonymizedText,
    );
  }
}

final reportDraftNotifierProvider =
    StateNotifierProvider<ReportDraftNotifier, ReportDraft?>((ref) {
  return ReportDraftNotifier();
});
