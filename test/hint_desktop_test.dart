import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit/testing.dart';

/// Pumps [hint] centred in a fixed-size app.
Future<void> pumpHint(WidgetTester tester, Widget hint) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: hint)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Adds a synthetic mouse and returns it, ready to move.
Future<TestGesture> mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

void main() {
  setUp(resetHintKit);

  group('secondaryTap', () {
    testWidgets('a right-click opens and the next one closes',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.secondaryTap},
          message: 'Right-clicked',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      final Offset centre = tester.getCenter(find.byType(SizedBox).first);

      final TestGesture click = await tester.startGesture(
        centre,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      expect(find.text('Right-clicked'), findsOneWidget);

      final TestGesture second = await tester.startGesture(
        centre,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('Right-clicked'), findsNothing);
    });

    testWidgets('a primary click does not open it',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.secondaryTap},
          message: 'Right-clicked',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      await tester.tap(find.byType(SizedBox).first);
      await tester.pumpAndSettle();
      expect(find.text('Right-clicked'), findsNothing);
    });

    testWidgets('a right-click does not open a tap hint',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.tap},
          message: 'Tapped',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      final TestGesture click = await tester.startGesture(
        tester.getCenter(find.byType(SizedBox).first),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      expect(find.text('Tapped'), findsNothing);
    });

    testWidgets('the observer is told which button opened it',
        (WidgetTester tester) async {
      final RecordingHintObserver observer = RecordingHintObserver();
      HintRegistry.instance.addObserver(observer);
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.secondaryTap},
          message: 'Right-clicked',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      final TestGesture click = await tester.startGesture(
        tester.getCenter(find.byType(SizedBox).first),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      expect(observer.shown.single.trigger, HintTrigger.secondaryTap);
    });
  });

  group('mouseCursor', () {
    testWidgets('is applied to the target', (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          mouseCursor: SystemMouseCursors.help,
          message: 'Explains itself',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(tester.getCenter(find.byType(SizedBox).first));
      await tester.pumpAndSettle();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.help,
      );
    });

    testWidgets('defers to the child when unset', (WidgetTester tester) async {
      /// The cursor over a text button, with and without a hint around it.
      Future<MouseCursor?> cursorOver({required bool wrapped}) async {
        const Widget button = _CursorChild();
        await pumpHint(
          tester,
          wrapped
              ? const Hint(message: 'Explains itself', child: button)
              : button,
        );
        final TestGesture pointer = await mouse(tester);
        await pointer.moveTo(tester.getCenter(find.byType(_CursorChild)));
        await tester.pumpAndSettle();
        final MouseCursor? cursor =
            RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
        await pointer.removePointer();
        await tester.pump();
        return cursor;
      }

      // Whatever the child asks for, wrapping it in a Hint must not change it.
      final MouseCursor? bare = await cursorOver(wrapped: false);
      final MouseCursor? wrapped = await cursorOver(wrapped: true);
      expect(wrapped, bare);
      expect(wrapped, SystemMouseCursors.grab);
    });
  });

  group('followPointer', () {
    testWidgets('anchors the bubble to the cursor, not the target',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          followPointer: true,
          triggers: <HintTrigger>{HintTrigger.hover},
          message: 'Follows',
          child: SizedBox(width: 300, height: 200),
        ),
      );
      final Rect target = tester.getRect(find.byType(SizedBox).first);
      final TestGesture pointer = await mouse(tester);

      await pointer.moveTo(target.centerLeft + const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(find.text('Follows'), findsOneWidget);
      final double left = tester.getCenter(find.text('Follows')).dx;

      await pointer.moveTo(target.centerRight - const Offset(20, 0));
      await tester.pumpAndSettle();
      final double right = tester.getCenter(find.text('Follows')).dx;

      expect(
        right,
        greaterThan(left + 100),
        reason: 'the bubble should have travelled with the cursor',
      );
    });

    testWidgets('falls back to the target with no pointer',
        (WidgetTester tester) async {
      final HintController controller = HintController();
      addTearDown(controller.dispose);
      await pumpHint(
        tester,
        Hint(
          followPointer: true,
          controller: controller,
          triggers: const <HintTrigger>{HintTrigger.manual},
          message: 'Follows',
          child: const SizedBox(width: 300, height: 200),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();

      // Opened from code with no cursor anywhere: it points at the widget.
      final Rect target = tester.getRect(find.byType(SizedBox).first);
      final Offset bubble = tester.getCenter(find.text('Follows'));
      expect((bubble.dx - target.center.dx).abs(), lessThan(20));
    });

    testWidgets('stays on screen at the edge of the overlay',
        (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          followPointer: true,
          triggers: <HintTrigger>{HintTrigger.hover},
          message: 'Follows the pointer right to the edge',
          child: SizedBox(width: 780, height: 560),
        ),
      );
      final Rect target = tester.getRect(find.byType(SizedBox).first);
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(target.bottomRight - const Offset(2, 2));
      await tester.pumpAndSettle();

      final Rect bubble = tester.getRect(find.byType(HintBubbleDecoration));
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(bubble.right, lessThanOrEqualTo(screen.width));
      expect(bubble.bottom, lessThanOrEqualTo(screen.height));
      expect(bubble.left, greaterThanOrEqualTo(0));
    });
  });

  group('followHighContrast', () {
    /// Resolves a theme under a given high-contrast setting.
    Future<ResolvedHintTheme> resolve(
      WidgetTester tester, {
      required bool highContrast,
      required HintThemeData theme,
    }) async {
      late ResolvedHintTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
          home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: Builder(
              builder: (BuildContext context) {
                resolved = HintThemeData.resolve(context, theme);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return resolved;
    }

    testWidgets('swaps in the contrast design when the platform asks',
        (WidgetTester tester) async {
      final ResolvedHintTheme normal = await resolve(
        tester,
        highContrast: false,
        theme: const HintThemeData(
          preset: HintPreset.soft,
          followHighContrast: true,
        ),
      );
      expect(normal.borderRadius, const BorderRadius.all(Radius.circular(18)));

      final ResolvedHintTheme contrast = await resolve(
        tester,
        highContrast: true,
        theme: const HintThemeData(
          preset: HintPreset.soft,
          followHighContrast: true,
        ),
      );
      expect(contrast.backgroundColor, const Color(0xFF000000));
      expect(contrast.foregroundColor, const Color(0xFFFFFFFF));
      expect(contrast.elevation, 0);
    });

    testWidgets('does nothing unless asked', (WidgetTester tester) async {
      final ResolvedHintTheme resolved = await resolve(
        tester,
        highContrast: true,
        theme: const HintThemeData(preset: HintPreset.soft),
      );
      expect(
        resolved.borderRadius,
        const BorderRadius.all(Radius.circular(18)),
      );
    });

    testWidgets('explicit fields still win over it',
        (WidgetTester tester) async {
      final ResolvedHintTheme resolved = await resolve(
        tester,
        highContrast: true,
        theme: const HintThemeData(
          followHighContrast: true,
          backgroundColor: Color(0xFF123456),
          maxWidth: 411,
        ),
      );
      expect(resolved.backgroundColor, const Color(0xFF123456));
      expect(resolved.maxWidth, 411);
      // …and the rest of the contrast design still applied.
      expect(resolved.foregroundColor, const Color(0xFFFFFFFF));
    });

    testWidgets('survives withoutArrow', (WidgetTester tester) async {
      final ResolvedHintTheme resolved = await resolve(
        tester,
        highContrast: true,
        theme: const HintThemeData(followHighContrast: true),
      );
      final ResolvedHintTheme card = resolved.withoutArrow();
      expect(card.arrowSize, Size.zero);
      expect(card.backgroundColor, const Color(0xFF000000));
    });
  });

  group('backgroundBlur', () {
    testWidgets('adds a clipped backdrop filter', (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          theme: HintThemeData(preset: HintPreset.glass),
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Frosted',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(HintBubbleDecoration),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HintBubbleDecoration),
          matching: find.byType(ClipPath),
        ),
        findsOneWidget,
      );
    });

    testWidgets('costs nothing when it is off', (WidgetTester tester) async {
      await pumpHint(
        tester,
        const Hint(
          triggers: <HintTrigger>{HintTrigger.onAppear},
          message: 'Plain',
          child: SizedBox(width: 80, height: 40),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}

/// A child with a cursor of its own, to prove a Hint does not override it.
class _CursorChild extends StatelessWidget {
  const _CursorChild();

  @override
  Widget build(BuildContext context) {
    return const MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: SizedBox(width: 120, height: 48),
    );
  }
}
