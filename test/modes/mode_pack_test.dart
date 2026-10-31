import 'package:canvas_route/data/models/app_mode.dart';
import 'package:canvas_route/data/models/visit_field.dart';
import 'package:canvas_route/modes/mode_pack.dart';
import 'package:canvas_route/modes/registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every mode has a pack', () {
    for (final m in AppMode.values) {
      expect(packFor(m).id, m);
    }
  });

  test('field sales keeps community off; consumer modes keep it on', () {
    expect(packFor(AppMode.fieldSales).hasCommunity, isFalse);
    expect(packFor(AppMode.yardSales).hasCommunity, isTrue);
    expect(packFor(AppMode.cardDrops).hasCommunity, isTrue);
  });

  test('outcome → report mappings reference declared report statuses', () {
    for (final pack in modePacks.values) {
      final statuses = pack.reportStatuses.map((s) => s.value).toSet();
      for (final e in pack.outcomeToReportStatus.entries) {
        expect(pack.defaultOutcomes, contains(e.key), reason: '${pack.label}: ${e.key}');
        expect(statuses, contains(e.value), reason: '${pack.label}: ${e.value}');
      }
    }
  });

  test('export fields resolve to a visit field or a built-in column', () {
    for (final pack in modePacks.values) {
      final keys = {'stopName', 'address', 'visitedAt', ...pack.defaultVisitFields.map((f) => f.key)};
      for (final f in pack.defaultExportFields) {
        expect(keys, contains(f), reason: '${pack.label}: $f');
      }
    }
  });

  test('time-window modes declare a non-distance optimizer', () {
    expect(packFor(AppMode.yardSales).optimizer, OptimizerKind.timeWindow);
    expect(packFor(AppMode.cardDrops).optimizer, OptimizerKind.restockWindow);
    expect(packFor(AppMode.fieldSales).usesTimeWindows, isFalse);
  });

  test('every default outcome has a quick-log icon', () {
    for (final pack in modePacks.values) {
      expect(pack.outcomeIcons.keys.toSet(), pack.defaultOutcomes.toSet(), reason: pack.label);
    }
  });

  test('recap wins are default outcomes', () {
    for (final pack in modePacks.values) {
      expect(pack.defaultOutcomes, containsAll(pack.winOutcomes), reason: pack.label);
    }
  });

  test('visit field definitions round-trip through JSON', () {
    const f = VisitFieldDefinition(key: 'c_bins', label: 'Bins', type: FieldType.number, isCustom: true);
    final back = VisitFieldDefinition.fromJson(f.toJson());
    expect(back.key, 'c_bins');
    expect(back.type, FieldType.number);
    expect(back.isCustom, isTrue);
  });
}
