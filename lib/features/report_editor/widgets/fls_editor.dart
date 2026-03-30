import 'package:flutter/material.dart';
import '../models/fls_data.dart';

class FlsEditor extends StatefulWidget {
  final FlsData data;
  final ValueChanged<FlsData> onChanged;

  const FlsEditor({super.key, required this.data, required this.onChanged});

  @override
  State<FlsEditor> createState() => _FlsEditorState();
}

class _FlsEditorState extends State<FlsEditor> {
  late FlsData _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  void _update(void Function() mutate) {
    setState(mutate);
    widget.onChanged(_data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bewilligte FLS
        Text('Bewilligte FLS', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numberField(
                label: 'Gesamt/Woche',
                value: _data.bewilligtProWoche,
                onChanged: (v) =>
                    _update(() => _data.bewilligtProWoche = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                label: 'Qualifiziert/Woche',
                value: _data.qualifiziertProWoche,
                onChanged: (v) =>
                    _update(() => _data.qualifiziertProWoche = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                label: 'Einfach/Woche',
                value: _data.einfachProWoche,
                onChanged: (v) =>
                    _update(() => _data.einfachProWoche = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _numberField(
          label: 'Berichtszeitraum (Wochen)',
          value: _data.berichtszeitraumWochen.toDouble(),
          onChanged: (v) =>
              _update(() => _data.berichtszeitraumWochen = v.round()),
        ),
        const Divider(height: 32),

        // Erbrachte FLS
        Text('Erbrachte FLS', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numberField(
                label: 'Gesamt erbracht',
                value: _data.erbracht,
                onChanged: (v) => _update(() => _data.erbracht = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                label: 'Qualifiziert',
                value: _data.erbrachtQualifiziert,
                onChanged: (v) =>
                    _update(() => _data.erbrachtQualifiziert = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _numberField(
                label: 'Einfach',
                value: _data.erbrachtEinfach,
                onChanged: (v) =>
                    _update(() => _data.erbrachtEinfach = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _numberField(
          label: 'Ausfallstunden',
          value: _data.ausfallstunden,
          onChanged: (v) => _update(() => _data.ausfallstunden = v),
        ),
        const Divider(height: 32),

        // Auswertung
        Text('Auswertung', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        _buildStats(theme),

        // Abweichungs-Warnung
        if (_data.hatAbweichung) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Abweichung > 10% – Begründung erforderlich',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Begründung für die Abweichung...',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(
                    text: _data.abweichungsBegruendung,
                  ),
                  onChanged: (v) =>
                      _update(() => _data.abweichungsBegruendung = v),
                ),
              ],
            ),
          ),
        ],

        if (_data.fachkraftquoteUnter75 && _data.erbracht > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fachkraftquote (${_data.fachkraftquote.toStringAsFixed(1)}%) '
                    'liegt unter der Berliner Orientierungsgröße von 75%.',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStats(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _statChip(
          'Bewilligt gesamt',
          '${_data.bewilligtGesamt.toStringAsFixed(1)} Std.',
          Colors.blue,
        ),
        _statChip(
          'Auslastung',
          '${_data.auslastung.toStringAsFixed(1)}%',
          _data.hatAbweichung ? Colors.orange : Colors.green,
        ),
        _statChip(
          'Fachkraftquote',
          '${_data.fachkraftquote.toStringAsFixed(1)}%',
          _data.fachkraftquoteUnter75 ? Colors.red : Colors.green,
        ),
        _statChip(
          'Indirekte (5:1)',
          '${_data.indirekteAssistenz.toStringAsFixed(1)} Std.',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(Icons.analytics, color: color, size: 16),
      ),
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.05),
    );
  }

  Widget _numberField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      controller: TextEditingController(
        text: value > 0 ? value.toString() : '',
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}
