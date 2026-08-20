import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

Future<void> pumpBeacon(
  WidgetTester tester,
  Widget beacon, {
  MediaQueryData media = const MediaQueryData(size: Size(800, 600)),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) =>
          MediaQuery(data: media, child: child ?? const SizedBox()),
      home: Scaffold(body: Center(child: beacon)),
    ),
  );
}

/// Advances past the hint's show animation.
///
/// A running beacon always has a frame scheduled, so `pumpAndSettle` would
/// never return — pump a fixed number of frames instead.
Future<void> settleWithPulse(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('a tap opens the hint and a second tap closes it',
      (WidgetTester tester) async {
    await pumpBeacon(
      tester,
      const Beacon(message: 'Long-press a shift to duplicate it'),
    );
    expect(find.text('Long-press a shift to duplicate it'), findsNothing);

    await tester.tap(find.byType(Beacon));
    await settleWithPulse(tester);
    expect(find.text('Long-press a shift to duplicate it'), findsOneWidget);

    await tester.tap(find.byType(Beacon), warnIfMissed: false);
    await settleWithPulse(tester);
    expect(find.text('Long-press a shift to duplicate it'), findsNothing);
  });

  testWidgets('renders over a child without displacing it',
      (WidgetTester tester) async {
    await pumpBeacon(
      tester,
      const Beacon(
        message: 'hint',
        child: SizedBox(width: 120, height: 48, child: Text('feature')),
      ),
    );
    expect(tester.getSize(find.byType(Beacon)), const Size(120, 48));
    expect(find.text('feature'), findsOneWidget);
  });

  testWidgets('the tap target is larger than the dot',
      (WidgetTester tester) async {
    await pumpBeacon(tester, const Beacon(message: 'hint', size: 10));
    expect(tester.getSize(find.byType(Beacon)), const Size(20, 20));
  });

  testWidgets('pulses by default', (WidgetTester tester) async {
    await pumpBeacon(tester, const Beacon(message: 'hint'));
    await tester.pump(const Duration(milliseconds: 100));
    // A running pulse keeps scheduling frames.
    expect(tester.binding.hasScheduledFrame, isTrue);
    // Let the test end cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('autoStart: false leaves it still', (WidgetTester tester) async {
    await pumpBeacon(
      tester,
      const Beacon(message: 'hint', autoStart: false),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('does not pulse when animations are disabled',
      (WidgetTester tester) async {
    await pumpBeacon(
      tester,
      const Beacon(message: 'hint'),
      media: const MediaQueryData(
        size: Size(800, 600),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('carries a semantic label', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpBeacon(
      tester,
      const Beacon(message: 'hint', semanticsLabel: 'What is this?'),
    );
    expect(
      find.bySemanticsLabel('What is this?'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('reports show and dismiss', (WidgetTester tester) async {
    int shows = 0;
    int dismisses = 0;
    await pumpBeacon(
      tester,
      Beacon(
        message: 'hint',
        onShow: () => shows++,
        onDismiss: () => dismisses++,
      ),
    );
    await tester.tap(find.byType(Beacon));
    await settleWithPulse(tester);
    expect(shows, 1);

    await tester.tapAt(const Offset(5, 5));
    await settleWithPulse(tester);
    expect(dismisses, 1);
  });

  testWidgets('supports rich content', (WidgetTester tester) async {
    await pumpBeacon(
      tester,
      Beacon(
        interactive: true,
        contentBuilder: (BuildContext context) => const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[Icon(Icons.star), Text('rich beacon')],
        ),
      ),
    );
    await tester.tap(find.byType(Beacon));
    await settleWithPulse(tester);
    expect(find.text('rich beacon'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  test('asserts without content', () {
    expect(Beacon.new, throwsA(isA<AssertionError>()));
  });
}
