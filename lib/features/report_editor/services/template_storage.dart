import 'package:hive/hive.dart';
import '../models/report_template.dart';

/// Persistente Speicherung von Berichts-Templates in Hive.
class TemplateStorage {
  static const _boxName = 'report_templates';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get isInitialized => _box != null && _box!.isOpen;

  List<ReportTemplate> getAll() {
    if (!isInitialized) return [];
    return _box!.values
        .map((json) => ReportTemplate.fromJsonString(json))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(ReportTemplate template) async {
    if (!isInitialized) return;
    await _box!.put(template.id, template.toJsonString());
  }

  Future<void> delete(String templateId) async {
    if (!isInitialized) return;
    await _box!.delete(templateId);
  }

  ReportTemplate? get(String templateId) {
    if (!isInitialized) return null;
    final json = _box!.get(templateId);
    if (json == null) return null;
    return ReportTemplate.fromJsonString(json);
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
