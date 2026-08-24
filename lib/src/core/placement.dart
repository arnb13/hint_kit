import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'hint_side.dart';

/// The result of [resolvePlacement].
///
/// Everything in here is expressed in *overlay* coordinates, i.e. the
/// coordinate space of the `Overlay` the bubble is painted into, whose origin
/// is its top-left corner.
///
/// {@category Advanced}
@immutable
class HintPlacement {
  /// Creates a resolved placement.
  const HintPlacement({
    required this.side,
    required this.bubbleRect,
    required this.arrowFraction,
  });

  /// The side of the target the bubble was placed on.
  final HintSide side;

  /// Where the bubble should be painted, in overlay coordinates.
  final Rect bubbleRect;

  /// Where the arrow sits along the bubble's anchored edge, as a fraction in
  /// the range 0..1.
  ///
  /// The anchored edge is the bubble edge closest to the target: the bottom
  /// edge for [HintSide.top], the top edge for [HintSide.bottom], and so on.
  /// The fraction is always measured left-to-right for a horizontal edge and
  /// top-to-bottom for a vertical one, regardless of text direction.
  final double arrowFraction;

  /// The point on the bubble's anchored edge that the caret grows out of.
  ///
  /// This is [arrowFraction] expressed in overlay pixels.
  Offset get arrowAnchor => switch (side) {
        HintSide.top => Offset(
            bubbleRect.left + bubbleRect.width * arrowFraction,
            bubbleRect.bottom,
          ),
        HintSide.bottom => Offset(
            bubbleRect.left + bubbleRect.width * arrowFraction,
            bubbleRect.top,
          ),
        HintSide.left => Offset(
            bubbleRect.right,
            bubbleRect.top + bubbleRect.height * arrowFraction,
          ),
        HintSide.right => Offset(
            bubbleRect.left,
            bubbleRect.top + bubbleRect.height * arrowFraction,
          ),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HintPlacement &&
          other.side == side &&
          other.bubbleRect == bubbleRect &&
          other.arrowFraction == arrowFraction;

  @override
  int get hashCode => Object.hash(side, bubbleRect, arrowFraction);

  @override
  String toString() => 'HintPlacement(side: $side, bubbleRect: $bubbleRect, '
      'arrowFraction: ${arrowFraction.toStringAsFixed(3)})';
}

/// Decides where a hint bubble of size [bubble] should go relative to
/// [target].
///
/// This is a pure function: it touches no widgets, no `BuildContext` and no
/// global state, which makes it cheap to unit test and safe to call during
/// layout.
///
/// The algorithm, in order:
///
/// 1. **Side.** If [preferred] fits, it wins. Otherwise its opposite is tried,
///    then the remaining two sides ordered by free space. A side "fits" when
///    the free space between the target and the [margin] box on that side is
///    at least the bubble's main-axis extent plus [gap]. If nothing fits, the
///    side with the greatest slack (free space minus required space) is used,
///    so a side that *almost* works beats one that is hopeless.
/// 2. **Main axis.** Derived from the chosen side and [gap].
/// 3. **Cross axis.** Centred on the target, then clamped into the [margin]
///    box so the bubble never leaves the screen. A bubble too large to fit is
///    centred on the margin box instead of being clamped to one edge.
/// 4. **Arrow.** Points at the target's centre, then clamped to keep at least
///    [arrowInset] between the arrow's centre and each end of the anchored
///    edge, so the caret never rides onto a rounded corner.
///
/// [textDirection] flips [HintDirection.left] and [HintDirection.right]: under
/// [TextDirection.rtl], `left` means the visual right. It also breaks ties
/// between the two horizontal sides under [HintDirection.auto].
///
/// All arguments must be finite; this is asserted in debug builds. The result
/// is always finite, and [HintPlacement.arrowFraction] is always in 0..1.
///
/// {@category Advanced}
HintPlacement resolvePlacement({
  required Rect target,
  required Size overlay,
  required Size bubble,
  required HintDirection preferred,
  required double gap,
  required EdgeInsets margin,
  required double arrowInset,
  required TextDirection textDirection,
}) {
  assert(
    target.isFinite,
    'resolvePlacement: target must be finite, got $target. The target rect is '
    'measured from a RenderBox; a non-finite value means it was read before '
    'layout.',
  );
  assert(
    overlay.isFinite && !overlay.isEmpty,
    'resolvePlacement: overlay must be finite and non-empty, got $overlay.',
  );
  assert(
    bubble.isFinite,
    'resolvePlacement: bubble must be finite, got $bubble. Measure the bubble '
    'before resolving its placement.',
  );
  assert(gap.isFinite && gap >= 0, 'resolvePlacement: gap must be >= 0.');
  assert(
    arrowInset.isFinite && arrowInset >= 0,
    'resolvePlacement: arrowInset must be >= 0.',
  );

  // Free space between the target and the margin box, per side.
  double freeOn(HintSide side) => switch (side) {
        HintSide.top => target.top - margin.top,
        HintSide.bottom => overlay.height - margin.bottom - target.bottom,
        HintSide.left => target.left - margin.left,
        HintSide.right => overlay.width - margin.right - target.right,
      };

  double requiredOn(HintSide side) =>
      (side.isVertical ? bubble.height : bubble.width) + gap;

  final HintSide side = _chooseSide(
    preferred: preferred,
    textDirection: textDirection,
    freeOn: freeOn,
    requiredOn: requiredOn,
  );

  // Main axis follows from the side; cross axis is centred then clamped.
  final double mainLeft;
  final double mainTop;
  if (side.isVertical) {
    mainTop = side == HintSide.top
        ? target.top - gap - bubble.height
        : target.bottom + gap;
    mainLeft = _fit(
      preferred: target.center.dx - bubble.width / 2,
      size: bubble.width,
      start: margin.left,
      end: overlay.width - margin.right,
    );
  } else {
    mainLeft = side == HintSide.left
        ? target.left - gap - bubble.width
        : target.right + gap;
    mainTop = _fit(
      preferred: target.center.dy - bubble.height / 2,
      size: bubble.height,
      start: margin.top,
      end: overlay.height - margin.bottom,
    );
  }

  // The main axis is kept inside the margin box too: when the bubble is taller
  // than the space above the target it overlaps the target rather than hanging
  // off the screen.
  final Rect bubbleRect = Rect.fromLTWH(
    side.isVertical
        ? mainLeft
        : _fit(
            preferred: mainLeft,
            size: bubble.width,
            start: margin.left,
            end: overlay.width - margin.right,
          ),
    side.isVertical
        ? _fit(
            preferred: mainTop,
            size: bubble.height,
            start: margin.top,
            end: overlay.height - margin.bottom,
          )
        : mainTop,
    bubble.width,
    bubble.height,
  );

  return HintPlacement(
    side: side,
    bubbleRect: bubbleRect,
    arrowFraction: _arrowFraction(
      targetCentre: side.isVertical ? target.center.dx : target.center.dy,
      edgeStart: side.isVertical ? bubbleRect.left : bubbleRect.top,
      edgeLength: side.isVertical ? bubbleRect.width : bubbleRect.height,
      inset: arrowInset,
    ),
  );
}

/// Picks the winning side, honouring [preferred] first and falling back to
/// free space.
HintSide _chooseSide({
  required HintDirection preferred,
  required TextDirection textDirection,
  required double Function(HintSide side) freeOn,
  required double Function(HintSide side) requiredOn,
}) {
  // Horizontal sides ordered by free space, ties broken by reading direction.
  final bool rtl = textDirection == TextDirection.rtl;
  final HintSide preferredHorizontal = rtl ? HintSide.left : HintSide.right;
  final HintSide otherHorizontal = preferredHorizontal.opposite;
  final List<HintSide> horizontals =
      freeOn(otherHorizontal) > freeOn(preferredHorizontal)
          ? <HintSide>[otherHorizontal, preferredHorizontal]
          : <HintSide>[preferredHorizontal, otherHorizontal];

  final List<HintSide> candidates;
  if (preferred == HintDirection.auto) {
    candidates = <HintSide>[HintSide.bottom, HintSide.top, ...horizontals];
  } else {
    final HintSide first = _resolveDirection(preferred, textDirection);
    candidates = <HintSide>[
      first,
      first.opposite,
      ...first.isVertical
          ? horizontals
          : <HintSide>[HintSide.bottom, HintSide.top],
    ];
  }

  for (final HintSide candidate in candidates) {
    if (freeOn(candidate) >= requiredOn(candidate)) {
      return candidate;
    }
  }

  // Nothing fits: take the least-bad side, preserving candidate order on ties.
  HintSide best = candidates.first;
  double bestSlack = freeOn(best) - requiredOn(best);
  for (final HintSide candidate in candidates.skip(1)) {
    final double slack = freeOn(candidate) - requiredOn(candidate);
    if (slack > bestSlack) {
      best = candidate;
      bestSlack = slack;
    }
  }
  return best;
}

/// Turns a non-`auto` [HintDirection] into a visual [HintSide].
HintSide _resolveDirection(HintDirection direction, TextDirection text) {
  final bool rtl = text == TextDirection.rtl;
  return switch (direction) {
    HintDirection.top => HintSide.top,
    HintDirection.bottom => HintSide.bottom,
    HintDirection.left => rtl ? HintSide.right : HintSide.left,
    HintDirection.right => rtl ? HintSide.left : HintSide.right,
    HintDirection.auto => HintSide.bottom,
  };
}

/// Clamps [preferred] so a span of [size] stays inside `[start, end]`.
///
/// When the span is too large to fit it is centred on the range instead, which
/// keeps the overflow symmetric rather than dumping it all on one edge.
double _fit({
  required double preferred,
  required double size,
  required double start,
  required double end,
}) {
  final double available = end - start;
  if (size >= available) {
    return start + (available - size) / 2;
  }
  return clampDouble(preferred, start, end - size);
}

/// Positions the arrow along an edge, keeping it clear of the rounded corners.
double _arrowFraction({
  required double targetCentre,
  required double edgeStart,
  required double edgeLength,
  required double inset,
}) {
  if (edgeLength <= 0 || inset * 2 >= edgeLength) {
    return 0.5;
  }
  final double raw = (targetCentre - edgeStart) / edgeLength;
  final double insetFraction = inset / edgeLength;
  return clampDouble(raw, insetFraction, 1 - insetFraction);
}
