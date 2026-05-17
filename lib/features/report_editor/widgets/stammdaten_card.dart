import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_draft.dart';
import '../providers/report_providers.dart';

/// Karte mit strukturierten Stammdaten-Feldern für Kopfdaten oder Persondaten.
///
/// Wird im Editor anstelle des `TextField`-Notes eingesetzt für die Module
/// `kopfdaten` und `persondaten`. Werte werden direkt in `draft.stammdaten`
/// gespeichert (nicht mehr in `module.notes`).
class StammdatenCard extends ConsumerStatefulWidget {
  const StammdatenCard({
    super.key,
    required this.title,
    required this.icon,
    required this.fields,
    required this.color,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<StammdatenField> fields;
  final Color color;
  final bool initiallyExpanded;

  @override
  ConsumerState<StammdatenCard> createState() => _StammdatenCardState();
}

class _StammdatenCardState extends ConsumerState<StammdatenCard> {
  late bool _expanded;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, String value) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: value);
    } else if (_controllers[key]!.text != value) {
      // Externe Änderungen (z.B. aus PDF-Import) übernehmen, aber Caret
      // erhalten wenn Wert identisch ist.
      final old = _controllers[key]!.text;
      if (old != value) {
        _controllers[key]!.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
    return _controllers[key]!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(reportDraftNotifierProvider);
    final stamm = draft?.stammdaten ?? const {};
    final notifier = ref.read(reportDraftNotifierProvider.notifier);

    final missingCount = widget.fields
        .where((f) => f.required && (stamm[f.key] ?? '').trim().isEmpty)
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.08),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (missingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$missingCount Pflicht',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'vollständig',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Zwei-Spalten bei breiten Layouts, eine bei schmalen
                  final twoCol = constraints.maxWidth > 520;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final f in widget.fields)
                        SizedBox(
                          width: twoCol
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _buildField(
                              f, stamm[f.key] ?? '', notifier, theme),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(
    StammdatenField field,
    String value,
    ReportDraftNotifier notifier,
    ThemeData theme,
  ) {
    final isMissing = field.required && value.trim().isEmpty;

    final decoration = InputDecoration(
      labelText: field.required ? '${field.label} *' : field.label,
      hintText: field.hint,
      isDense: true,
      border: const OutlineInputBorder(),
      errorText: isMissing ? 'Pflichtfeld' : null,
    );

    switch (field.kind) {
      case StammdatenFieldKind.dropdown:
        final current = field.options.contains(value) ? value : null;
        return DropdownButtonFormField<String>(
          initialValue: current,
          decoration: decoration,
          items: [
            for (final opt in field.options)
              DropdownMenuItem(value: opt, child: Text(opt)),
          ],
          onChanged: (v) =>
              notifier.updateStammdatenField(field.key, v ?? ''),
        );

      case StammdatenFieldKind.autocomplete:
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: value),
          optionsBuilder: (textValue) {
            if (textValue.text.isEmpty) return field.options;
            final lower = textValue.text.toLowerCase();
            return field.options.where(
              (o) => o.toLowerCase().contains(lower),
            );
          },
          onSelected: (selected) =>
              notifier.updateStammdatenField(field.key, selected),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            // Externe Updates spiegeln
            if (controller.text != value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (controller.text != value) {
                  controller.value = TextEditingValue(
                    text: value,
                    selection:
                        TextSelection.collapsed(offset: value.length),
                  );
                }
              });
            }
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: decoration.copyWith(
                suffixIcon: const Icon(Icons.arrow_drop_down, size: 22),
              ),
              onChanged: (v) =>
                  notifier.updateStammdatenField(field.key, v),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, maxWidth: 400),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final opt in options)
                        InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Text(opt),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

      case StammdatenFieldKind.date:
        return TextFormField(
          controller: _controllerFor(field.key, value),
          decoration: decoration.copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today, size: 18),
              onPressed: () => _pickDate(field.key, value, notifier),
            ),
            hintText: 'TT.MM.JJJJ',
          ),
          keyboardType: TextInputType.datetime,
          onChanged: (v) => notifier.updateStammdatenField(field.key, v),
        );

      case StammdatenFieldKind.email:
        return TextFormField(
          controller: _controllerFor(field.key, value),
          decoration: decoration,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => notifier.updateStammdatenField(field.key, v),
        );

      case StammdatenFieldKind.phone:
        return TextFormField(
          controller: _controllerFor(field.key, value),
          decoration: decoration,
          keyboardType: TextInputType.phone,
          onChanged: (v) => notifier.updateStammdatenField(field.key, v),
        );

      case StammdatenFieldKind.multiline:
        return TextFormField(
          controller: _controllerFor(field.key, value),
          decoration: decoration,
          maxLines: 3,
          onChanged: (v) => notifier.updateStammdatenField(field.key, v),
        );

      case StammdatenFieldKind.text:
        return TextFormField(
          controller: _controllerFor(field.key, value),
          decoration: decoration,
          onChanged: (v) => notifier.updateStammdatenField(field.key, v),
        );
    }
  }

  Future<void> _pickDate(
    String key,
    String current,
    ReportDraftNotifier notifier,
  ) async {
    DateTime initial = DateTime.now();
    final parsed = _parseDate(current);
    if (parsed != null) initial = parsed;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('de'),
    );
    if (picked == null || !mounted) return;
    final s = '${picked.day.toString().padLeft(2, '0')}.'
        '${picked.month.toString().padLeft(2, '0')}.'
        '${picked.year}';
    _controllers[key]?.text = s;
    notifier.updateStammdatenField(key, s);
  }

  DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$').firstMatch(s.trim());
    if (m == null) return null;
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
}
