import 'package:flutter/material.dart';
import '../models/fls_data.dart';
import '../models/report_module.dart';
import 'fls_editor.dart';

class ModuleCard extends StatelessWidget {
  final ReportModule module;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback? onRemove;
  final bool expanded;
  final VoidCallback? onToggleExpand;

  const ModuleCard({
    super.key,
    required this.module,
    required this.onNotesChanged,
    this.onRemove,
    this.expanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _moduleColor(module.type, theme);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onToggleExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              child: Row(
                children: [
                  Icon(module.type.icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: color,
                          ),
                        ),
                        if (module.notes.isNotEmpty)
                          Text(
                            '${module.notes.split('\n').length} Stichpunkte',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (module.type.required)
                    Chip(
                      label: const Text('Pflicht'),
                      labelStyle: const TextStyle(fontSize: 11),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: color.withValues(alpha: 0.15),
                    )
                  else if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemove,
                      tooltip: 'Modul entfernen',
                    ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded: Notizen-Editor oder FLS-Editor
          if (expanded && module.type == ModuleType.flsUebersicht)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FlsEditor(
                data: FlsData(),
                onChanged: (data) => onNotesChanged(data.toPromptText()),
              ),
            ),
          if (expanded && module.type != ModuleType.flsUebersicht)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: _hintForModule(module),
                  hintMaxLines: 3,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                ),
                controller: TextEditingController(text: module.notes)
                  ..selection = TextSelection.collapsed(
                    offset: module.notes.length,
                  ),
                onChanged: onNotesChanged,
              ),
            ),
        ],
      ),
    );
  }

  Color _moduleColor(ModuleType type, ThemeData theme) {
    return switch (type) {
      ModuleType.kopfdaten => Colors.blueGrey,
      ModuleType.persondaten => Colors.indigo,
      ModuleType.allgemeineInfos => Colors.teal,
      ModuleType.teilhabeziel => Colors.orange,
      ModuleType.icfDomain => Colors.purple,
      ModuleType.flsUebersicht => Colors.blue,
      ModuleType.kontextfaktoren => Colors.green,
      ModuleType.zusammenfassung => Colors.deepOrange,
    };
  }

  String _hintForModule(ReportModule module) {
    return switch (module.type) {
      ModuleType.kopfdaten =>
        'ID Kostenübernahme, Berichtszeitraum, Leistungstyp, Leistungserbringer...',
      ModuleType.persondaten =>
        'Name, Geburtsdatum, Kontaktdaten, Familienstand...',
      ModuleType.allgemeineInfos =>
        'Ausbildung, Arbeit, Tagesstruktur, bedeutsame Kontakte...',
      ModuleType.teilhabeziel =>
        'Leitziel, Sichtweise der Person, Sichtweise des Leistungserbringers, '
            'Kontextfaktoren, Art der Unterstützung, Zielerreichung...',
      ModuleType.icfDomain =>
        'Aktuelle Situation, Ressourcen, Einschränkungen, '
            'Hilfebedarf in diesem Lebensbereich...',
      ModuleType.flsUebersicht =>
        'Bewilligte FLS, erbrachte FLS, qualifizierte/einfache Assistenz, '
            'Ausfallstunden, Abweichungen...',
      ModuleType.kontextfaktoren =>
        'Förderfaktoren (positiv wirkende Umwelt- und personbezogene Faktoren), '
            'Barrieren (hinderliche Faktoren)...',
      ModuleType.zusammenfassung =>
        'Gesamteinschätzung, Empfehlung für nächsten Leistungszeitraum, '
            'FLS-Anpassung...',
    };
  }
}
