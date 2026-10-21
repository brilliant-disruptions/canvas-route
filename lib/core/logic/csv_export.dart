/// Pure CSV builder shared by every mode. Columns come from the mode's export
/// field list; values are resolved by [CsvRow.value].
class CsvRow {
  const CsvRow(this.values);

  /// field key → display value
  final Map<String, String> values;

  String value(String key) => values[key] ?? '';
}

String escapeCsvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// [meta] becomes the first row (e.g. rep name, company, route name).
/// [headers] maps field key → column header; keys absent map to the raw key.
String buildCsv({
  required List<String> meta,
  required List<String> fields,
  required Map<String, String> headers,
  required List<CsvRow> rows,
}) {
  final lines = <String>[];
  if (meta.isNotEmpty) lines.add(meta.map(escapeCsvField).join(','));
  lines.add(fields.map((f) => escapeCsvField(headers[f] ?? f)).join(','));
  for (final row in rows) {
    lines.add(fields.map((f) => escapeCsvField(row.value(f))).join(','));
  }
  return lines.join('\n');
}

String csvFileName(String routeName, String suffix) =>
    '${routeName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$suffix.csv';
