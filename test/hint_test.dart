import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Pumps [child] inside an app with an overlay, at a fixed size.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  MediaQueryData media = const MediaQueryData(size: Size(800, 600)),
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? widget) => MediaQuery(
        data: media,
        child: Directionality(
          textDirection: textDirection,
          child: widget ?? const SizedBox(),
        ),
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Simulates a long press with raw pointer events, the way a real device does.
Future<void> longPress(WidgetTester tester, Finder finder) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Moves a synthetic mouse onto [finder] and returns the gesture so the caller
/// can move it away again.
Future<TestGesture> hoverOver(WidgetTester tester, Finder finder) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return mouse;
}

void main() {
  group('triggers', () {
    testWidgets('long press shows and a second long press hides',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          child: Text('target'),
        ),
      );
      expect(find.text('Check in here'), findsNothing);

      await longPress(tester, find.text('target'));
      expect(find.text('Check in here'), findsOneWidget);

      await longPress(tester, find.text('target'));
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('a tap does not show a long-press hint',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.longPress},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('moving the finger past the slop cancels the long press',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.longPress},
          child: Text('target'),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('target')),
      );
      await gesture.moveBy(const Offset(kTouchSlop + 10, 0));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('tap toggles', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);

      await tester.tap(find.text('target'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('hover shows and unhover hides', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.hover},
          child: SizedBox(width: 100, height: 40, child: Text('target')),
        ),
      );
      final TestGesture mouse = await hoverOver(tester, find.text('target'));
      expect(find.text('Check in here'), findsOneWidget);

      await mouse.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('hover respects waitDuration', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.hover},
          waitDuration: Duration(milliseconds: 500),
          child: SizedBox(width: 100, height: 40, child: Text('target')),
        ),
      );
      await hoverOver(tester, find.text('target'));
      expect(find.text('Check in here'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('leaving before waitDuration elapses shows nothing',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.hover},
          waitDuration: Duration(milliseconds: 500),
          child: SizedBox(width: 100, height: 40, child: Text('target')),
        ),
      );
      final TestGesture mouse = await hoverOver(tester, find.text('target'));
      await tester.pump(const Duration(milliseconds: 200));
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('focus shows and blur hides', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          triggers: const <HintTrigger>{HintTrigger.focus},
          child: TextField(focusNode: node),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);

      node.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('onAppear shows without any interaction',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.onAppear},
          child: Text('target'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('manual ignores every gesture', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.manual},
          child: Text('target'),
        ),
      );
      await longPress(tester, find.text('target'));
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });
  });

  group('disabled and non-interactive children', () {
    testWidgets('shows on ElevatedButton(onPressed: null)',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'You need an active shift to check in',
          child: ElevatedButton(onPressed: null, child: Text('Check in')),
        ),
      );
      // The button is disabled: it ignores the gesture entirely.
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
        isFalse,
      );

      await longPress(tester, find.text('Check in'));
      expect(
        find.text('You need an active shift to check in'),
        findsOneWidget,
      );
    });

    testWidgets('does not steal the tap from an enabled child',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          triggers: const <HintTrigger>{HintTrigger.longPress},
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('Check in'),
          ),
        ),
      );
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the hint must not enter the gesture arena');
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('a long press on an enabled child still opens the hint',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          child: ElevatedButton(
            onPressed: () => taps++,
            child: const Text('Check in'),
          ),
        ),
      );
      await longPress(tester, find.text('Check in'));
      expect(find.text('Check in here'), findsOneWidget);
      // The button still fires: Flutter's TapGestureRecognizer has no upper
      // time bound, so a long press followed by a release is also a tap. The
      // hint changes nothing about that, which is the point — it stays out of
      // the arena entirely.
      expect(taps, 1);
    });

    testWidgets('shows on an IgnorePointer *inside* the hint',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          child: IgnorePointer(
            child: SizedBox(width: 120, height: 48, child: Text('target')),
          ),
        ),
      );
      await longPress(tester, find.text('target'));
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('cannot show under an ancestor IgnorePointer — documented',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const IgnorePointer(
          child: Hint(
            message: 'Check in here',
            child: SizedBox(width: 120, height: 48, child: Text('target')),
          ),
        ),
      );
      await longPress(tester, find.text('target'));
      expect(
        find.text('Check in here'),
        findsNothing,
        reason: 'this is the known limitation called out in the README',
      );
    });

    testWidgets('absorbChildInput covers a child that does not hit-test',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          absorbChildInput: true,
          child: SizedBox(width: 120, height: 48),
        ),
      );
      await longPress(tester, find.byType(SizedBox).first);
      expect(find.text('Check in here'), findsOneWidget);
    });
  });

  group('controller', () {
    testWidgets('show, hide and toggle drive the bubble',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          controller: controller,
          triggers: const <HintTrigger>{HintTrigger.manual},
          child: const Text('target'),
        ),
      );

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
      expect(controller.isShown, isTrue);

      controller.hide();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('reports a dismissal it did not initiate',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          controller: controller,
          triggers: const <HintTrigger>{HintTrigger.tap},
          child: const Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(controller.isShown, isTrue);

      // Tap outside.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(controller.isShown, isFalse);
    });

    testWidgets('knows when it is attached', (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      expect(controller.isAttached, isFalse);
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          controller: controller,
          child: const Text('target'),
        ),
      );
      expect(controller.isAttached, isTrue);

      await pumpApp(tester, const SizedBox());
      expect(controller.isAttached, isFalse);
    });

    testWidgets('refresh re-measures without closing',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          controller: controller,
          triggers: const <HintTrigger>{HintTrigger.manual},
          child: const Text('target'),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can be handed to a second hint once the first is gone',
        (WidgetTester tester) async {
      // Mounting two hints on one controller asserts (see HintController); the
      // guard must not fire on the legitimate case of reusing a controller
      // after the first hint has been disposed.
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpApp(
        tester,
        Hint(message: 'one', controller: controller, child: const Text('a')),
      );
      expect(controller.isAttached, isTrue);

      await pumpApp(
        tester,
        Hint(message: 'two', controller: controller, child: const Text('b')),
      );
      expect(controller.isAttached, isTrue);
      expect(tester.takeException(), isNull);

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    });
  });

  group('dismissal', () {
    testWidgets('a tap outside dismisses by default',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('dismissOnTapOutside: false keeps it open',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          dismissOnTapOutside: false,
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('a transparent barrier lets the tap through to the app',
        (WidgetTester tester) async {
      int outsideTaps = 0;
      await pumpApp(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Hint(
              message: 'Check in here',
              triggers: <HintTrigger>{HintTrigger.tap},
              child: Text('target'),
            ),
            GestureDetector(
              onTap: () => outsideTaps++,
              child: const SizedBox(width: 100, height: 40, child: Text('out')),
            ),
          ],
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('out'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(outsideTaps, 1, reason: 'a hover tooltip must not eat clicks');
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('a coloured barrier is modal and absorbs the tap',
        (WidgetTester tester) async {
      int outsideTaps = 0;
      await pumpApp(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Hint(
              message: 'Check in here',
              triggers: <HintTrigger>{HintTrigger.tap},
              barrierColor: Color(0x66000000),
              child: Text('target'),
            ),
            GestureDetector(
              onTap: () => outsideTaps++,
              child: const SizedBox(width: 100, height: 40, child: Text('out')),
            ),
          ],
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('out'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(outsideTaps, 0);
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('escape dismisses', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('showDuration auto-hides', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.onAppear},
          showDuration: Duration(seconds: 2),
          child: Text('target'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
    });

    testWidgets('showDuration is ignored under accessible navigation',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.onAppear},
          showDuration: Duration(seconds: 2),
          child: Text('target'),
        ),
        media: const MediaQueryData(
          size: Size(800, 600),
          accessibleNavigation: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Check in here'),
        findsOneWidget,
        reason: 'a screen-reader user cannot read a bubble that self-destructs',
      );
    });

    testWidgets('popping the route takes the bubble with it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const Scaffold(
                        body: Center(
                          child: Hint(
                            message: 'Check in here',
                            triggers: <HintTrigger>{HintTrigger.onAppear},
                            child: Text('target'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('push'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsOneWidget);

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Check in here'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('exclusivity', () {
    testWidgets('opening one hint closes another', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Hint(
              message: 'first',
              triggers: <HintTrigger>{HintTrigger.tap},
              dismissOnTapOutside: false,
              child: Text('a'),
            ),
            Hint(
              message: 'second',
              triggers: <HintTrigger>{HintTrigger.tap},
              dismissOnTapOutside: false,
              child: Text('b'),
            ),
          ],
        ),
      );
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    });

    testWidgets('a non-exclusive hint survives another opening',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Hint(
              message: 'pinned',
              triggers: <HintTrigger>{HintTrigger.onAppear},
              exclusive: false,
              dismissOnTapOutside: false,
              child: Text('a'),
            ),
            Hint(
              message: 'transient',
              triggers: <HintTrigger>{HintTrigger.tap},
              dismissOnTapOutside: false,
              child: Text('b'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pinned'), findsOneWidget);

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(find.text('transient'), findsOneWidget);
      expect(find.text('pinned'), findsOneWidget);
    });
  });

  group('placement in a real tree', () {
    testWidgets('a target at the top gets a bubble below it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Hint(
                message: 'below',
                triggers: <HintTrigger>{HintTrigger.onAppear},
                child: SizedBox(width: 80, height: 40, child: Text('target')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('below')).dy,
        greaterThan(tester.getCenter(find.text('target')).dy),
      );
    });

    testWidgets('a target at the bottom gets a bubble above it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Hint(
                message: 'above',
                triggers: <HintTrigger>{HintTrigger.onAppear},
                child: SizedBox(width: 80, height: 40, child: Text('target')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('above')).dy,
        lessThan(tester.getCenter(find.text('target')).dy),
      );
    });

    testWidgets('the bubble stays on screen for a corner target',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Hint(
                message: 'a hint long enough to need most of the screen width',
                triggers: <HintTrigger>{HintTrigger.onAppear},
                child: SizedBox(width: 40, height: 40, child: Text('target')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect bubble = tester.getRect(
        find.text('a hint long enough to need most of the screen width'),
      );
      expect(bubble.left, greaterThanOrEqualTo(0));
      expect(bubble.top, greaterThanOrEqualTo(0));
      expect(bubble.right, lessThanOrEqualTo(800));
    });

    testWidgets('the bubble follows the target through a scroll',
        (WidgetTester tester) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: <Widget>[
                const SizedBox(height: 300),
                const Hint(
                  message: 'follow me',
                  triggers: <HintTrigger>{HintTrigger.onAppear},
                  dismissOnTapOutside: false,
                  child: SizedBox(width: 80, height: 40, child: Text('target')),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final double before = tester.getCenter(find.text('target')).dy -
          tester.getCenter(find.text('follow me')).dy;

      scroll.jumpTo(150);
      await tester.pumpAndSettle();
      final double after = tester.getCenter(find.text('target')).dy -
          tester.getCenter(find.text('follow me')).dy;
      expect(after, closeTo(before, 1));
    });
  });

  group('content', () {
    testWidgets('contentBuilder renders arbitrary widgets',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        Hint(
          triggers: const <HintTrigger>{HintTrigger.onAppear},
          contentBuilder: (BuildContext context) => const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[Icon(Icons.info), Text('rich')],
          ),
          child: const Text('target'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('rich'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('an interactive bubble can be tapped',
        (WidgetTester tester) async {
      int pressed = 0;
      await pumpApp(
        tester,
        Hint(
          triggers: const <HintTrigger>{HintTrigger.onAppear},
          interactive: true,
          dismissOnTapOutside: false,
          contentBuilder: (BuildContext context) => TextButton(
            onPressed: () => pressed++,
            child: const Text('Learn more'),
          ),
          child: const Text('target'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn more'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('a non-interactive bubble ignores pointers',
        (WidgetTester tester) async {
      int pressed = 0;
      await pumpApp(
        tester,
        Hint(
          triggers: const <HintTrigger>{HintTrigger.onAppear},
          dismissOnTapOutside: false,
          contentBuilder: (BuildContext context) => TextButton(
            onPressed: () => pressed++,
            child: const Text('Learn more'),
          ),
          child: const Text('target'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn more'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pressed, 0);
    });

    testWidgets('asserts when given both a message and a contentBuilder',
        (WidgetTester tester) async {
      expect(
        () => Hint(
          message: 'a',
          contentBuilder: (BuildContext context) => const Text('b'),
          child: const Text('target'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('callbacks', () {
    testWidgets('onShow and onDismiss fire exactly once each',
        (WidgetTester tester) async {
      int shows = 0;
      int dismisses = 0;
      await pumpApp(
        tester,
        Hint(
          message: 'Check in here',
          triggers: const <HintTrigger>{HintTrigger.tap},
          onShow: () => shows++,
          onDismiss: () => dismisses++,
          child: const Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(shows, 1);
      expect(dismisses, 0);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(shows, 1);
      expect(dismisses, 1);
    });
  });

  group('accessibility', () {
    testWidgets('the target carries a semantic tooltip',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Hint(
          message: 'You need an active shift',
          child: Text('target'),
        ),
      );
      expect(
        tester.getSemantics(find.text('target')),
        matchesSemantics(
          label: 'target',
          tooltip: 'You need an active shift',
          hasEnabledState: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('excludeFromSemantics drops the tooltip',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Hint(
          message: 'You need an active shift',
          excludeFromSemantics: true,
          child: Text('target'),
        ),
      );
      expect(
        tester.getSemantics(find.text('target')).tooltip,
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('the open bubble is a live region reading title and message',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Hint(
          title: 'Shifts',
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      // The bubble stands in for its own text — one node, spoken as it
      // arrives, and still there to be read afterwards.
      expect(
        tester.getSemantics(find.text('Check in here')),
        matchesSemantics(label: 'Shifts\nCheck in here', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('semanticsLabel replaces the text the bubble reads out',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          semanticsLabel: 'Check in to start your shift',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Check in here')),
        matchesSemantics(
          label: 'Check in to start your shift',
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('excludeFromSemantics leaves the bubble a plain text node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          excludeFromSemantics: true,
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      // matchesSemantics asserts every flag it is not given is false, so this
      // is the assertion that nothing is announced.
      expect(
        tester.getSemantics(find.text('Check in here')),
        matchesSemantics(label: 'Check in here'),
      );
      handle.dispose();
    });

    testWidgets('rich content keeps its own semantics and says nothing',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        Hint(
          contentBuilder: (BuildContext context) => const Text('rich'),
          triggers: const <HintTrigger>{HintTrigger.tap},
          child: const Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('rich')),
        matchesSemantics(label: 'rich'),
      );
      handle.dispose();
    });

    testWidgets('rich content is announced when semanticsLabel is given',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        Hint(
          contentBuilder: (BuildContext context) => const Text('rich'),
          semanticsLabel: 'Two shifts need attention',
          triggers: const <HintTrigger>{HintTrigger.tap},
          child: const Text('target'),
        ),
      );
      await tester.tap(find.text('target'));
      await tester.pumpAndSettle();
      // The label announces; the content below it stays readable, because it
      // can hold buttons of its own.
      expect(
        tester.getSemantics(find.text('rich')),
        matchesSemantics(label: 'rich'),
      );
      expect(
        find.bySemanticsLabel('Two shifts need attention'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('appears instantly when animations are disabled',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Hint(
          message: 'Check in here',
          triggers: <HintTrigger>{HintTrigger.tap},
          child: Text('target'),
        ),
        media: const MediaQueryData(
          size: Size(800, 600),
          disableAnimations: true,
        ),
      );
      await tester.tap(find.text('target'));
      // A single pump, with no time passing: no animation may be pending.
      await tester.pump();
      await tester.pump();
      expect(find.text('Check in here'), findsOneWidget);
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Check in here'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
    });
  });
}
