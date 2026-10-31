import 'package:canvas_route/core/logic/sale_text.dart';
import 'package:canvas_route/modes/yard_sales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 15); // Saturday afternoon
  SaleDraft parse(String s) => parseSaleText(s, now, categoryKeywords: yardSalesPack.categoryKeywords);

  test('a typical Facebook post', () {
    final d = parse('HUGE Moving Sale!!\nSat 11/7, 7am-1pm at 4431 Bryan St, Dallas, TX 75204. '
        'Furniture, kids clothes, tools, vinyl records. No early birds please!');
    expect(d.name, 'HUGE Moving Sale');
    expect(d.address, '4431 Bryan St, Dallas, TX 75204');
    expect(d.day, DateTime(2026, 11, 7));
    expect(d.opens, (7, 0));
    expect(d.closes, (13, 0));
    expect(d.categories, containsAll(['Furniture', 'Kids', 'Clothing', 'Tools', 'Collectibles']));
    expect(d.earlyBirds, 'not_welcome');
    expect(d.filled, 7);
  });

  test('bare hours read as morning to afternoon', () {
    expect(parse('Garage sale Saturday 7-2').closes, (14, 0));
    expect(parse('Garage sale Saturday 7-2').opens, (7, 0));
    expect(parse('8 to noon').closes, (12, 0));
    expect(parse('7:30am – 12:30').closes, (12, 30));
    expect(parse('starts 8:00 AM until 3 PM').opens, (8, 0));
    expect(parse('starts 8:00 AM until 3 PM').closes, (15, 0));
  });

  test('dates: weekdays, month names, numeric, today and tomorrow', () {
    expect(parse('Yard sale this Saturday 7-5').day, DateTime(2026, 10, 31), reason: 'still on until 5pm');
    expect(parse('Yard sale this Saturday').day, DateTime(2026, 11, 7), reason: 'a usual sale is over by 3pm');
    expect(parse('next Sat').day, DateTime(2026, 11, 7));
    expect(parse('Fri & Sat').day, DateTime(2026, 11, 6), reason: 'first day named');
    expect(parse('November 14th').day, DateTime(2026, 11, 14));
    expect(parse('Oct 3').day, DateTime(2027, 10, 3), reason: 'past dates roll to next year');
    expect(parse('sale tomorrow 8-1').day, DateTime(2026, 11, 1));
    expect(parse('12/5/26').day, DateTime(2026, 12, 5));
  });

  test("hours aren't mistaken for dates and vice versa", () {
    final d = parse('Sale on 11/7 from 7-1');
    expect(d.day, DateTime(2026, 11, 7));
    expect((d.opens, d.closes), ((7, 0), (13, 0)));
  });

  test('addresses with directions, units and street types', () {
    expect(parse('at 123 N. Main Street #4 come by').address, '123 N. Main Street #4');
    expect(parse('901 Eagle Creek Trl, McKinney').address, '901 Eagle Creek Trl, McKinney');
    expect(parse('call 214-555-0100 for info').address, isNull);
  });

  test('names the kind of sale when the first line is long', () {
    final d = parse('We are cleaning out the whole house before we move next month so come by, estate sale style, everything priced to go');
    expect(d.name, 'Estate sale');
  });

  test('early birds welcome', () => expect(parse('Early birds welcome!').earlyBirds, 'welcome'));

  test('text with nothing useful fills nothing', () {
    final d = parse('Hello neighbors!');
    expect(d.filled, 0);
  });

  test('a sign as OCR reads it: all caps, one block per line', () {
    final d = parse('GARAGE SALE\nSAT 7AM-2PM\n5927 GOLIAD AVE\nFURNITURE · TOOLS · BABY STUFF');
    expect(d.name, 'Garage Sale');
    expect(d.address, '5927 Goliad Ave');
    expect(parse('123 N MAIN ST, PLANO, TX 75024').address, '123 N Main St, Plano, TX 75024');
    // It's Saturday 3pm in these tests, so today's 7-2 sale is over: next Saturday.
    expect(d.day, DateTime(2026, 11, 7));
    expect((d.opens, d.closes), ((7, 0), (14, 0)));
    expect(d.categories, containsAll(['Furniture', 'Tools', 'Kids']));
  });
}
