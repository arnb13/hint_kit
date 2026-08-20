import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// A 400x800 phone-ish overlay used by most cases.
const Size kOverlay = Size(400, 800);
const Size kBubble = Size(200, 100);
const EdgeInsets kMargin = EdgeInsets.all(8);
const double kGap = 12;
const double kArrowInset = 16;

HintPlacement resolve({
  required Rect target,
  Size overlay = kOverlay,
  Size bubble = kBubble,
  HintDirection preferred = HintDirection.auto,
  double gap = kGap,
  EdgeInsets margin = kMargin,
  double arrowInset = kArrowInset,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return resolvePlacement(
    target: target,
    overlay: overlay,
    bubble: bubble,
    preferred: preferred,
    gap: gap,
    margin: margin,
    arrowInset: arrowInset,
    textDirection: textDirection,
  );
}

/// Asserts the bubble is inside the margin box (or, when it cannot fit,
/// symmetrically overflowing it).
void expectInsideMargin(
  HintPlacement placement, {
  Size overlay = kOverlay,
  EdgeInsets margin = kMargin,
}) {
  final Rect rect = placement.bubbleRect;
  expect(rect.left.isFinite, isTrue, reason: 'left must be finite');
  expect(rect.top.isFinite, isTrue, reason: 'top must be finite');
  if (rect.width <= overlay.width - margin.horizontal) {
    expect(rect.left, greaterThanOrEqualTo(margin.left - 0.001));
    expect(rect.right, lessThanOrEqualTo(overlay.width - margin.right + 0.001));
  }
  if (rect.height <= overlay.height - margin.vertical) {
    expect(rect.top, greaterThanOrEqualTo(margin.top - 0.001));
    expect(
      rect.bottom,
      lessThanOrEqualTo(overlay.height - margin.bottom + 0.001),
    );
  }
}

void main() {
  group('side selection', () {
    // A target in the middle of the screen has room on every side, so the
    // preferred direction always wins.
    const Rect centred = Rect.fromLTWH(150, 350, 100, 100);

    test('preferred bottom fits and is taken', () {
      final HintPlacement p =
          resolve(target: centred, preferred: HintDirection.bottom);
      expect(p.side, HintSide.bottom);
      expect(p.bubbleRect.top, centred.bottom + kGap);
    });

    test('preferred top fits and is taken', () {
      final HintPlacement p =
          resolve(target: centred, preferred: HintDirection.top);
      expect(p.side, HintSide.top);
      expect(p.bubbleRect.bottom, centred.top - kGap);
    });

    test('preferred left fits and is taken', () {
      final HintPlacement p = resolve(
        target: centred,
        preferred: HintDirection.left,
        bubble: const Size(100, 60),
      );
      expect(p.side, HintSide.left);
      expect(p.bubbleRect.right, centred.left - kGap);
    });

    test('preferred right fits and is taken', () {
      final HintPlacement p = resolve(
        target: centred,
        preferred: HintDirection.right,
        bubble: const Size(100, 60),
      );
      expect(p.side, HintSide.right);
      expect(p.bubbleRect.left, centred.right + kGap);
    });

    test('auto prefers bottom when both vertical sides fit', () {
      expect(resolve(target: centred).side, HintSide.bottom);
    });

    test('auto flips to top when there is no room below', () {
      final HintPlacement p =
          resolve(target: const Rect.fromLTWH(150, 700, 100, 40));
      expect(p.side, HintSide.top);
    });

    test('auto falls back to the wider horizontal side', () {
      // A full-height target leaves no vertical room at all; the target hugs
      // the left edge, so the right has more space.
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 0, 100, 800),
        bubble: const Size(120, 60),
      );
      expect(p.side, HintSide.right);
    });

    test('auto falls back to left when left is wider', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(300, 0, 100, 800),
        bubble: const Size(120, 60),
      );
      expect(p.side, HintSide.left);
    });

    test('bottom flips to top when the target is near the bottom edge', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 720, 100, 60),
        preferred: HintDirection.bottom,
      );
      expect(p.side, HintSide.top);
      expect(p.bubbleRect.bottom, 720 - kGap);
    });

    test('top flips to bottom when the target is near the top edge', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 20, 100, 60),
        preferred: HintDirection.top,
      );
      expect(p.side, HintSide.bottom);
      expect(p.bubbleRect.top, 80 + kGap);
    });

    test('left flips to right when the target hugs the left edge', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(4, 350, 100, 60),
        preferred: HintDirection.left,
      );
      expect(p.side, HintSide.right);
      expect(p.bubbleRect.left, 104 + kGap);
    });

    test('right flips to left when the target hugs the right edge', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(296, 350, 100, 60),
        preferred: HintDirection.right,
      );
      expect(p.side, HintSide.left);
      expect(p.bubbleRect.right, 296 - kGap);
    });

    test('falls through to a perpendicular side when neither vertical fits',
        () {
      // Target spans the full height: no vertical room, plenty on the right.
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 0, 80, 800),
        preferred: HintDirection.top,
        bubble: const Size(120, 60),
      );
      expect(p.side, HintSide.right);
    });

    test('fits is exclusive of a hair less space', () {
      // Free space below is exactly bubble.height + gap - 0.5: does not fit.
      final double free = kBubble.height + kGap - 0.5;
      final double targetBottom = kOverlay.height - kMargin.bottom - free;
      final HintPlacement p = resolve(
        target: Rect.fromLTWH(150, targetBottom - 40, 100, 40),
        preferred: HintDirection.bottom,
      );
      expect(p.side, HintSide.top);
    });

    test('fits is inclusive of exactly enough space', () {
      final double free = kBubble.height + kGap;
      final double targetBottom = kOverlay.height - kMargin.bottom - free;
      final HintPlacement p = resolve(
        target: Rect.fromLTWH(150, targetBottom - 40, 100, 40),
        preferred: HintDirection.bottom,
      );
      expect(p.side, HintSide.bottom);
    });

    test('picks the least-bad side when nothing fits', () {
      // Tiny viewport, big bubble. Target sits low, so above has most slack.
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(40, 150, 20, 20),
        overlay: const Size(100, 200),
        bubble: const Size(90, 90),
        preferred: HintDirection.bottom,
      );
      expect(p.side, HintSide.top);
      expectInsideMargin(p, overlay: const Size(100, 200));
    });
  });

  group('cross-axis clamping', () {
    test('centres on the target when there is room', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 350, 100, 100),
        preferred: HintDirection.bottom,
      );
      expect(p.bubbleRect.center.dx, 200);
    });

    test('clamps to the left screen margin', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 350, 40, 40),
        preferred: HintDirection.bottom,
      );
      expect(p.bubbleRect.left, kMargin.left);
      expectInsideMargin(p);
    });

    test('clamps to the right screen margin', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(360, 350, 40, 40),
        preferred: HintDirection.bottom,
      );
      expect(p.bubbleRect.right, kOverlay.width - kMargin.right);
      expectInsideMargin(p);
    });

    test('clamps to the top screen margin', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 0, 40, 40),
        preferred: HintDirection.right,
        bubble: const Size(100, 120),
      );
      expect(p.side, HintSide.right);
      expect(p.bubbleRect.top, kMargin.top);
      expectInsideMargin(p);
    });

    test('clamps to the bottom screen margin', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 760, 40, 40),
        preferred: HintDirection.right,
        bubble: const Size(100, 120),
      );
      expect(p.side, HintSide.right);
      expect(p.bubbleRect.bottom, kOverlay.height - kMargin.bottom);
      expectInsideMargin(p);
    });

    test('respects an asymmetric margin such as a safe area', () {
      const EdgeInsets margin = EdgeInsets.fromLTRB(24, 60, 24, 40);
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 350, 30, 30),
        preferred: HintDirection.bottom,
        margin: margin,
      );
      expect(p.bubbleRect.left, 24);
      expectInsideMargin(p, margin: margin);
    });
  });

  group('arrow', () {
    test('points at the target centre', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 350, 100, 100),
        preferred: HintDirection.bottom,
      );
      // Bubble is centred on the target, so the arrow sits at the middle.
      expect(p.arrowFraction, closeTo(0.5, 1e-9));
      expect(p.arrowAnchor.dx, closeTo(200, 1e-9));
      expect(p.arrowAnchor.dy, p.bubbleRect.top);
    });

    test('tracks the target when the bubble is clamped sideways', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 350, 80, 40),
        preferred: HintDirection.bottom,
      );
      // Target centre is x=40, bubble starts at x=8 and is 200 wide, so the
      // arrow clears the corner inset and points straight at the target.
      expect(p.arrowAnchor.dx, closeTo(40, 1e-9));
      expect(p.arrowFraction, closeTo((40 - 8) / 200, 1e-9));
    });

    test('clamps off the leading rounded corner', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(0, 350, 4, 4),
        preferred: HintDirection.bottom,
      );
      // Raw fraction would be (2 - 8) / 200 < 0; inset keeps it at 16/200.
      expect(p.arrowFraction, closeTo(kArrowInset / kBubble.width, 1e-9));
    });

    test('clamps off the trailing rounded corner', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(396, 350, 4, 4),
        preferred: HintDirection.bottom,
      );
      expect(p.arrowFraction, closeTo(1 - kArrowInset / kBubble.width, 1e-9));
    });

    test('runs along the vertical edge for horizontal sides', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(20, 0, 40, 40),
        preferred: HintDirection.right,
        bubble: const Size(100, 200),
      );
      expect(p.side, HintSide.right);
      expect(p.arrowAnchor.dx, p.bubbleRect.left);
      // Target centre is y=20; the inset stops the arrow reaching it.
      expect(p.arrowFraction, closeTo(kArrowInset / 200, 1e-9));
    });

    test('centres when the bubble is too small to inset', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 350, 100, 100),
        preferred: HintDirection.bottom,
        bubble: const Size(20, 20),
        arrowInset: 30,
      );
      expect(p.arrowFraction, 0.5);
    });

    test('is always within 0..1', () {
      for (double x = -200; x <= 600; x += 37) {
        for (final HintDirection d in HintDirection.values) {
          final HintPlacement p = resolve(
            target: Rect.fromLTWH(x, x.abs() % 800, 30, 30),
            preferred: d,
          );
          expect(p.arrowFraction, inInclusiveRange(0, 1));
          expect(p.arrowFraction.isFinite, isTrue);
        }
      }
    });
  });

  group('text direction', () {
    const Rect centred = Rect.fromLTWH(150, 350, 100, 100);

    test('rtl flips HintDirection.left to the visual right', () {
      final HintPlacement p = resolve(
        target: centred,
        preferred: HintDirection.left,
        bubble: const Size(100, 60),
        textDirection: TextDirection.rtl,
      );
      expect(p.side, HintSide.right);
      expect(p.bubbleRect.left, centred.right + kGap);
    });

    test('rtl flips HintDirection.right to the visual left', () {
      final HintPlacement p = resolve(
        target: centred,
        preferred: HintDirection.right,
        bubble: const Size(100, 60),
        textDirection: TextDirection.rtl,
      );
      expect(p.side, HintSide.left);
      expect(p.bubbleRect.right, centred.left - kGap);
    });

    test('rtl leaves vertical directions alone', () {
      final HintPlacement p = resolve(
        target: centred,
        preferred: HintDirection.top,
        textDirection: TextDirection.rtl,
      );
      expect(p.side, HintSide.top);
    });

    test('breaks equal horizontal free space by reading direction', () {
      // Symmetric target with no vertical room: free space left == right.
      const Rect fullHeight = Rect.fromLTWH(150, 0, 100, 800);
      expect(
        resolve(target: fullHeight, bubble: const Size(80, 40)).side,
        HintSide.right,
      );
      expect(
        resolve(
          target: fullHeight,
          bubble: const Size(80, 40),
          textDirection: TextDirection.rtl,
        ).side,
        HintSide.left,
      );
    });
  });

  group('degenerate input', () {
    test('a bubble wider than the viewport is centred, not clamped', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(10, 350, 40, 40),
        bubble: const Size(500, 60),
      );
      // 8 + (384 - 500) / 2 keeps the overflow symmetric.
      expect(p.bubbleRect.left, closeTo(8 + (384 - 500) / 2, 1e-9));
      expect(p.bubbleRect.center.dx, closeTo(kOverlay.width / 2, 1e-9));
      expect(p.arrowFraction, inInclusiveRange(0, 1));
    });

    test('a bubble bigger than the viewport in both axes stays finite', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(180, 380, 40, 40),
        bubble: const Size(600, 1000),
      );
      expect(p.bubbleRect.left.isFinite, isTrue);
      expect(p.bubbleRect.top.isFinite, isTrue);
      expect(p.arrowFraction, inInclusiveRange(0, 1));
      expect(p.bubbleRect.center.dy, closeTo(kOverlay.height / 2, 1e-9));
    });

    test('a zero-sized bubble does not divide by zero', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(180, 380, 40, 40),
        bubble: Size.zero,
      );
      expect(p.arrowFraction, 0.5);
      expect(p.bubbleRect.isFinite, isTrue);
    });

    test('a zero-sized target is treated as a point', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(200, 400, 0, 0),
        preferred: HintDirection.bottom,
      );
      expect(p.bubbleRect.top, 400 + kGap);
      expect(p.arrowAnchor.dx, closeTo(200, 1e-9));
    });

    test('a target entirely off-screen still yields an on-screen bubble', () {
      final HintPlacement p =
          resolve(target: const Rect.fromLTWH(-500, -500, 40, 40));
      expectInsideMargin(p);
      expect(p.arrowFraction, inInclusiveRange(0, 1));
    });

    test('margins larger than the viewport do not produce NaN', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(180, 380, 40, 40),
        margin: const EdgeInsets.all(500),
      );
      expect(p.bubbleRect.left.isFinite, isTrue);
      expect(p.bubbleRect.top.isFinite, isTrue);
      expect(p.arrowFraction.isFinite, isTrue);
    });

    test('a zero gap places the bubble flush against the target', () {
      final HintPlacement p = resolve(
        target: const Rect.fromLTWH(150, 350, 100, 100),
        preferred: HintDirection.bottom,
        gap: 0,
      );
      expect(p.bubbleRect.top, 450);
    });

    test('asserts on a non-finite target', () {
      expect(
        () => resolve(
          target: const Rect.fromLTWH(0, 0, double.infinity, 10),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on an empty overlay', () {
      expect(
        () => resolve(
          target: const Rect.fromLTWH(0, 0, 10, 10),
          overlay: Size.zero,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on a negative gap', () {
      expect(
        () => resolve(target: const Rect.fromLTWH(0, 0, 10, 10), gap: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('HintPlacement value semantics', () {
    const HintPlacement a = HintPlacement(
      side: HintSide.top,
      bubbleRect: Rect.fromLTWH(0, 0, 10, 10),
      arrowFraction: 0.5,
    );

    test('equal placements compare equal', () {
      const HintPlacement b = HintPlacement(
        side: HintSide.top,
        bubbleRect: Rect.fromLTWH(0, 0, 10, 10),
        arrowFraction: 0.5,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different placements compare unequal', () {
      const HintPlacement b = HintPlacement(
        side: HintSide.bottom,
        bubbleRect: Rect.fromLTWH(0, 0, 10, 10),
        arrowFraction: 0.5,
      );
      expect(a, isNot(b));
    });

    test('toString is informative', () {
      expect(a.toString(), contains('HintSide.top'));
      expect(a.toString(), contains('0.500'));
    });
  });

  group('HintSide', () {
    test('opposite is an involution', () {
      for (final HintSide s in HintSide.values) {
        expect(s.opposite.opposite, s);
        expect(s.opposite, isNot(s));
      }
    });

    test('axis helpers agree', () {
      expect(HintSide.top.isVertical, isTrue);
      expect(HintSide.bottom.isVertical, isTrue);
      expect(HintSide.left.isHorizontal, isTrue);
      expect(HintSide.right.isHorizontal, isTrue);
      for (final HintSide s in HintSide.values) {
        expect(s.isVertical, isNot(s.isHorizontal));
      }
    });
  });
}
