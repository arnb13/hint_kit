import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit/testing.dart';

/// A three-step tour whose middle step can opt out.
Widget app({
  required TourController controller,
  bool middleEnabled = true,
  Map<String, int>? tourLengths,
  Duration? stepTimeout,
  void Function(String tour, int index)? onStepUnavailable,
  bool buildThird = true,
}) {
  return TourScope(
    controller: controller,
    tourLengths: tourLengths,
    stepTimeout: stepTimeout,
    onStepUnavailable: onStepUnavailable,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const HintTarget(
              tour: 'onboarding',
              order: 1,
              title: 'One',
              child: SizedBox(width: 80, height: 40),
            ),
            HintTarget(
              tour: 'onboarding',
              order: 2,
              title: 'Two',
              enabled: middleEnabled,
              child: const SizedBox(width: 80, height: 40),
            ),
            if (buildThird)
              const HintTarget(
                tour: 'onboarding',
                order: 3,
                title: 'Three',
                child: SizedBox(width: 80, height: 40),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(resetHintKit);

  group('enabled: false', () {
    testWidgets('takes the step out of the tour', (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(app(controller: tour, middleEnabled: false));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);

      tour.next();
      await tester.pumpAndSettle();
      // Straight to the third step: the second does not apply to this user.
      expect(find.text('Three'), findsOneWidget);
      expect(find.text('Two'), findsNothing);
      expect(find.text('2 of 2'), findsOneWidget);

      tour.next();
      await tester.pumpAndSettle();
      expect(tour.isRunning, isFalse);
    });

    testWidgets('is subtracted from a declared length',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        app(
          controller: tour,
          middleEnabled: false,
          tourLengths: const <String, int>{'onboarding': 3},
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      // Not "1 of 3": one of the three was never going to appear.
      expect(find.text('1 of 2'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('the child still renders', (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(app(controller: tour, middleEnabled: false));
      await tester.pumpAndSettle();
      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opting out mid-tour releases the step',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(app(controller: tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour.next();
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);

      // The flag flips while its step is the one on screen.
      await tester.pumpWidget(app(controller: tour, middleEnabled: false));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsNothing);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('an enabled step behaves as before',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(app(controller: tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      tour.next();
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });
  });

  group('stepTimeout', () {
    // Orders 1 and 2 are built, the tour declares four steps: indices 2 and 3
    // have no target and never will. That is the only shape where a step can
    // go unclaimed — indices map into the orders that *have* registered, so
    // omitting a middle target closes the gap rather than leaving one.
    Widget gappyApp(
      TourController tour, {
      Duration? stepTimeout,
      void Function(String tour, int index)? onStepUnavailable,
      bool buildThird = false,
    }) =>
        app(
          controller: tour,
          buildThird: buildThird,
          tourLengths: const <String, int>{'onboarding': 4},
          stepTimeout: stepTimeout,
          onStepUnavailable: onStepUnavailable,
        );

    testWidgets('without one, the tour waits forever',
        (WidgetTester tester) async {
      // The behaviour that lets a tour cross routes: a step is simply not
      // drawn until its target turns up, however long that takes.
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(gappyApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour
        ..next()
        ..next();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(tour.isRunning, isTrue);
      expect(tour.index, 2);
      expect(find.text('Three'), findsNothing);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('moves on when the target never arrives',
        (WidgetTester tester) async {
      final List<int> missed = <int>[];
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        gappyApp(
          tour,
          stepTimeout: const Duration(seconds: 2),
          onStepUnavailable: (String _, int index) => missed.add(index),
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour
        ..next()
        ..next();
      await tester.pumpAndSettle();
      expect(tour.index, 2);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(missed, <int>[2], reason: 'the empty step should be reported');
      expect(tour.index, 3);

      // The fourth is empty too, so the tour reports it and then ends rather
      // than sitting on a step nothing can draw.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(missed, <int>[2, 3]);
      expect(tour.isRunning, isFalse);
    });

    testWidgets('a target that turns up in time cancels the countdown',
        (WidgetTester tester) async {
      final List<int> missed = <int>[];
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        gappyApp(
          tour,
          stepTimeout: const Duration(seconds: 2),
          onStepUnavailable: (String _, int index) => missed.add(index),
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour
        ..next()
        ..next();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // The screen holding the step finally builds, with time to spare.
      await tester.pumpWidget(
        gappyApp(
          tour,
          stepTimeout: const Duration(seconds: 2),
          onStepUnavailable: (String _, int index) => missed.add(index),
          buildThird: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(missed, isEmpty);
      expect(find.text('Three'), findsOneWidget);
      expect(tour.index, 2);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('a missing last step ends the tour',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: tour,
          tourLengths: const <String, int>{'onboarding': 2},
          stepTimeout: const Duration(seconds: 1),
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: HintTarget(
                tour: 'onboarding',
                order: 1,
                title: 'One',
                child: SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour.next();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(tour.isRunning, isFalse);
    });
  });
}
