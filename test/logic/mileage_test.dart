import 'package:canvas_route/core/logic/mileage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IRS rate follows the day driven, including the 2026 mid-year change', () {
    expect(irsBusinessRate(DateTime(2024, 6, 1)), 0.70);
    expect(irsBusinessRate(DateTime(2025, 12, 31)), 0.70);
    expect(irsBusinessRate(DateTime(2026, 1, 1)), 0.725);
    expect(irsBusinessRate(DateTime(2026, 6, 30)), 0.725);
    expect(irsBusinessRate(DateTime(2026, 7, 1)), 0.76);
  });

  test('months group newest first with rate-correct deductions', () {
    final months = mileageByMonth([
      (day: DateTime(2026, 6, 30), miles: 10.0),
      (day: DateTime(2026, 7, 2), miles: 20.0),
      (day: DateTime(2026, 7, 20), miles: 5.0),
    ]);
    expect(months.map((m) => m.month), [DateTime(2026, 7), DateTime(2026, 6)]);
    expect(months.first.miles, 25.0);
    expect(months.first.trips, 2);
    expect(months.first.deduction, closeTo(25 * 0.76, 1e-9));
    expect(months.last.deduction, closeTo(10 * 0.725, 1e-9));
  });

  test('no trips, no months', () => expect(mileageByMonth([]), isEmpty));
}
