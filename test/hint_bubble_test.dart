import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Wraps [child] in the minimum needed to paint a bubble deterministically.
Widget harness(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF101010),
      body: Center(child: child),
    ),
  );
}

/// Builds a bubble with resolved theming, ready to pump.
Widget bubble({
  required HintSide side,
  double arrowFraction = 0.5,
  HintThemeData? theme,
  String message = 'Check in here',
  String? title,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ResolvedHintTheme resolved = HintThemeData.resolve(context, theme);
      return SizedBox(
        width: 200,
        child: HintBubbleDecoration(
          side: side,
          arrowFraction: arrowFraction,
          theme: resolved,
          child: HintBubbleContent(
            theme: resolved,
            title: title,
            message: message,
          ),
        ),
      );
    },
  );
}

void main() {
  group('buildBubblePath', () {
    const Rect rect = Rect.fromLTWH(0, 0, 100, 50);
    const BorderRadius radius = BorderRadius.all(Radius.circular(8));
    const Size arrow = Size(14, 7);

    test('extends past the body on the anchored edge', () {
      // Bubble above the target: the caret hangs below the body.
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: arrow,
      );
      expect(p.getBounds().bottom, closeTo(rect.bottom + arrow.height, 0.01));
      expect(p.getBounds().top, closeTo(rect.top, 0.01));
    });

    test('grows from the correct edge for every side', () {
      Rect boundsFor(HintSide side) => buildBubblePath(
            rect: rect,
            borderRadius: radius,
            side: side,
            arrowFraction: 0.5,
            arrowSize: arrow,
          ).getBounds();

      expect(boundsFor(HintSide.top).bottom, greaterThan(rect.bottom));
      expect(boundsFor(HintSide.bottom).top, lessThan(rect.top));
      expect(boundsFor(HintSide.left).right, greaterThan(rect.right));
      expect(boundsFor(HintSide.right).left, lessThan(rect.left));
    });

    test('is a single closed contour, not two shapes', () {
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.bottom,
        arrowFraction: 0.5,
        arrowSize: arrow,
      );
      final List<PathMetric> metrics = p.computeMetrics().toList();
      expect(
        metrics.length,
        1,
        reason: 'the union must fuse the body and arrow into one contour',
      );
      expect(metrics.single.isClosed, isTrue);
    });

    test('the arrow tip is inside the path', () {
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: arrow,
      );
      // A point just inside the tip is filled; one past it is not.
      expect(p.contains(Offset(50, rect.bottom + arrow.height - 1)), isTrue);
      expect(p.contains(Offset(50, rect.bottom + arrow.height + 1)), isFalse);
    });

    test('the arrow follows arrowFraction', () {
      final Path left = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.2,
        arrowSize: arrow,
      );
      final Path right = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.8,
        arrowSize: arrow,
      );
      expect(left.contains(Offset(20, rect.bottom + 5)), isTrue);
      expect(left.contains(Offset(80, rect.bottom + 5)), isFalse);
      expect(right.contains(Offset(80, rect.bottom + 5)), isTrue);
      expect(right.contains(Offset(20, rect.bottom + 5)), isFalse);
    });

    test('a zero-sized arrow leaves the body untouched', () {
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: Size.zero,
      );
      expect(p.getBounds(), rect);
    });

    test('an oversized radius does not blow up the geometry', () {
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: BorderRadius.circular(999),
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: arrow,
      );
      // Radius clamps to half the short side, so the body is a stadium.
      expect(p.getBounds().width, closeTo(rect.width, 0.01));
      expect(p.contains(const Offset(50, 25)), isTrue);
    });

    test('an empty rect degrades to an empty body', () {
      final Path p = buildBubblePath(
        rect: Rect.zero,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: arrow,
      );
      expect(p.getBounds().isEmpty, isTrue);
    });

    test('asserts on an out-of-range arrow fraction', () {
      expect(
        () => buildBubblePath(
          rect: rect,
          borderRadius: radius,
          side: HintSide.top,
          arrowFraction: 1.4,
          arrowSize: arrow,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on a non-finite rect', () {
      expect(
        () => buildBubblePath(
          rect: const Rect.fromLTWH(0, 0, double.nan, 10),
          borderRadius: radius,
          side: HintSide.top,
          arrowFraction: 0.5,
          arrowSize: arrow,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('HintBubbleContent', () {
    testWidgets('renders a message alone', (WidgetTester tester) async {
      await tester.pumpWidget(harness(bubble(side: HintSide.top)));
      expect(find.text('Check in here'), findsOneWidget);
    });

    testWidgets('renders a title above the message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(bubble(side: HintSide.top, title: 'Shift required')),
      );
      final Offset titleY = tester.getTopLeft(find.text('Shift required'));
      final Offset messageY = tester.getTopLeft(find.text('Check in here'));
      expect(titleY.dy, lessThan(messageY.dy));
    });

    testWidgets('wraps rather than clipping at maxWidth',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          bubble(
            side: HintSide.top,
            message: 'A rather long hint message that has to wrap onto '
                'several lines to fit inside the bubble.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final Size size = tester.getSize(find.byType(HintBubbleDecoration));
      expect(size.width, 200);
      expect(size.height, greaterThan(40));
    });

    testWidgets('grows with the text scaler', (WidgetTester tester) async {
      Future<double> heightAt(double scale) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: harness(bubble(side: HintSide.top)),
          ),
        );
        return tester.getSize(find.byType(HintBubbleDecoration)).height;
      }

      final double small = await heightAt(1);
      final double large = await heightAt(2);
      expect(large, greaterThan(small));
      expect(tester.takeException(), isNull);
    });

    testWidgets('asserts when given neither title nor message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) => HintBubbleContent(
              theme: HintThemeData.resolve(context),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('curved arrow', () {
    const Rect rect = Rect.fromLTWH(0, 0, 100, 50);
    const BorderRadius radius = BorderRadius.all(Radius.circular(8));
    const Size arrow = Size(20, 12);

    Path curved(HintSide side, {double fraction = 0.5}) => buildBubblePath(
          rect: rect,
          borderRadius: radius,
          side: side,
          arrowFraction: fraction,
          arrowSize: arrow,
          arrowShape: HintArrowShape.curved,
        );

    Path triangle(HintSide side, {double fraction = 0.5}) => buildBubblePath(
          rect: rect,
          borderRadius: radius,
          side: side,
          arrowFraction: fraction,
          arrowSize: arrow,
        );

    test('occupies exactly the same box as the triangle', () {
      // Switching shapes must never move the bubble, so the two silhouettes
      // have to agree on their bounds to the pixel.
      for (final HintSide side in HintSide.values) {
        final Rect a = curved(side).getBounds();
        final Rect b = triangle(side).getBounds();
        expect(a.left, closeTo(b.left, 0.01), reason: '$side left');
        expect(a.top, closeTo(b.top, 0.01), reason: '$side top');
        expect(a.right, closeTo(b.right, 0.01), reason: '$side right');
        expect(a.bottom, closeTo(b.bottom, 0.01), reason: '$side bottom');
      }
    });

    test('grows from the correct edge for every side', () {
      expect(
        curved(HintSide.top).getBounds().bottom,
        closeTo(rect.bottom + arrow.height, 0.01),
      );
      expect(
        curved(HintSide.bottom).getBounds().top,
        closeTo(rect.top - arrow.height, 0.01),
      );
      expect(
        curved(HintSide.left).getBounds().right,
        closeTo(rect.right + arrow.height, 0.01),
      );
      expect(
        curved(HintSide.right).getBounds().left,
        closeTo(rect.left - arrow.height, 0.01),
      );
    });

    test('is a single closed contour', () {
      final List<PathMetric> metrics =
          curved(HintSide.top).computeMetrics().toList();
      expect(metrics.length, 1);
      expect(metrics.single.isClosed, isTrue);
    });

    test('reaches the tip and stops there', () {
      final Path p = curved(HintSide.top);
      expect(p.contains(Offset(50, rect.bottom + arrow.height - 1)), isTrue);
      expect(p.contains(Offset(50, rect.bottom + arrow.height + 1)), isFalse);
    });

    test('follows arrowFraction', () {
      final Path left = curved(HintSide.top, fraction: 0.2);
      final Path right = curved(HintSide.top, fraction: 0.8);
      expect(left.contains(Offset(20, rect.bottom + 4)), isTrue);
      expect(left.contains(Offset(80, rect.bottom + 4)), isFalse);
      expect(right.contains(Offset(80, rect.bottom + 4)), isTrue);
      expect(right.contains(Offset(20, rect.bottom + 4)), isFalse);
    });

    test('tapers inside the straight flank', () {
      // The flanks leave the body parallel to the edge and then fall away
      // towards the tip, so the caret is concave: mid-way down it is slimmer
      // than a straight taper between the same base and tip. That concavity is
      // the difference between the two shapes.
      final Path c = curved(HintSide.top);
      final Path t = triangle(HintSide.top);
      final Offset probe = Offset(50 + arrow.width * 0.3, rect.bottom + 3);
      expect(t.contains(probe), isTrue, reason: 'inside the straight flank');
      expect(c.contains(probe), isFalse, reason: 'outside the curved flank');
    });

    test('still fills the base corners', () {
      // Slimmer in the middle must not mean detached at the base: the caret
      // has to meet the body across its full width or the union would leave a
      // notch beside it.
      final Path c = curved(HintSide.top);
      for (final double dx in <double>[-9, -5, 0, 5, 9]) {
        expect(
          c.contains(Offset(50 + dx, rect.bottom - 0.25)),
          isTrue,
          reason: 'gap at the base at dx=$dx',
        );
      }
    });

    test('leaves the body edge without a corner', () {
      // Sampled just inside the base on both flanks, the curve is symmetric
      // about the caret centre — a crease would break that.
      final Path p = curved(HintSide.top);
      for (final double dx in <double>[2, 4, 6, 8]) {
        expect(
          p.contains(Offset(50 - dx, rect.bottom + 1)),
          p.contains(Offset(50 + dx, rect.bottom + 1)),
          reason: 'asymmetric at dx=$dx',
        );
      }
    });

    test('a zero-sized arrow still degrades to the plain body', () {
      final Path p = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: Size.zero,
        arrowShape: HintArrowShape.curved,
      );
      expect(p.getBounds(), rect);
    });

    test('defaults to a triangle when no shape is given', () {
      final Path implicit = triangle(HintSide.top);
      final Path explicit = buildBubblePath(
        rect: rect,
        borderRadius: radius,
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: arrow,
        arrowShape: HintArrowShape.triangle,
      );
      // Same silhouette: a probe grid agrees everywhere.
      for (double x = 40; x <= 60; x += 2) {
        for (double y = 48; y <= 64; y += 2) {
          expect(
            implicit.contains(Offset(x, y)),
            explicit.contains(Offset(x, y)),
            reason: 'disagreement at ($x, $y)',
          );
        }
      }
    });
  });

  group('goldens', () {
    for (final HintSide side in HintSide.values) {
      testWidgets('bubble on ${side.name}', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              // Room for the arrow to overhang in any direction.
              padding: const EdgeInsets.all(16),
              child: bubble(side: side, title: 'Check in'),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/bubble_${side.name}.png'),
        );
      });
    }

    testWidgets('bubble with an off-centre arrow', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(side: HintSide.top, arrowFraction: 0.12),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_arrow_offset.png'),
      );
    });

    testWidgets('bubble with a border and a large radius',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(
              side: HintSide.bottom,
              theme: const HintThemeData(
                backgroundColor: Color(0xFFFFFFFF),
                foregroundColor: Color(0xFF1A1A1A),
                borderColor: Color(0xFF6750A4),
                borderWidth: 2,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                arrowSize: Size(18, 9),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_bordered.png'),
      );
    });

    for (final HintSide side in HintSide.values) {
      testWidgets('curved arrow on ${side.name}', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              padding: const EdgeInsets.all(20),
              child: bubble(
                side: side,
                title: 'Check in',
                theme: const HintThemeData(
                  arrowShape: HintArrowShape.curved,
                  arrowSize: Size(24, 14),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/bubble_curved_${side.name}.png'),
        );
      });
    }

    testWidgets('curved arrow with a border', (WidgetTester tester) async {
      // The border is where the join shows: a crease between caret and body
      // would be plainly visible along the stroke.
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(20),
            child: bubble(
              side: HintSide.top,
              theme: const HintThemeData(
                arrowShape: HintArrowShape.curved,
                arrowSize: Size(26, 15),
                backgroundColor: Color(0xFFFFFFFF),
                foregroundColor: Color(0xFF1A1A1A),
                borderColor: Color(0xFF6750A4),
                borderWidth: 2,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_curved_bordered.png'),
      );
    });

    testWidgets('bubble in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(side: HintSide.bottom, title: 'Check in'),
          ),
          brightness: Brightness.dark,
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_dark.png'),
      );
    });
  });

  group('a custom arrow', () {
    /// A flat-topped caret: two shoulders and a blunt end, which no built-in
    /// shape can produce.
    Path blunt(HintArrowGeometry g) {
      final Offset shoulderA = g.baseStart + (g.tip - g.baseCentre) * 0.6;
      final Offset shoulderB = g.baseEnd + (g.tip - g.baseCentre) * 0.6;
      return Path()
        ..moveTo(g.baseStart.dx, g.baseStart.dy)
        ..lineTo(shoulderA.dx, shoulderA.dy)
        ..lineTo(shoulderB.dx, shoulderB.dy)
        ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
        ..close();
    }

    test('is unioned into the body like the built-in shapes', () {
      final Path custom = buildBubblePath(
        rect: const Rect.fromLTWH(0, 0, 100, 50),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: HintSide.top,
        arrowFraction: 0.5,
        arrowSize: const Size(20, 10),
        arrowShape: HintArrowShape.custom,
        arrowBuilder: blunt,
      );
      // One closed silhouette, body and caret together.
      expect(custom.contains(const Offset(50, 25)), isTrue);
      // The blunt caret stops at 60% of the depth, so it covers a point the
      // triangle's taper would have missed and misses one past its end.
      expect(custom.contains(const Offset(56, 55)), isTrue);
      expect(custom.contains(const Offset(50, 59.5)), isFalse);
    });

    test('receives geometry resolved for the side', () {
      final List<HintArrowGeometry> seen = <HintArrowGeometry>[];
      for (final HintSide side in HintSide.values) {
        buildBubblePath(
          rect: const Rect.fromLTWH(0, 0, 100, 50),
          borderRadius: BorderRadius.zero,
          side: side,
          arrowFraction: 0.5,
          arrowSize: const Size(20, 10),
          arrowShape: HintArrowShape.custom,
          arrowBuilder: (HintArrowGeometry g) {
            seen.add(g);
            return Path()
              ..moveTo(g.baseStart.dx, g.baseStart.dy)
              ..lineTo(g.tip.dx, g.tip.dy)
              ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
              ..close();
          },
        );
      }
      expect(seen.length, 4);
      // The tip always points away from the bubble, towards the target.
      expect(seen[0].tip.dy, greaterThan(50)); // top: caret below
      expect(seen[1].tip.dy, lessThan(0)); // bottom: caret above
      expect(seen[2].tip.dx, greaterThan(100)); // left: caret right
      expect(seen[3].tip.dx, lessThan(0)); // right: caret left
      // The base spans the full arrow width, whichever way "along" runs.
      for (final HintArrowGeometry g in seen) {
        expect((g.baseEnd - g.baseStart).distance, closeTo(20, 0.001));
        expect(g.halfWidth, 10);
        expect(g.size, const Size(20, 10));
      }
    });

    test('falls back to a triangle when no builder is given', () {
      // Release behaviour: the assert fires in debug, and the shape still
      // draws rather than vanishing.
      Path build() => buildBubblePath(
            rect: const Rect.fromLTWH(0, 0, 100, 50),
            borderRadius: BorderRadius.zero,
            side: HintSide.top,
            arrowFraction: 0.5,
            arrowSize: const Size(20, 10),
            arrowShape: HintArrowShape.custom,
          );
      expect(build, throwsAssertionError);
    });

    testWidgets('a themed builder reaches the painter',
        (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(
              side: HintSide.top,
              theme: HintThemeData(
                arrowShape: HintArrowShape.custom,
                arrowSize: const Size(24, 12),
                arrowBuilder: (HintArrowGeometry g) {
                  calls++;
                  return blunt(g);
                },
              ),
            ),
          ),
        ),
      );
      expect(calls, greaterThan(0));
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_custom_arrow.png'),
      );
    });
  });

  group('preset goldens', () {
    // Seven designs and no regression net would mean a wrong radius or arrow
    // inset in one of them could ship unnoticed.
    for (final HintPreset preset in HintPreset.values) {
      testWidgets('${preset.name} looks right', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              padding: const EdgeInsets.all(20),
              child: bubble(
                side: HintSide.top,
                title: 'Check in',
                theme: HintThemeData(preset: preset),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/preset_${preset.name}.png'),
        );
      });
    }

    testWidgets('card in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(20),
            child: bubble(
              side: HintSide.top,
              title: 'Check in',
              theme: const HintThemeData(preset: HintPreset.card),
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/preset_card_dark.png'),
      );
    });
  });
}
