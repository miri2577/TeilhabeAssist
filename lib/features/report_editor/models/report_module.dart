import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'icf_domain.dart';

const _uuid = Uuid();

enum ModuleType {
  // Module des Informationsberichts (Berlin v1.01).
  kopfdaten('Kopfdaten', Icons.badge_outlined, true),
  persondaten('Persondaten', Icons.person_outline, true),
  allgemeineInfos('Allgemeine Informationen', Icons.info_outline, true),
  teilhabeziel('Teilhabeziel', Icons.flag_outlined, false),
  icfDomain('ICF-Lebensbereich', Icons.category_outlined, false),
  flsUebersicht('FLS-Übersicht', Icons.access_time, true),
  kontextfaktoren('Kontextfaktoren', Icons.public, false),
  zusammenfassung('Zusammenfassung & Empfehlung', Icons.summarize_outlined, true);

  const ModuleType(this.label, this.icon, this.required);
  final String label;
  final IconData icon;
  final bool required;
}

class ReportModule {
  final String id;
  final ModuleType type;
  final IcfDomain? icfDomain;
  final String title;
  String notes;
  int? goalNumber;

  ReportModule({
    String? id,
    required this.type,
    this.icfDomain,
    String? title,
    this.notes = '',
    this.goalNumber,
  })  : id = id ?? _uuid.v4(),
        title = title ?? _defaultTitle(type, icfDomain, goalNumber);

  static String _defaultTitle(ModuleType type, IcfDomain? domain, int? goal) {
    if (type == ModuleType.icfDomain && domain != null) {
      return '${domain.code}: ${domain.label}';
    }
    if (type == ModuleType.teilhabeziel && goal != null) {
      return 'Teilhabeziel $goal';
    }
    return type.label;
  }

  ReportModule copyWith({String? notes, int? goalNumber}) {
    return ReportModule(
      id: id,
      type: type,
      icfDomain: icfDomain,
      title: title,
      notes: notes ?? this.notes,
      goalNumber: goalNumber ?? this.goalNumber,
    );
  }
}
