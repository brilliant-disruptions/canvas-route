DateTime? dtOrNull(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
DateTime dt(dynamic v) => DateTime.parse(v as String).toLocal();
String? iso(DateTime? d) => d?.toUtc().toIso8601String();
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double dbl(dynamic v) => (v as num).toDouble();
double? dblOrNull(dynamic v) => v == null ? null : (v as num).toDouble();
int intOr(dynamic v, int fallback) => v == null ? fallback : (v as num).toInt();
List<String> strList(dynamic v) => v == null ? const [] : (v as List).map((e) => e.toString()).toList();
Map<String, dynamic> mapOf(dynamic v) => v == null ? {} : Map<String, dynamic>.from(v as Map);
