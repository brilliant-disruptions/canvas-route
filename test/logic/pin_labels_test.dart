import 'package:canvas_route/core/logic/pin_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact times drop :00 and use a/p', () {
    expect(compactTime(DateTime(2026, 10, 31, 7)), '7a');
    expect(compactTime(DateTime(2026, 10, 31, 0, 15)), '12:15a');
    expect(compactTime(DateTime(2026, 10, 31, 12, 30)), '12:30p');
    expect(compactTime(DateTime(2026, 10, 31, 13)), '1p');
  });

  test('compact windows', () {
    expect(compactWindow(DateTime(2026, 10, 31, 7), DateTime(2026, 10, 31, 13)), '7a–1p');
    expect(compactWindow(DateTime(2026, 10, 31, 8), null), 'From 8a');
  });

  test('sign windows', () {
    expect(signWindow(DateTime(2026, 10, 31, 7), DateTime(2026, 10, 31, 13)), '7AM–1PM');
    expect(signWindow(DateTime(2026, 10, 31, 8, 30), null), 'FROM 8:30AM');
  });

  test('short place names drop suffixes and cap length', () {
    expect(shortPlaceName('Collectors Cave (card shop)'), 'Collectors Cave');
    expect(shortPlaceName('Moving sale — everything goes'), 'Moving sale');
    expect(shortPlaceName('Target'), 'Target');
    expect(shortPlaceName('Multi-family sale'), 'Multi-family sa…');
    expect(shortPlaceName('Barnes & Noble Booksellers'), 'Barnes & Noble…');
  });

  test('hunt filter: empty wants everything, wildcard always fits', () {
    expect(matchesHunt(['Tools'], {}), isTrue);
    expect(matchesHunt(['Tools', 'Kids'], {'Kids'}), isTrue);
    expect(matchesHunt(['Furniture'], {'Kids'}), isFalse);
    expect(matchesHunt(['Everything'], {'Kids'}, wildcard: 'Everything'), isTrue);
    expect(matchesHunt(const [], {'Kids'}), isFalse);
    expect(huntLabel({}), 'Any');
    expect(huntLabel({'Tools'}), 'Tools');
    expect(huntLabel({'Tools', 'Kids', 'Books'}), 'Tools +2');
  });

  group('sale status', () {
    final opens = DateTime(2026, 11, 7, 7);
    final closes = DateTime(2026, 11, 7, 11);
    String at(DateTime now) => saleStatus(opens, closes, now);

    test('a week out, the day before, and the last two hours', () {
      expect(at(DateTime(2026, 10, 31, 15)), 'Opens Sat 7a · in 7 days');
      expect(at(DateTime(2026, 11, 6, 20)), 'Opens tomorrow 7a');
      expect(at(DateTime(2026, 11, 7, 6, 15)), 'Opens in 45 min');
      expect(salePhase(opens, closes, DateTime(2026, 11, 7, 6, 15)), SalePhase.startingSoon);
    });

    test('open, closing soon, ended; reports only while it is on', () {
      expect(at(DateTime(2026, 11, 7, 8)), 'Open now · until 11a');
      expect(at(DateTime(2026, 11, 7, 10, 30)), 'Closing soon · until 11a');
      expect(at(DateTime(2026, 11, 7, 11)), 'Ended');
      expect(salePhaseTakesReports(salePhase(opens, closes, DateTime(2026, 11, 7, 8))), isTrue);
      expect(salePhaseTakesReports(salePhase(opens, closes, DateTime(2026, 10, 31))), isFalse);
      expect(salePhaseTakesReports(SalePhase.ended), isFalse);
    });
  });
}
