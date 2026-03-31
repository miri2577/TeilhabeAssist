import 'dart:convert';
import 'icf_domain.dart';
import 'report_draft.dart';
import 'report_module.dart';

class ReportTemplate {
  final String id;
  final String name;
  final ReportType reportType;
  final DateTime createdAt;
  final List<TemplateModule> modules;

  const ReportTemplate({
    required this.id,
    required this.name,
    required this.reportType,
    required this.createdAt,
    required this.modules,
  });

  /// Erstellt einen neuen Draft aus diesem Template
  ReportDraft toDraft() {
    final modules = this.modules.map((tm) {
      IcfDomain? domain;
      if (tm.icfDomainCode != null) {
        domain = IcfDomain.values.firstWhere(
          (d) => d.code == tm.icfDomainCode,
          orElse: () => IcfDomain.d1,
        );
      }
      return ReportModule(
        type: tm.type,
        icfDomain: domain,
        notes: tm.defaultNotes,
        goalNumber: tm.goalNumber,
      );
    }).toList();

    return ReportDraft(
      type: reportType,
      modules: modules,
    );
  }

  /// Erstellt ein Template aus einem existierenden Draft
  factory ReportTemplate.fromDraft(ReportDraft draft, String name) {
    return ReportTemplate(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      reportType: draft.type,
      createdAt: DateTime.now(),
      modules: draft.modules
          .map((m) => TemplateModule(
                type: m.type,
                icfDomainCode: m.icfDomain?.code,
                defaultNotes: m.notes,
                goalNumber: m.goalNumber,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reportType': reportType.name,
        'createdAt': createdAt.toIso8601String(),
        'modules': modules.map((m) => m.toJson()).toList(),
      };

  factory ReportTemplate.fromJson(Map<String, dynamic> json) {
    return ReportTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      reportType: ReportType.values.byName(json['reportType'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      modules: (json['modules'] as List)
          .map((m) => TemplateModule.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory ReportTemplate.fromJsonString(String s) =>
      ReportTemplate.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class TemplateModule {
  final ModuleType type;
  final String? icfDomainCode;
  final String defaultNotes;
  final int? goalNumber;

  const TemplateModule({
    required this.type,
    this.icfDomainCode,
    this.defaultNotes = '',
    this.goalNumber,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'icfDomainCode': icfDomainCode,
        'defaultNotes': defaultNotes,
        'goalNumber': goalNumber,
      };

  factory TemplateModule.fromJson(Map<String, dynamic> json) {
    return TemplateModule(
      type: ModuleType.values.byName(json['type'] as String),
      icfDomainCode: json['icfDomainCode'] as String?,
      defaultNotes: json['defaultNotes'] as String? ?? '',
      goalNumber: json['goalNumber'] as int?,
    );
  }
}
