import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Records everything it is told, in order.
class RecordingObserver extends HintObserver {
  final List<String> events = <String>[];
  final List<HintEvent> shown = <HintEvent>[];

  @override
  void didShowHint(HintEvent event) {
    events.add('show:${event.id ?? event.label}');
    shown.add(event);
  }

  @override
  void didDismissHint(HintEvent event) =>
      events.add('dismiss:${event.id ?? event.label}');

  @override
  void didStartTour(String tour) => events.add('tour-start:$tour');

  @override
  void didChangeTourStep(String tour, int index) =>
      events.add('tour-step:$tour:$index');

  @override
  void didEndTour(String tour, TourEndReason reason) =>
      events.add('tour-end:$tour:${reason.name}');
}

/// An in-memory store that also counts writes.
class CountingStorage extends InMemoryTourStorage {
  int writes = 0;

  @override
  Future<void> markCompleted(String tour) {
    writes++;
    return super.markCompleted(tour);
  }
}

Future<void> pumpHint(
  WidgetTester tester,
  Widget hint, {
  Key? appKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: appKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: hint)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late RecordingObserver observer;

  setUp(() {
    observer = RecordingObserver();
    HintRegistry.instance.addObserver(observer);
    // Every test starts from a clean slate: the registry is process-global on
    // purpose, so it outlives a widget tree and would otherwise leak between
    // cases.
    HintRegistry.instance.storage = InMemoryTourStorage();
  });

  tearDown(() {
    HintRegistry.instance.removeObserver(observer);
    HintRegistry.instance.closeAll();
    HintRegistry.instance.storage = InMemoryTourStorage();
  });

  group('observer', () {
    testWidgets('reports a show and a dismiss', (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpHint(
        tester,
        Hint(
          controller: controller,
          triggers: const <HintTrigger>{HintTrigger.manual},
          analyticsId: 'check-in',
          message: 'Check in here',
          child: const SizedBox(width: 60, height: 30),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      controller.hide();
      await tester.pumpAndSettle();

      expect(observer.events, <String>['show:check-in', 'dismiss:check-in']);
    });

    testWidgets('carries the trigger that opened the hint',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.tap},
          message: 'Check in here',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      await tester.tap(find.byType(SizedBox).first);
      await tester.pumpAndSettle();

      expect(observer.shown.single.trigger, HintTrigger.tap);
      expect(observer.shown.single.label, 'Check in here');
      expect(observer.shown.single.id, isNull);
    });

    testWidgets('falls back to the hint text when there is no id',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.onAppear},
          title: 'Check in',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      expect(observer.events, contains('show:Check in'));
    });

    testWidgets('a removed observer hears nothing more',
        (WidgetTester tester) async {
      HintRegistry.instance.removeObserver(observer);
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Check in here',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      expect(observer.events, isEmpty);
    });

    testWidgets('reports the whole tour lifecycle',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: tour,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  HintTarget(
                    tour: 'onboarding',
                    order: 1,
                    title: 'One',
                    child: SizedBox(width: 60, height: 30),
                  ),
                  HintTarget(
                    tour: 'onboarding',
                    order: 2,
                    title: 'Two',
                    child: SizedBox(width: 60, height: 30),
                  ),
                ],
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
      tour.next();
      await tester.pumpAndSettle();

      expect(observer.events, <String>[
        'tour-start:onboarding',
        'tour-step:onboarding:0',
        'tour-step:onboarding:1',
        'tour-end:onboarding:finished',
      ]);
    });
  });

  group('showOnce', () {
    testWidgets('shows the first time and never again',
        (WidgetTester tester) async {
      Widget build(String key) => MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Hint(
                  key: ValueKey<String>(key),
                  showOnce: 'payslip-tip',
                  triggers: const <HintTrigger>{HintTrigger.onAppear},
                  message: 'Payslips live here now',
                  child: const SizedBox(width: 60, height: 30),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build('first'));
      await tester.pumpAndSettle();
      expect(find.text('Payslips live here now'), findsOneWidget);

      // A completely fresh hint under the same key: the flag is in storage,
      // not in the widget.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(build('second'));
      await tester.pumpAndSettle();
      expect(find.text('Payslips live here now'), findsNothing);
      expect(
        observer.events.where((String e) => e.startsWith('show:')).length,
        1,
      );
    });

    testWidgets('blocks a controller too', (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpHint(
        tester,
        Hint(
          controller: controller,
          showOnce: 'saved-tip',
          triggers: const <HintTrigger>{HintTrigger.manual},
          message: 'Saved',
          child: const SizedBox(width: 60, height: 30),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      controller.hide();
      await tester.pumpAndSettle();

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      // The controller is told the truth rather than being left thinking a
      // bubble is open.
      expect(controller.isShown, isFalse);
    });

    testWidgets('records the key once, as the bubble opens',
        (WidgetTester tester) async {
      final CountingStorage storage = CountingStorage();
      HintRegistry.instance.storage = storage;
      await pumpHint(
        tester,
        const Hint(
          showOnce: 'tip',
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Once',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      expect(storage.writes, 1);
      expect(await storage.isCompleted('tip'), isTrue);
    });

    testWidgets('resetShowOnce lets it appear again',
        (WidgetTester tester) async {
      Widget build(String key) => MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Hint(
                  key: ValueKey<String>(key),
                  showOnce: 'tip',
                  triggers: const <HintTrigger>{HintTrigger.onAppear},
                  message: 'Once',
                  child: const SizedBox(width: 60, height: 30),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build('a'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      await HintRegistry.instance.resetShowOnce('tip');
      await tester.pumpWidget(build('b'));
      await tester.pumpAndSettle();
      expect(find.text('Once'), findsOneWidget);
    });

    testWidgets('resetShowOnce re-arms a hint that is still on screen',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpHint(
        tester,
        Hint(
          controller: controller,
          showOnce: 'whats-new',
          triggers: const <HintTrigger>{HintTrigger.manual},
          message: 'Once',
          child: const SizedBox(width: 60, height: 30),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      controller.hide();
      await tester.pumpAndSettle();
      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Once'), findsNothing);

      // A "show it again" button pressed on the screen the hint lives on:
      // nothing is rebuilt, so clearing storage alone would leave the flag
      // cached in the state and the hint silent until the next launch.
      await HintRegistry.instance.resetShowOnce('whats-new');
      await tester.pumpAndSettle();
      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Once'), findsOneWidget);
    });

    testWidgets('a reset for another key leaves this hint blocked',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpHint(
        tester,
        Hint(
          controller: controller,
          showOnce: 'whats-new',
          triggers: const <HintTrigger>{HintTrigger.manual},
          message: 'Once',
          child: const SizedBox(width: 60, height: 30),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      controller.hide();
      await tester.pumpAndSettle();

      await HintRegistry.instance.resetShowOnce('some-other-key');
      await tester.pumpAndSettle();
      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Once'), findsNothing);
    });

    testWidgets('a new key is read afresh', (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      Widget build(String showOnce) => MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Hint(
                  controller: controller,
                  showOnce: showOnce,
                  triggers: const <HintTrigger>{HintTrigger.manual},
                  message: 'Once',
                  child: const SizedBox(width: 60, height: 30),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build('first-key'));
      controller.show();
      await tester.pumpAndSettle();
      controller.hide();
      await tester.pumpAndSettle();

      // Same state, different key: what was recorded for the old one says
      // nothing about this one.
      await tester.pumpWidget(build('second-key'));
      await tester.pumpAndSettle();
      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Once'), findsOneWidget);
    });

    testWidgets('a hint without a key is never blocked',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Always',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      expect(find.text('Always'), findsOneWidget);
    });

    testWidgets('the event carries the key', (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          showOnce: 'tip',
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Once',
          child: SizedBox(width: 60, height: 30),
        ),
      );
      expect(observer.shown.single.showOnce, 'tip');
    });
  });

  group('CallbackTourStorage', () {
    test('reads and writes through the callbacks', () async {
      final Map<String, bool> store = <String, bool>{};
      final CallbackTourStorage storage = CallbackTourStorage(
        isCompleted: (String tour) async => store[tour] ?? false,
        setCompleted: (String tour, bool completed) async =>
            store[tour] = completed,
      );

      expect(await storage.isCompleted('onboarding'), isFalse);
      await storage.markCompleted('onboarding');
      expect(store['onboarding'], isTrue);
      expect(await storage.isCompleted('onboarding'), isTrue);
      await storage.reset('onboarding');
      expect(store['onboarding'], isFalse);
      expect(await storage.isCompleted('onboarding'), isFalse);
    });

    testWidgets('drives a tour like any other storage',
        (WidgetTester tester) async {
      final Map<String, bool> store = <String, bool>{'onboarding': true};
      final TourController tour = TourController(
        storage: CallbackTourStorage(
          isCompleted: (String t) async => store[t] ?? false,
          setCompleted: (String t, bool done) async => store[t] = done,
        ),
      );
      addTearDown(tour.dispose);

      // Already completed, so start does nothing.
      await tour.start('onboarding');
      expect(tour.isRunning, isFalse);

      await tour.start('onboarding', force: true);
      expect(tour.isRunning, isTrue);
    });
  });
}
