import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit/testing.dart';

/// Three manual hints in a row, each driven by its own controller.
Widget threeTips(List<HintController> controllers, {int count = 3}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Hint(
              controller: controllers[i],
              triggers: const <HintTrigger>{HintTrigger.manual},
              message: 'Tip ${i + 1}',
              child: const SizedBox(width: 80, height: 40),
            ),
        ],
      ),
    ),
  );
}

void main() {
  setUp(resetHintKit);

  late List<HintController> controllers;

  setUp(() {
    controllers = List<HintController>.generate(3, (_) => HintController());
  });

  tearDown(() {
    for (final HintController controller in controllers) {
      controller.dispose();
    }
  });

  testWidgets('shows each hint in turn as the last is dismissed',
      (WidgetTester tester) async {
    final HintQueue queue = HintQueue(controllers, gap: Duration.zero);
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    expect(find.text('Tip 1'), findsOneWidget);
    expect(find.text('Tip 2'), findsNothing);

    controllers[0].hide();
    await tester.pumpAndSettle();
    expect(find.text('Tip 1'), findsNothing);
    expect(find.text('Tip 2'), findsOneWidget);

    controllers[1].hide();
    await tester.pumpAndSettle();
    expect(find.text('Tip 3'), findsOneWidget);
    expect(queue.isRunning, isTrue);

    controllers[2].hide();
    await tester.pumpAndSettle();
    expect(queue.isRunning, isFalse);
    expect(find.text('Tip 3'), findsNothing);
  });

  testWidgets('a dismissal by the user advances it too',
      (WidgetTester tester) async {
    final HintQueue queue = HintQueue(controllers, gap: Duration.zero);
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    // A tap outside dismisses the bubble; the queue must notice.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Tip 2'), findsOneWidget);
    queue.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('waits out the gap between hints', (WidgetTester tester) async {
    final HintQueue queue = HintQueue(
      controllers,
      gap: const Duration(milliseconds: 400),
    );
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    // The first opens immediately: waiting before the first tip would look
    // like nothing happened.
    expect(find.text('Tip 1'), findsOneWidget);

    controllers[0].hide();
    await tester.pumpAndSettle();
    expect(find.text('Tip 2'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Tip 2'), findsOneWidget);
    queue.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('next() skips ahead', (WidgetTester tester) async {
    final HintQueue queue = HintQueue(controllers, gap: Duration.zero);
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    queue.next();
    await tester.pumpAndSettle();
    expect(find.text('Tip 2'), findsOneWidget);
    expect(queue.index, 1);
    queue.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('stop() closes what is open and reports incomplete',
      (WidgetTester tester) async {
    bool? result;
    final HintQueue queue = HintQueue(
      controllers,
      gap: Duration.zero,
      onFinished: ({required bool completed}) => result = completed,
    );
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    queue.stop();
    await tester.pumpAndSettle();

    expect(find.text('Tip 1'), findsNothing);
    expect(queue.isRunning, isFalse);
    expect(result, isFalse);
  });

  testWidgets('reports completion when every hint has been shown',
      (WidgetTester tester) async {
    bool? result;
    final HintQueue queue = HintQueue(
      controllers,
      gap: Duration.zero,
      onFinished: ({required bool completed}) => result = completed,
    );
    addTearDown(queue.dispose);
    await tester.pumpWidget(threeTips(controllers));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    for (final HintController controller in controllers) {
      controller.hide();
      await tester.pumpAndSettle();
    }
    expect(result, isTrue);
  });

  testWidgets('stops when a hint has no mounted widget',
      (WidgetTester tester) async {
    bool? result;
    final HintQueue queue = HintQueue(
      controllers,
      gap: Duration.zero,
      onFinished: ({required bool completed}) => result = completed,
    );
    addTearDown(queue.dispose);
    // Only two of the three hints exist in the tree.
    await tester.pumpWidget(threeTips(controllers, count: 2));
    await tester.pumpAndSettle();

    queue.start();
    await tester.pumpAndSettle();
    controllers[0].hide();
    await tester.pumpAndSettle();
    controllers[1].hide();
    await tester.pumpAndSettle();

    expect(queue.isRunning, isFalse);
    expect(result, isFalse);
  });

  test('start() is a no-op while already running', () {
    final HintQueue queue = HintQueue(controllers, gap: Duration.zero);
    addTearDown(queue.dispose);
    queue.start();
    final int index = queue.index;
    queue.start();
    expect(queue.index, index);
  });

  test('notifies listeners as it advances', () async {
    int notifications = 0;
    final HintQueue queue = HintQueue(controllers, gap: Duration.zero)
      ..addListener(() => notifications++);
    addTearDown(queue.dispose);
    queue.start();
    expect(notifications, greaterThan(0));
  });
}
