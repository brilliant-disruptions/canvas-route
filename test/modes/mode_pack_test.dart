import 'package:canvas_route/data/models/app_mode.dart';
import 'package:canvas_route/data/models/profile.dart';
import 'package:canvas_route/data/models/visit_field.dart';
import 'package:canvas_route/modes/mode_pack.dart';
import 'package:canvas_route/modes/registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('launch modes', () {
    test('v1 ships Yard Sales alone', () {
      expect(launchModes, [AppMode.yardSales]);
      expect(launchable(AppMode.fieldSales), AppMode.yardSales);
      expect(launchable(AppMode.yardSales), AppMode.yardSales);
    });

    test('parses ids in order, dropping blanks, unknowns and repeats', () {
      expect(parseLaunchModes(' card_drops, yard_sales,,nope,card_drops'), [AppMode.cardDrops, AppMode.yardSales]);
      expect(parseLaunchModes('field_sales,yard_sales,card_drops'), AppMode.values);
    });

    test('an unusable list falls back to Yard Sales', () {
      expect(parseLaunchModes(''), [AppMode.yardSales]);
      expect(parseLaunchModes('bogus'), [AppMode.yardSales]);
    });
  });

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

  test('paid packs price and pitch their plan', () {
    for (final pack in modePacks.values.where((p) => p.proProductId != null)) {
      expect(pack.proPrice, isNotEmpty, reason: pack.label);
      expect(pack.proPitch, isNotEmpty, reason: pack.label);
      expect(pack.proPerks, isNotEmpty, reason: pack.label);
    }
  });

  test('route limit applies to free users at the limit only', () {
    final pack = packFor(AppMode.cardDrops);
    expect(pack.atRouteLimit(0, paying: false), isFalse);
    expect(pack.atRouteLimit(pack.freeRouteLimit!, paying: false), isTrue);
    expect(pack.atRouteLimit(99, paying: true), isFalse);
    // Field Sales: free reps keep 3 saved routes; Pro is unlimited.
    expect(packFor(AppMode.fieldSales).atRouteLimit(2, paying: false), isFalse);
    expect(packFor(AppMode.fieldSales).atRouteLimit(3, paying: false), isTrue);
    expect(packFor(AppMode.fieldSales).atRouteLimit(99, paying: true), isFalse);
  });

  test('every search suggestion has a quick-start icon', () {
    for (final pack in modePacks.values) {
      expect(pack.suggestionIcons.keys.toSet(), pack.searchSuggestions.toSet(), reason: pack.label);
    }
  });

  test('visit field definitions round-trip through JSON', () {
    const f = VisitFieldDefinition(key: 'c_bins', label: 'Bins', type: FieldType.number, isCustom: true);
    final back = VisitFieldDefinition.fromJson(f.toJson());
    expect(back.key, 'c_bins');
    expect(back.type, FieldType.number);
    expect(back.isCustom, isTrue);
  });

  group('paid access per vertical', () {
    Profile who({Plan plan = Plan.free, List<String> owns = const []}) =>
        Profile.fromRow({'id': 'u', 'plan': plan.name, 'entitlements': owns});
    bool pays(Profile p, AppMode m) => p.owns(packFor(m).proProductId, includedInPlan: packFor(m).includedInPlan);

    test('a Season Pass unlocks Yard Sales only', () {
      final p = who(owns: [packFor(AppMode.yardSales).proProductId!]);
      expect(pays(p, AppMode.yardSales), isTrue);
      expect(pays(p, AppMode.fieldSales), isFalse);
      expect(pays(p, AppMode.cardDrops), isFalse);
      expect(p.isPaying, isTrue);
    });

    test('a Field Sales Pro plan unlocks Field Sales only', () {
      final p = who(plan: Plan.pro);
      expect(pays(p, AppMode.fieldSales), isTrue);
      expect(pays(p, AppMode.yardSales), isFalse);
    });

    test('free users own nothing', () {
      final p = who();
      expect(AppMode.values.any((m) => pays(p, m)), isFalse);
      expect(p.isPaying, isFalse);
    });

    test('every paid vertical has its own product id', () {
      final ids = [for (final p in modePacks.values) ?p.proProductId];
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
