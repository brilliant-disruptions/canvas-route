// Reads a host's own sale post ("Huge moving sale Sat 11/7, 7am-noon, 4431 Bryan St…")
// into form fields. Pure; no Flutter. Every field is optional: whatever isn't found
// stays as the host left it.

class SaleDraft {
  const SaleDraft({
    this.name,
    this.address,
    this.day,
    this.opens,
    this.closes,
    this.categories = const {},
    this.earlyBirds,
  });

  final String? name;
  final String? address;

  /// The sale's (first) day, at midnight.
  final DateTime? day;

  /// Opening and closing time as (hour, minute).
  final (int, int)? opens;
  final (int, int)? closes;
  final Set<String> categories;

  /// 'welcome' or 'not_welcome'.
  final String? earlyBirds;

  /// How many fields the text filled, for "Filled 5 fields".
  int get filled => [name, address, day, opens, closes, earlyBirds].where((v) => v != null).length + (categories.isEmpty ? 0 : 1);
}

const _streetTypes =
    r'(?:St|Street|Ave|Avenue|Rd|Road|Dr|Drive|Ln|Lane|Blvd|Boulevard|Ct|Court|Cir|Circle|Way|Pl|Place|Pkwy|Parkway|Trl|Trail|Ter|Terrace|Hwy|Highway|Loop|Row|Run|Pass|Sq|Square|Xing|Crossing)';

// "4431 Bryan St", "123 N. Main Street, Plano, TX 75024", "901 Eagle Creek Trl #4".
final _address = RegExp(
  [
    r'\b\d{1,6}\s+(?:[NSEW]\.?\s+)?', // number, optional direction
    r'(?:[A-Za-z0-9.\x27-]+\s+){0,4}', // street name words
    _streetTypes,
    r'\b\.?',
    r'(?:\s*(?:#|Apt\.?|Unit|Suite)\s*\w+)?', // unit
    r'(?:,\s*[A-Za-z][A-Za-z .]+?(?:,\s*[A-Z]{2})?(?:\s+\d{5})?)?', // city, state, zip
    r'(?=$|[\s.,;!)\n])',
  ].join(),
  caseSensitive: false,
);

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// The date of a month/day on or after today (rolling to next year if passed).
DateTime _upcoming(int month, int day, DateTime now) {
  var d = DateTime(now.year, month, day);
  if (d.isBefore(_midnight(now))) d = DateTime(now.year + 1, month, day);
  return d;
}

DateTime? _parseDay(String t, DateTime now) {
  final s = t.toLowerCase();
  // 11/7, 11/07/2026, 11-7
  final numeric = RegExp(r'\b(1[0-2]|0?[1-9])[/-](3[01]|[12]\d|0?[1-9])(?:[/-](\d{2,4}))?\b').firstMatch(s);
  if (numeric != null) {
    final m = int.parse(numeric[1]!), d = int.parse(numeric[2]!);
    if (numeric[3] != null) {
      final y = int.parse(numeric[3]!);
      return DateTime(y < 100 ? 2000 + y : y, m, d);
    }
    return _upcoming(m, d, now);
  }
  // Nov 7, November 7th
  final named = RegExp(r'\b(' + _months.join('|') + r')[a-z]*\.?\s+(3[01]|[12]\d|0?[1-9])(?:st|nd|rd|th)?\b').firstMatch(s);
  if (named != null) return _upcoming(_months.indexOf(named[1]!) + 1, int.parse(named[2]!), now);
  // Today / tomorrow
  if (RegExp(r'\btoday\b').hasMatch(s)) return _midnight(now);
  if (RegExp(r'\btomorrow\b').hasMatch(s)) return DateTime(now.year, now.month, now.day + 1);
  // Sat, Saturday, "this Saturday", "next Sat": the first weekday named.
  final wd = RegExp(r'\b(next\s+)?(' + _weekdays.join('|') + r')(?:day|urday|nesday|sday|rsday|r)?\b').firstMatch(s);
  if (wd != null) {
    final target = _weekdays.indexOf(wd[2]!) + 1;
    var add = (target - now.weekday) % 7;
    if (wd[1] != null && add < 7) add += 7;
    return DateTime(now.year, now.month, now.day + add);
  }
  return null;
}

/// (hour, minute) from "7", "7:30", "7am", "noon"; [pm] forces afternoon.
(int, int)? _clock(String raw, {bool? pm}) {
  final s = raw.trim().toLowerCase();
  if (s.startsWith('noon')) return (12, 0);
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?|a|p)?$').firstMatch(s);
  if (m == null) return null;
  var h = int.parse(m[1]!);
  final min = int.parse(m[2] ?? '0');
  if (h > 23 || min > 59) return null;
  final suffix = m[3]?.replaceAll('.', '');
  final isPm = suffix == null ? pm : suffix.startsWith('p');
  if (isPm == true && h < 12) h += 12;
  if (isPm == false && h == 12) h = 0;
  return (h, min);
}

