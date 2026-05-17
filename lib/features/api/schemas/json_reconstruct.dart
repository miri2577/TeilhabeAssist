/// Rekursiver Reconstruct für strukturierte JSON-Berichte.
/// Ersetzt Pseudonym-Platzhalter (z.B. `[PERSON_001]`) in allen
/// String-Werten der Map — egal wie tief geschachtelt.
typedef ReconstructFn = String Function(String input);

Map<String, dynamic> reconstructMap(
  Map<String, dynamic> input,
  ReconstructFn reconstruct,
) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    out[key] = _reconstructValue(value, reconstruct);
  });
  return out;
}

dynamic _reconstructValue(dynamic value, ReconstructFn reconstruct) {
  if (value is String) return reconstruct(value);
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k.toString()] = _reconstructValue(v, reconstruct);
    });
    return out;
  }
  if (value is List) {
    return value.map((e) => _reconstructValue(e, reconstruct)).toList();
  }
  return value;
}

/// Sammelt alle übrig gebliebenen Platzhalter im JSON (für die
/// Validierung nach dem Reconstruct).
List<String> findRemainingPlaceholders(dynamic value) {
  final result = <String>[];
  _collect(value, result);
  return result;
}

void _collect(dynamic value, List<String> acc) {
  if (value is String) {
    final pattern = RegExp(r'\[[A-Z]+_\d{3}\]');
    for (final m in pattern.allMatches(value)) {
      acc.add(m.group(0)!);
    }
  } else if (value is Map) {
    for (final v in value.values) {
      _collect(v, acc);
    }
  } else if (value is List) {
    for (final v in value) {
      _collect(v, acc);
    }
  }
}
