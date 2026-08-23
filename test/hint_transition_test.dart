import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Pumps a hint that is open from the first frame, under [theme].
Future<void> pumpOpenHint(
  WidgetTester tester, {
  HintThemeData? theme,
  HintController? controller,
  Object hintKey = 'hint',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Hint(
            // A fresh key per pump, so pumping a second hint in one test
            // builds a new State and actually runs its entry animation
            // instead of reusing an already-open one.
            key: ValueKey<Object>(hintKey),
            theme: theme,
            controller: controller,
            triggers: controller == null
                ? const <HintTrigger>{HintTrigger.onAppear}
                : const <HintTrigger>{HintTrigger.manual},
            message: 'Check in here',
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Finds transition widgets belonging to the bubble itself.
///
/// Neither a bare type search nor an ancestor search works here: the route
/// MaterialApp pushes brings its own fade, slide and scale transitions, and
/// they sit above the overlay the bubble is drawn into. Everything the bubble
/// animates with is built inside [AnchoredHintBubble].
Finder wrapping(Type type) => find.descendant(
      of: find.byType(AnchoredHintBubble),
      matching: find.byType(type),
    );

/// The opacity the bubble's own [FadeTransition] is currently applying.
double? fadeOpacity(WidgetTester tester) {
  final Iterable<FadeTransition> fades =
      tester.widgetList<FadeTransition>(wrapping(FadeTransition));
  if (fades.isEmpty) {
    return null;
  }
  return fades.first.opacity.value;
}

void main() {
  group('preset transitions', () {
    testWidgets('scale is the default and wraps a ScaleTransition',
        (WidgetTester tester) async {
      await pumpOpenHint(tester);
      await tester.pump(const Duration(milliseconds: 40));
      expect(wrapping(ScaleTransition), findsWidgets);
      expect(wrapping(SlideTransition), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('fade uses opacity only', (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(transition: HintTransition.fade),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(FadeTransition), findsWidgets);
      expect(wrapping(ScaleTransition), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('slide adds a SlideTransition', (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(transition: HintTransition.slide),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(wrapping(SlideTransition), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('pop scales past 1 before settling',
        (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(
          transition: HintTransition.pop,
          transitionDuration: Duration(milliseconds: 300),
        ),
      );
      double peak = 0;
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        for (final ScaleTransition s
            in tester.widgetList<ScaleTransition>(wrapping(ScaleTransition))) {
          if (s.scale.value > peak) {
            peak = s.scale.value;
          }
        }
      }
      expect(peak, greaterThan(1.0), reason: 'pop should overshoot');
      await tester.pumpAndSettle();
      final ScaleTransition settled =
          tester.widgetList<ScaleTransition>(wrapping(ScaleTransition)).last;
      expect(settled.scale.value, closeTo(1, 0.001));
    });

    testWidgets('none wraps nothing at all', (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(transition: HintTransition.none),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Check in here'), findsOneWidget);
      expect(wrapping(ScaleTransition), findsNothing);
      expect(wrapping(SlideTransition), findsNothing);
      // The bubble is fully visible from the first frame rather than fading.
      expect(fadeOpacity(tester), isNull);
      await tester.pumpAndSettle();
    });
  });

  group('the transition curve', () {
    testWidgets('is actually applied to the animation',
        (WidgetTester tester) async {
      // Two hints, same duration, different curves: at the same moment they
      // must be at different points, or the curve is being ignored.
      Future<double> opacityAt(Curve curve) async {
        await pumpOpenHint(
          tester,
          hintKey: curve,
          theme: HintThemeData(
            transition: HintTransition.fade,
            transitionCurve: curve,
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final double value = fadeOpacity(tester)!;
        await tester.pumpAndSettle();
        return value;
      }

      final double fast = await opacityAt(Curves.easeOutCubic);
      final double slow = await opacityAt(Curves.easeInCubic);
      expect(fast, greaterThan(slow));
    });

    testWidgets('an overshooting curve does not break opacity',
        (WidgetTester tester) async {
      // easeOutBack drives past 1; FadeTransition asserts on that, so the
      // clamped animation is what keeps this from throwing.
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(
          transitionCurve: Curves.easeOutBack,
          transitionDuration: Duration(milliseconds: 300),
        ),
      );
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        final double? opacity = fadeOpacity(tester);
        if (opacity != null) {
          expect(opacity, inInclusiveRange(0, 1));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });

  group('a custom transition', () {
    testWidgets('replaces the preset entirely', (WidgetTester tester) async {
      bool called = false;
      await pumpOpenHint(
        tester,
        theme: HintThemeData(
          // Set both: the builder must win.
          transition: HintTransition.slide,
          transitionBuilder: (
            BuildContext context,
            HintTransitionInfo info,
            Widget child,
          ) {
            called = true;
            return RotationTransition(
              turns:
                  Tween<double>(begin: -0.05, end: 0).animate(info.animation),
              child: child,
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(called, isTrue);
      expect(wrapping(RotationTransition), findsOneWidget);
      expect(wrapping(SlideTransition), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('is handed the side and an origin on the caret',
        (WidgetTester tester) async {
      HintTransitionInfo? seen;
      await pumpOpenHint(
        tester,
        theme: HintThemeData(
          transitionBuilder: (
            BuildContext context,
            HintTransitionInfo info,
            Widget child,
          ) {
            seen = info;
            return child;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(seen, isNotNull);
      // The target is centred, so the bubble goes below it and the caret is on
      // the bubble's top edge.
      expect(seen!.side, HintSide.bottom);
      expect(seen!.origin.y, -1);
      expect(seen!.towardsTarget, const Offset(0, -1));
      expect(seen!.opacity.value, inInclusiveRange(0, 1));
    });

    testWidgets('can build on a preset transition',
        (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: HintThemeData(
          transitionBuilder: (
            BuildContext context,
            HintTransitionInfo info,
            Widget child,
          ) =>
              HintTransition.fade.build(
            context,
            info,
            Padding(padding: const EdgeInsets.all(4), child: child),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(FadeTransition), findsWidgets);
      await tester.pumpAndSettle();
    });
  });

  group('presets carry motion', () {
    testWidgets('soft pops and card slides', (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        hintKey: 'soft',
        theme: const HintThemeData(preset: HintPreset.soft),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(wrapping(ScaleTransition), findsWidgets);
      await tester.pumpAndSettle();

      await pumpOpenHint(
        tester,
        hintKey: 'card',
        theme: const HintThemeData(preset: HintPreset.card),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(wrapping(SlideTransition), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('an explicit transition beats the preset',
        (WidgetTester tester) async {
      await pumpOpenHint(
        tester,
        theme: const HintThemeData(
          preset: HintPreset.card,
          transition: HintTransition.fade,
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(wrapping(SlideTransition), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
