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
}