final _range = RegExp(
  r'\b(\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?|a|p)?|noon)\s*(?:-|–|—|to|till|til|until)\s*(\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?|a|p)?|noon)(?=$|[^\d/])',
  caseSensitive: false,
);

/// Opening and closing times from "7am-1pm", "7 - 2", "8 to noon", "7:30am–12:30".
((int, int), (int, int))? _parseHours(String t) {
  for (final m in _range.allMatches(t)) {
    final a = m[1]!, b = m[2]!;
    // A bare "11-7" with no am/pm is likely a date (handled elsewhere), not hours.
    final hasMarker = RegExp(r'[ap]|noon|:', caseSensitive: false).hasMatch('$a$b');
    final before = m.start > 0 ? t[m.start - 1] : ' ';
    if (!hasMarker && (before == '/' || t.substring(m.end).startsWith('/'))) continue;
    // A bare opening hour stays as written: yard sales open in the morning.
    final open = _clock(a);
    if (open == null) continue;
    var close = _clock(b);
    if (close == null) continue;
    // "7-2", "8-12:30": a bare closing hour at or before the opening is afternoon.
    if (!RegExp(r'[ap]|noon', caseSensitive: false).hasMatch(b) && close.$1 <= open.$1 && close.$1 < 12) {
      close = (close.$1 + 12, close.$2);
    }
    if (close.$1 * 60 + close.$2 <= open.$1 * 60 + open.$2) continue;
    return (open, close);
  }
  return null;
}

final _kinds = <(RegExp, String)>[
  (RegExp(r'\bestate sale\b', caseSensitive: false), 'Estate sale'),
  (RegExp(r'\bmoving sale\b', caseSensitive: false), 'Moving sale'),
  (RegExp(r'\bmulti[- ]?family\b', caseSensitive: false), 'Multi-family sale'),
  (RegExp(r'\b(neighbou?rhood|community|street)[- ](wide )?(garage |yard )?sale\b', caseSensitive: false), 'Neighborhood sale'),
  (RegExp(r'\b(church|rummage)\b', caseSensitive: false), 'Rummage sale'),
  (RegExp(r'\bgarage sale\b', caseSensitive: false), 'Garage sale'),
  (RegExp(r'\byard sale\b', caseSensitive: false), 'Yard sale'),
];

/// Reads what it can from a host's post. [categoryKeywords] maps each category
/// to words that imply it (from the mode's config).
SaleDraft parseSaleText(String text, DateTime now, {Map<String, List<String>> categoryKeywords = const {}}) {
  final t = text.replaceAll('\r', '');
  final lower = t.toLowerCase();

  var addr = _address.firstMatch(t)?[0]?.trim().replaceAll(RegExp(r'[.,;]+$'), '');
  // A shouted sign address reads better as "5927 Goliad Ave, Dallas, TX".
  if (addr != null && addr == addr.toUpperCase()) {
    addr = addr
        .split(' ')
        .map((w) => w.length <= 2 || RegExp(r'^\d').hasMatch(w) ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  // Hours first, and blank them out so "7-1" isn't read as July 1st.
  final hours = _parseHours(t);
  final forDate = hours == null ? t : t.replaceAll(_range, ' ');
  var day = _parseDay(forDate, now);
  // "Sat" read on a Saturday afternoon means next Saturday once today's sale is over.
  if (day != null && day.year == now.year && day.month == now.month && day.day == now.day) {
    final (ch, cm) = hours?.$2 ?? (13, 0);
    if (now.hour * 60 + now.minute >= ch * 60 + cm) day = DateTime(day.year, day.month, day.day + 7);
  }

  // A short first line that mentions a sale is the title; else the kind of sale.
  final firstLine = t.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
  String? name;
  if (firstLine.length <= 60 && RegExp(r'\bsale\b', caseSensitive: false).hasMatch(firstLine)) {
    name = firstLine.replaceAll(RegExp(r'[!*#]+'), '').trim();
    // Signs shout: "GARAGE SALE" reads better as "Garage Sale".
    if (name == name.toUpperCase() && RegExp('[A-Z]').hasMatch(name)) {
      name = name.toLowerCase().split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  } else {
    for (final (re, label) in _kinds) {
      if (re.hasMatch(t)) {
        name = label;
        break;
      }
    }
  }

  final cats = <String>{
    for (final e in categoryKeywords.entries)
      if (e.value.any((k) => RegExp('\\b${RegExp.escape(k)}', caseSensitive: false).hasMatch(lower))) e.key,
  };

  String? early;
  if (RegExp(r"\b(no|not|don'?t|please no)\b[^.\n]{0,20}\bearly( birds?)?\b", caseSensitive: false).hasMatch(t)) {
    early = 'not_welcome';
  } else if (RegExp(r'\bearly birds? (welcome|ok|okay)\b', caseSensitive: false).hasMatch(t)) {
    early = 'welcome';
  }

  return SaleDraft(
    name: name,
    address: addr,
    day: day,
    opens: hours?.$1,
    closes: hours?.$2,
    categories: cats,
    earlyBirds: early,
  );
}
