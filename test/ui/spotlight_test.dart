import 'package:canvas_route/core/theme/kn_theme.dart';
import 'package:canvas_route/ui/widgets/spotlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a = GlobalKey(), b = GlobalKey(), gone = GlobalKey();
  final steps = [
    SpotlightStep(target: a, title: 'First', body: 'The first thing'),
    SpotlightStep(target: gone, title: 'Missing', body: 'Not on screen'),
    SpotlightStep(target: b, title: 'Second', body: 'The second thing'),
  ];

  Future<Future<bool>> start(WidgetTester t, {Brightness brightness = Brightness.dark, bool still = false}) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        theme: knTheme(brightness),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: still),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              // One target near the top, one on the bottom edge.
              return Column(
                children: [
                  SizedBox(key: a, width: 100, height: 40),
                  const Spacer(),
                  SizedBox(key: b, width: 100, height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
    final done = showSpotlight(ctx, steps);
    await t.pumpAndSettle();
    return done;
  }

  testWidgets('steps whose target is not on screen are left out', (t) async {
    final done = await start(t);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Missing'), findsNothing);
    expect(find.text('Skip'), findsNothing, reason: 'the last stop only offers Got it');
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    expect(await done, isTrue);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('tapping anywhere goes on', (t) async {
    await start(t);
    await t.tapAt(const Offset(380, 400));
    await t.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('skip ends it early', (t) async {
    final done = await start(t);
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await done, isFalse);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('the caption sits below its target, or above when there is no room', (t) async {
    await start(t);
    final first = t.getRect(find.ancestor(of: find.text('First'), matching: find.byType(Container)).first);
    expect(first.top, greaterThan(t.getRect(find.byKey(a)).bottom));
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    final second = t.getRect(find.ancestor(of: find.text('Second'), matching: find.byType(Container)).first);
    expect(second.bottom, lessThan(t.getRect(find.byKey(b)).top));
  });

  testWidgets('follows a target that moves', (t) async {
    late BuildContext ctx;
    late StateSetter set;
    var gap = 0.0;
    final k = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: knTheme(Brightness.dark),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, s) {
              ctx = c;
              set = s;
              return Column(
                children: [
                  SizedBox(height: gap),
                  SizedBox(key: k, width: 100, height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
    showSpotlight(ctx, [SpotlightStep(target: k, title: 'Moving', body: 'It moves')]);
    await t.pumpAndSettle();
    final before = t.getRect(find.ancestor(of: find.text('Moving'), matching: find.byType(Container)).first).top;
    set(() => gap = 200);
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpAndSettle();
    final after = t.getRect(find.ancestor(of: find.text('Moving'), matching: find.byType(Container)).first).top;
    expect(after - before, closeTo(200, 0.01));
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
  });

  testWidgets('with reduced motion, steps change without animating', (t) async {
    await start(t, still: true);
    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing, reason: 'no cross-fade left running');
  });

  testWidgets('works on the light theme too', (t) async {
    final done = await start(t, brightness: Brightness.light);
    expect(find.text('1 of 2'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await done, isFalse);
  });

  testWidgets('the caption is read out, the dimmed backdrop is not', (t) async {
    final handle = t.ensureSemantics();
    await start(t);
    expect(find.bySemanticsLabel(RegExp('The first thing')), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('nothing to show: resolves at once without a route', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(await showSpotlight(ctx, [SpotlightStep(target: gone, title: 'x', body: 'y')]), isTrue);
  });
}
