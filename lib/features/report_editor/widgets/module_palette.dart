import 'package:flutter/material.dart';
import '../models/icf_domain.dart';
import '../models/report_module.dart';

class ModulePalette extends StatelessWidget {
  final void Function(ModuleType type, IcfDomain? domain) onAddModule;

  const ModulePalette({super.key, required this.onAddModule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Module hinzufügen',
                style: theme.textTheme.titleSmall),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _sectionHeader('Teilhabeziele', theme),
                _paletteItem(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'Neues Teilhabeziel',
                  color: Colors.orange,
                  onTap: () => onAddModule(ModuleType.teilhabeziel, null),
                ),
                const SizedBox(height: 16),
                _sectionHeader('ICF-Lebensbereiche', theme),
                for (final domain in IcfDomain.values)
                  _paletteItem(
                    context,
                    icon: domain.icon,
                    label: '${domain.code}: ${domain.label}',
                    color: Colors.purple,
                    onTap: () => onAddModule(ModuleType.icfDomain, domain),
                  ),
                const SizedBox(height: 16),
                _sectionHeader('Weitere', theme),
                _paletteItem(
                  context,
                  icon: Icons.public,
                  label: 'Kontextfaktoren',
                  color: Colors.green,
                  onTap: () =>
                      onAddModule(ModuleType.kontextfaktoren, null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _paletteItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.add_circle_outline, size: 18),
        onTap: onTap,
      ),
    );
  }
}
