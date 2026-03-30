import 'package:flutter/material.dart';

enum IcfDomain {
  d1('d1', 'Lernen und Wissensanwendung', Icons.psychology),
  d2('d2', 'Allgemeine Aufgaben und Anforderungen', Icons.task_alt),
  d3('d3', 'Kommunikation', Icons.chat_bubble_outline),
  d4('d4', 'Mobilität', Icons.directions_walk),
  d5('d5', 'Selbstversorgung', Icons.restaurant),
  d6('d6', 'Häusliches Leben', Icons.home),
  d7('d7', 'Interpersonelle Interaktionen', Icons.people_outline),
  d8('d8', 'Bedeutende Lebensbereiche', Icons.work_outline),
  d9('d9', 'Gemeinschafts-, soziales und staatsbürgerliches Leben', Icons.groups);

  const IcfDomain(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;
}
