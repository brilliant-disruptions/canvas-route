import 'package:canvas_route/core/logic/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escapes commas, quotes and newlines', () {
    expect(escapeCsvField('plain'), 'plain');
    expect(escapeCsvField('a,b'), '"a,b"');
    expect(escapeCsvField('say "hi"'), '"say ""hi"""');
    expect(escapeCsvField('line1\nline2'), '"line1\nline2"');
  });

  test('builds meta row, headers, and rows in field order', () {
    final csv = buildCsv(
      meta: ['Rep: Sam', 'Route: Sat run'],
      fields: ['stopName', 'spent', 'notes'],
      headers: {'stopName': 'Sale', 'spent': 'Spent (\$)'},
      rows: [
        const CsvRow({'stopName': 'Elm St', 'spent': '12.50', 'notes': 'lamp, books'}),
        const CsvRow({'stopName': 'Oak Ave'}),
      ],
    );
    expect(csv.split('\n'), [
      'Rep: Sam,Route: Sat run',
      'Sale,Spent (\$),notes',
      'Elm St,12.50,"lamp, books"',
      'Oak Ave,,',
    ]);
  });

  test('file name strips unsafe characters', () {
    expect(csvFileName('Yard sales · Sat Oct 25', 'visits'), 'Yard_sales___Sat_Oct_25_visits.csv');
  });
}
