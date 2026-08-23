import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit/testing.dart';

/// A three-step tour whose targets are all on one screen.
///
/// Step counts come from the scope, not the controller, so anything that
/// depends on a tour's length has to be pumped rather than unit-tested.
Widget threeStepApp(TourController controller) {
  return TourScope(
    controller: controller,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            HintTarget(
              tour: 'onboarding',
              order: 1,
              title: 'One',
              child: SizedBox(key: Key('one'), width: 80, height: 40),
            ),
            HintTarget(
              tour: 'onboarding',
              order: 2,
              title: 'Two',
              child: SizedBox(key: Key('two'), width: 80, height: 40),
            ),
            HintTarget(
              tour: 'onboarding',
              order: 3,
              title: 'Three',
              child: SizedBox(key: Key('three'), width: 80, height: 40),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(resetHintKit);

  group('progress is recorded', () {
    testWidgets('on every step change', (WidgetTester tester) async {
      final FakeTourStorage storage = FakeTourStorage();
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);
      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      expect(storage.indices['onboarding'], 0);
      tour.next();
      await tester.pumpAndSettle();
      expect(storage.indices['onboarding'], 1);
      tour.next();
      await tester.pumpAndSettle();
      expect(storage.indices['onboarding'], 2);
      tour.previous();
      await tester.pumpAndSettle();
      expect(storage.indices['onboarding'], 1);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('and cleared when the tour finishes',
        (WidgetTester tester) async {
      final FakeTourStorage storage = FakeTourStorage();
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);
      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour
        ..next()
        ..next()
        ..next(); // past the last step: finishes.
      await tester.pumpAndSettle();
      expect(tour.isRunning, isFalse);
      expect(storage.indices.containsKey('onboarding'), isFalse);
      expect(storage.completed, contains('onboarding'));
    });

    testWidgets('and cleared when the tour is skipped',
        (WidgetTester tester) async {
      final FakeTourStorage storage = FakeTourStorage();
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);
      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour.next();
      await tester.pumpAndSettle();
      tour.skip();
      await tester.pumpAndSettle();
      expect(storage.indices.containsKey('onboarding'), isFalse);
    });

    testWidgets('but kept when the tour is cancelled',
        (WidgetTester tester) async {
      // Cancelling is "stopped in code" — an app going to the background, a
      // scope being disposed — which is exactly what resuming is for.
      final FakeTourStorage storage = FakeTourStorage();
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);
      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour.next();
      await tester.pumpAndSettle();
      tour.cancel();
      await tester.pumpAndSettle();
      expect(storage.indices['onboarding'], 1);
      expect(storage.completed, isEmpty);
    });
  });

  group('start(resume: true)', () {
    test('picks up where the tour stopped', () async {
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 2});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      await tour.start('onboarding', resume: true);
      expect(tour.index, 2);
      expect(tour.step, 3);
    });

    test('starts at the beginning without it', () async {
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 2});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      await tour.start('onboarding');
      expect(tour.index, 0);
    });

    testWidgets('clamps a saved index past the end',
        (WidgetTester tester) async {
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 9});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);
      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();

      await tour.start('onboarding', resume: true);
      await tester.pumpAndSettle();
      expect(tour.index, 2);
      expect(find.text('Three'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });

    test('trusts the saved index when the length is not known yet', () async {
      // A route-spanning tour reports length 0 until its targets register;
      // clamping to that would silently restart from the first step.
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 3});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      await tour.start('onboarding', resume: true);
      expect(tour.index, 3);
    });

    test('a storage that records nothing simply never resumes', () async {
      // The default implementations of lastIndex/saveIndex do nothing, so a
      // storage written before resuming existed keeps working.
      final TourController tour = TourController(storage: const _OldStorage());
      addTearDown(tour.dispose);

      await tour.start('onboarding', resume: true);
      expect(tour.index, 0);
      expect(await tour.hasProgress('onboarding'), isFalse);
    });

    test('hasProgress answers without starting anything', () async {
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 1});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      expect(await tour.hasProgress('onboarding'), isTrue);
      expect(await tour.hasProgress('other'), isFalse);
      expect(tour.isRunning, isFalse);
    });

    test('a completed tour still does not start', () async {
      final FakeTourStorage storage = FakeTourStorage(
        completed: <String>{'onboarding'},
        indices: <String, int>{'onboarding': 1},
      );
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      await tour.start('onboarding', resume: true);
      expect(tour.isRunning, isFalse);
    });
  });

  group('in a real tree', () {
    testWidgets('the resumed step is the one that lights up',
        (WidgetTester tester) async {
      final FakeTourStorage storage =
          FakeTourStorage(indices: <String, int>{'onboarding': 1});
      final TourController tour = TourController(storage: storage);
      addTearDown(tour.dispose);

      await tester.pumpWidget(threeStepApp(tour));
      await tester.pumpAndSettle();
      await tour.start('onboarding', resume: true);
      await tester.pumpAndSettle();

      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);
      expect(find.text('2 of 3'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('an interrupted tour resumes on the next launch',
        (WidgetTester tester) async {
      final FakeTourStorage storage = FakeTourStorage();

      // First run: the user gets to step 2 and the app goes away.
      final TourController first = TourController(storage: storage);
      await tester.pumpWidget(threeStepApp(first));
      await tester.pumpAndSettle();
      await first.start('onboarding');
      await tester.pumpAndSettle();
      first.next();
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      first.dispose();

      // Second run: a brand-new controller over the same storage.
      final TourController second = TourController(storage: storage);
      addTearDown(second.dispose);
      await tester.pumpWidget(threeStepApp(second));
      await tester.pumpAndSettle();
      await second.start('onboarding', resume: true);
      await tester.pumpAndSettle();

      expect(find.text('Two'), findsOneWidget);
      second.skip();
      await tester.pumpAndSettle();
    });
  });

  group('beforeShow', () {
    testWidgets('is awaited before the step appears',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      final TourController tour = TourController();
      addTearDown(tour.dispose);

      await tester.pumpWidget(
        TourScope(
          controller: tour,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: HintTarget(
                tour: 'onboarding',
                order: 1,
                title: 'Prepared',
                beforeShow: () => gate.future,
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Nothing yet: the step is still waiting on the future.
      expect(find.text('Prepared'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Prepared'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('is abandoned when the tour moves on first',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      final TourController tour = TourController();
      addTearDown(tour.dispose);

      await tester.pumpWidget(
        TourScope(
          controller: tour,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  HintTarget(
                    tour: 'onboarding',
                    order: 1,
                    title: 'Slow',
                    beforeShow: () => gate.future,
                    child: const SizedBox(width: 80, height: 40),
                  ),
                  const HintTarget(
                    tour: 'onboarding',
                    order: 2,
                    title: 'Fast',
                    child: SizedBox(width: 80, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tour.start('onboarding');
      await tester.pump();
      tour.next();
      await tester.pumpAndSettle();
      expect(find.text('Fast'), findsOneWidget);

      // The first step's future finishing late must not reopen it.
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Slow'), findsNothing);
      expect(find.text('Fast'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });
  });
}

/// A storage from before resuming existed: it implements only the original
/// three methods and inherits the no-op defaults for the rest.
class _OldStorage extends TourStorage {
  const _OldStorage();

  @override
  Future<bool> isCompleted(String tour) async => false;

  @override
  Future<void> markCompleted(String tour) async {}

  @override
  Future<void> reset(String tour) async {}
}
