import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit_example/main.dart';

/// Pumps a fixed number of frames.
///
/// The example screen contains a [Beacon], whose pulse always has a frame
/// scheduled, so `pumpAndSettle` would never return.
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('the example builds and its sections are present',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await settle(tester);
    expect(find.text('hint_kit'), findsWidgets);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.byType(Beacon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the disabled check-in button still explains itself',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await settle(tester);

    final Finder button = find.widgetWithText(ElevatedButton, 'Check in');
    expect(tester.widget<ElevatedButton>(button).enabled, isFalse);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(button),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await settle(tester);
    expect(find.text('You need an active shift to check in'), findsOneWidget);
  });

  testWidgets('the tour runs across four steps and two routes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await settle(tester);

    await tester.tap(find.text('Start tour'));
    await settle(tester);
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);

    // Step 2 is passthrough: pressing the real button advances the tour.
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Try it yourself'), findsOneWidget);

    await tester.tap(find.text('Press me'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Out of sight'), findsOneWidget, reason: 'step 3');

    // Step 4 lives on the details route, so the tour waits for it.
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('A step on another route'), findsNothing);

    await tester.tap(find.textContaining('Details page'), warnIfMissed: false);
    await settle(tester, 20);
    expect(find.text('A step on another route'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('A step on another route'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the beacon opens its hint', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await settle(tester);
    // The beacon sits below the fold; scroll it into view before tapping.
    await tester.scrollUntilVisible(find.byType(Beacon), 200);
    await settle(tester);
    // The dot is the affordance, not the whole child it decorates.
    await tester.tap(
      find.descendant(of: find.byType(Beacon), matching: find.byType(Hint)),
    );
    await settle(tester);
    expect(find.text('Duplicate a shift'), findsOneWidget);
  });
}
