import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// A storage that records what it was asked, for assertions.
class RecordingStorage implements TourStorage {
  final Set<String> completed = <String>{};
  final List<String> calls = <String>[];

  @override
  Future<bool> isCompleted(String tour) async {
    calls.add('isCompleted:$tour');
    return completed.contains(tour);
  }

  @override
  Future<void> markCompleted(String tour) async {
    calls.add('markCompleted:$tour');
    completed.add(tour);
  }

  @override
  Future<void> reset(String tour) async {
    calls.add('reset:$tour');
    completed.remove(tour);
    indices.remove(tour);
  }

  final Map<String, int> indices = <String, int>{};

  @override
  Future<int?> lastIndex(String tour) async {
    calls.add('lastIndex:$tour');
    return indices[tour];
  }

  @override
  Future<void> saveIndex(String tour, int? index) async {
    calls.add('saveIndex:$tour:$index');
    if (index == null) {
      indices.remove(tour);
    } else {
      indices[tour] = index;
    }
  }
}

/// Builds a three-step tour over three buttons.
Widget threeStepApp({
  TourController? controller,
  TourStorage? storage,
  Map<String, int>? tourLengths,
  bool passthroughSecond = false,
  VoidCallback? onSecondTap,
}) {
  return TourScope(
    controller: controller,
    storage: controller == null ? storage : null,
    tourLengths: tourLengths,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const HintTarget(
              tour: 'onboarding',
              order: 1,
              title: 'First',
              description: 'The first step.',
              child: SizedBox(width: 120, height: 40, child: Text('one')),
            ),
            HintTarget(
              tour: 'onboarding',
              order: 2,
              title: 'Second',
              description: 'The second step.',
              passthrough: passthroughSecond,
              child: SizedBox(
                width: 120,
                height: 40,
                child: GestureDetector(
                  onTap: onSecondTap,
                  child: const Text('two'),
                ),
              ),
            ),
            const HintTarget(
              tour: 'onboarding',
              order: 3,
              title: 'Third',
              description: 'The last step.',
              child: SizedBox(width: 120, height: 40, child: Text('three')),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('TourController', () {
    test('starts, advances and finishes', () async {
      final RecordingStorage storage = RecordingStorage();
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      expect(controller.isRunning, isFalse);

      await controller.start('onboarding');
      expect(controller.activeTour, 'onboarding');
      expect(controller.index, 0);
      expect(controller.step, 1);

      controller.finish();
      expect(controller.isRunning, isFalse);
      expect(storage.completed, contains('onboarding'));
    });

    test('does not restart a completed tour', () async {
      final RecordingStorage storage = RecordingStorage()
        ..completed.add('onboarding');
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await controller.start('onboarding');
      expect(controller.isRunning, isFalse);
    });

    test('force restarts a completed tour', () async {
      final RecordingStorage storage = RecordingStorage()
        ..completed.add('onboarding');
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await controller.start('onboarding', force: true);
      expect(controller.isRunning, isTrue);
    });

    test('skip marks the tour completed', () async {
      final RecordingStorage storage = RecordingStorage();
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await controller.start('onboarding');
      controller.skip();
      expect(controller.isRunning, isFalse);
      expect(storage.completed, contains('onboarding'));
    });

    test('cancel does not mark the tour completed', () async {
      final RecordingStorage storage = RecordingStorage();
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await controller.start('onboarding');
      controller.cancel();
      expect(controller.isRunning, isFalse);
      expect(storage.completed, isEmpty);
    });

    test('previous is a no-op on the first step', () async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await controller.start('t');
      controller.previous();
      expect(controller.index, 0);
    });

    test('reports the reason a tour ended', () async {
      final List<TourEndReason> reasons = <TourEndReason>[];
      final TourController controller = TourController(
        onEnd: (String _, TourEndReason reason) => reasons.add(reason),
      );
      addTearDown(controller.dispose);
      await controller.start('a');
      controller.skip();
      await controller.start('b');
      controller.finish();
      expect(reasons, <TourEndReason>[
        TourEndReason.skipped,
        TourEndReason.finished,
      ]);
    });

    test('reports every step change', () async {
      final List<int> steps = <int>[];
      final TourController controller = TourController(
        onStepChanged: (String _, int index) => steps.add(index),
      );
      addTearDown(controller.dispose);
      await controller.start('t');
      // With no scope there are no registered steps, so next() finishes.
      expect(steps, <int>[0]);
    });

    test('starting an already running tour is a no-op', () async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await controller.start('t');
      controller.next();
      final int before = controller.index;
      await controller.start('t');
      expect(controller.index, before);
    });

    test('an in-memory storage forgets nothing during the session', () async {
      final InMemoryTourStorage storage = InMemoryTourStorage();
      expect(await storage.isCompleted('t'), isFalse);
      await storage.markCompleted('t');
      expect(await storage.isCompleted('t'), isTrue);
      expect(storage.completed, <String>{'t'});
      await storage.reset('t');
      expect(await storage.isCompleted('t'), isFalse);
    });
  });

  group('tour flow', () {
    testWidgets('shows the first step and advances through the tour',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(threeStepApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);

      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(controller.length, 3);
      expect(find.text('1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Third'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Third'), findsNothing);
      expect(controller.isRunning, isFalse);
    });

    testWidgets('skip ends the tour', (WidgetTester tester) async {
      final RecordingStorage storage = RecordingStorage();
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await tester.pumpWidget(threeStepApp(controller: controller));
      await controller.start('onboarding');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(controller.isRunning, isFalse);
      expect(storage.completed, contains('onboarding'));
    });

    testWidgets('a declared length is used before every target registers',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        threeStepApp(
          controller: controller,
          tourLengths: const <String, int>{'onboarding': 5},
        ),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('Tour.of starts a tour from the tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TourScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => Tour.read(context).start('onboarding'),
                      child: const Text('start'),
                    ),
                    const HintTarget(
                      tour: 'onboarding',
                      order: 1,
                      title: 'Only step',
                      child: Text('target'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text('Only step'), findsOneWidget);
    });

    testWidgets('a tour already marked completed does not start',
        (WidgetTester tester) async {
      final RecordingStorage storage = RecordingStorage()
        ..completed.add('onboarding');
      final TourController controller = TourController(storage: storage);
      addTearDown(controller.dispose);
      await tester.pumpWidget(threeStepApp(controller: controller));
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
    });

    testWidgets('custom content replaces the default card',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: controller,
          child: MaterialApp(
            home: Scaffold(
              body: HintTarget(
                tour: 'onboarding',
                order: 1,
                title: 'ignored',
                contentBuilder: (BuildContext context, TourStepInfo info) =>
                    Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('custom ${info.step}/${info.length}'),
                    TextButton(
                      onPressed: info.controller.finish,
                      child: const Text('close'),
                    ),
                  ],
                ),
                child: const Text('target'),
              ),
            ),
          ),
        ),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('custom 1/1'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(controller.isRunning, isFalse);
    });
  });

  group('passthrough hit-testing', () {
    testWidgets('a modal step swallows a tap on the target',
        (WidgetTester tester) async {
      int taps = 0;
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        threeStepApp(controller: controller, onSecondTap: () => taps++),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);

      await tester.tap(find.text('two'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'the scrim is modal');
    });

    testWidgets('a passthrough step lets a real tap reach the target',
        (WidgetTester tester) async {
      int taps = 0;
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        threeStepApp(
          controller: controller,
          passthroughSecond: true,
          onSecondTap: () => taps++,
        ),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('two'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'passthrough must be a real hit-test change');
    });

    testWidgets('a passthrough step still blocks taps outside the hole',
        (WidgetTester tester) async {
      int taps = 0;
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        threeStepApp(
          controller: controller,
          passthroughSecond: true,
          onSecondTap: () => taps++,
        ),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // A corner of the screen, far from the spotlight.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(controller.isRunning, isTrue);
    });

    testWidgets('the blocker reports hitTestSelf per position',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Spotlight(
            holeRect: Rect.fromLTWH(100, 100, 100, 100),
            shape: SpotlightShape.rect,
            borderRadius: BorderRadius.zero,
            color: Color(0x99000000),
            passthrough: true,
          ),
        ),
      );
      final RenderSpotlightBlocker blocker = tester.allRenderObjects
          .whereType<RenderSpotlightBlocker>()
          .toSet()
          .single;
      expect(blocker.hitTestSelf(const Offset(150, 150)), isFalse);
      expect(blocker.hitTestSelf(const Offset(50, 50)), isTrue);
    });

    testWidgets('a modal blocker claims every position',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Spotlight(
            holeRect: Rect.fromLTWH(100, 100, 100, 100),
            shape: SpotlightShape.rect,
            borderRadius: BorderRadius.zero,
            color: Color(0x99000000),
          ),
        ),
      );
      final RenderSpotlightBlocker blocker = tester.allRenderObjects
          .whereType<RenderSpotlightBlocker>()
          .toSet()
          .single;
      expect(blocker.hitTestSelf(const Offset(150, 150)), isTrue);
      expect(blocker.hitTestSelf(const Offset(50, 50)), isTrue);
    });
  });

  group('spotlight shapes', () {
    test('rect and roundedRect bound the target', () {
      const Rect target = Rect.fromLTWH(10, 20, 100, 50);
      expect(
        SpotlightShape.rect.toPath(target, BorderRadius.zero).getBounds(),
        target,
      );
      expect(
        SpotlightShape.roundedRect
            .toPath(target, BorderRadius.circular(8))
            .getBounds(),
        target,
      );
    });

    test('circle encloses the target rather than cropping it', () {
      const Rect target = Rect.fromLTWH(0, 0, 100, 40);
      final Rect bounds =
          SpotlightShape.circle.toPath(target, BorderRadius.zero).getBounds();
      expect(bounds.width, closeTo(100, 0.01));
      expect(bounds.height, closeTo(100, 0.01));
      expect(bounds.center, target.center);
    });

    test('oval is inscribed in the target', () {
      const Rect target = Rect.fromLTWH(0, 0, 100, 40);
      expect(
        SpotlightShape.oval.toPath(target, BorderRadius.zero).getBounds(),
        target,
      );
    });

    test('custom builds whatever it is told to', () {
      final SpotlightShape shape = SpotlightShape.custom(
        (Rect r) => Path()..addRect(r.deflate(10)),
      );
      expect(
        shape
            .toPath(const Rect.fromLTWH(0, 0, 100, 100), BorderRadius.zero)
            .getBounds(),
        const Rect.fromLTWH(10, 10, 80, 80),
      );
    });

    test('constants compare equal', () {
      expect(SpotlightShape.circle, SpotlightShape.circle);
      expect(SpotlightShape.circle, isNot(SpotlightShape.rect));
      expect(
        SpotlightShape.circle.hashCode,
        SpotlightShape.circle.hashCode,
      );
    });
  });

  group('cross-route tours', () {
    testWidgets('a step waits for a target on another route',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        TourScope(
          controller: controller,
          tourLengths: const <String, int>{'onboarding': 2},
          child: MaterialApp(
            navigatorKey: nav,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  const HintTarget(
                    tour: 'onboarding',
                    order: 1,
                    title: 'On page one',
                    child: Text('first target'),
                  ),
                  Builder(
                    builder: (BuildContext context) => ElevatedButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => const Scaffold(
                            body: HintTarget(
                              tour: 'onboarding',
                              order: 2,
                              title: 'On page two',
                              child: Text('second target'),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('go'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('On page one'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);

      // Advance to a step whose target does not exist yet.
      controller.next();
      await tester.pumpAndSettle();
      expect(find.text('On page one'), findsNothing);
      expect(find.text('On page two'), findsNothing);
      expect(
        controller.isRunning,
        isTrue,
        reason: 'the tour waits rather than skipping or crashing',
      );

      // Navigating to the route resumes the tour on that step.
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('On page two'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
    });
  });

  group('scrolling', () {
    testWidgets('a step below the fold is scrolled into view',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        TourScope(
          controller: controller,
          child: MaterialApp(
            home: Scaffold(
              // A non-lazy scroll view: the target below the fold is built,
              // just not visible. A lazily-built target that has never been
              // created has not registered with the scope, so there is nothing
              // to scroll to — see HintTarget's documentation.
              body: SingleChildScrollView(
                controller: scroll,
                child: const Column(
                  children: <Widget>[
                    SizedBox(height: 1200),
                    HintTarget(
                      tour: 'onboarding',
                      order: 1,
                      title: 'Down here',
                      child: SizedBox(
                        width: 120,
                        height: 40,
                        child: Text('deep target'),
                      ),
                    ),
                    SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(scroll.offset, 0);

      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(find.text('Down here'), findsOneWidget);
      expect(find.text('deep target'), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('arrows move, enter advances and escape skips',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(threeStepApp(controller: controller));
      await controller.start('onboarding');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.index, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.index, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.index, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isRunning, isFalse);
    });

    testWidgets('shortcuts can be turned off', (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: controller,
          enableKeyboardShortcuts: false,
          child: const MaterialApp(
            home: Scaffold(
              body: HintTarget(
                tour: 'onboarding',
                order: 1,
                title: 'Only',
                child: Text('target'),
              ),
            ),
          ),
        ),
      );
      await controller.start('onboarding');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isRunning, isTrue);
    });
  });

  group('interaction with tooltips', () {
    testWidgets('starting a tour closes an open hint',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: controller,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  Hint(
                    message: 'a tooltip',
                    triggers: <HintTrigger>{HintTrigger.onAppear},
                    dismissOnTapOutside: false,
                    child: Text('hint target'),
                  ),
                  HintTarget(
                    tour: 'onboarding',
                    order: 1,
                    title: 'Step one',
                    child: Text('tour target'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('a tooltip'), findsOneWidget);

      await controller.start('onboarding');
      await tester.pumpAndSettle();
      expect(find.text('Step one'), findsOneWidget);
      expect(find.text('a tooltip'), findsNothing);
    });
  });

  group('errors', () {
    testWidgets('a HintTarget without a scope explains itself',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HintTarget(
              tour: 'onboarding',
              order: 1,
              title: 'Orphan',
              child: Text('target'),
            ),
          ),
        ),
      );
      final Object? error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('TourScope'));
      Object? next = tester.takeException();
      while (next != null) {
        next = tester.takeException();
      }
    });
  });
}
