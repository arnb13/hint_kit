/// @docImport 'hint.dart';
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/hint_arrow.dart';
import '../core/hint_side.dart';
import '../theme/hint_theme.dart';

/// Builds the outline of a hint bubble: the rounded body with its arrow fused
/// into a single closed path.
///
/// The union is what keeps the border stroke and the drop shadow continuous.
/// Stacking a triangle widget on top of a rounded [Container] — the usual
/// approach — leaves a visible seam wherever the two shapes meet, and a shadow
/// that is cast twice.
///
/// [rect] is the bubble body in the coordinate space of the returned path,
/// [side] is the side of the *target* the bubble sits on (so the arrow grows
/// from the opposite edge of the body), and [arrowFraction] is the position of
/// the arrow along that edge as a fraction in 0..1.
///
/// The caller is responsible for having clamped [arrowFraction] far enough
/// from the ends of the edge that the caret does not collide with a corner;
/// `resolvePlacement` does this using `HintThemeData.arrowInset`.
///
/// [arrowShape] selects the caret silhouette, and [arrowBuilder] supplies one
/// of your own when that shape is [HintArrowShape.custom]. Every built-in
/// shape occupies exactly the same [arrowSize] box, so switching between them
/// never moves the bubble; a custom caret is free to draw outside it, at the
/// cost of that guarantee.
Path buildBubblePath({
  required Rect rect,
  required BorderRadius borderRadius,
  required HintSide side,
  required double arrowFraction,
  required Size arrowSize,
  HintArrowShape arrowShape = HintArrowShape.triangle,
  HintArrowBuilder? arrowBuilder,
}) {
  assert(rect.isFinite, 'buildBubblePath: rect must be finite, got $rect.');
  assert(
    arrowFraction >= 0 && arrowFraction <= 1,
    'buildBubblePath: arrowFraction must be in 0..1, got $arrowFraction.',
  );
  assert(
    arrowSize.width >= 0 && arrowSize.height >= 0,
    'buildBubblePath: arrowSize must be non-negative, got $arrowSize.',
  );

  final BorderRadius radius = _clampRadius(borderRadius, rect.size);
  final Path body = Path()..addRRect(radius.toRRect(rect));
  if (arrowSize.isEmpty || rect.isEmpty) {
    return body;
  }

  // The arrow's base sits *on* the body edge and its apex points away from the
  // bubble, towards the target. The base is sunk into the body by a hair so
  // the union never leaves a hairline crack along the shared edge.
  const double overlap = 0.5;
  final double half = arrowSize.width / 2;
  final double depth = arrowSize.height;

  // Where the caret meets the body, and which way is "along the edge".
  final Offset baseCentre;
  final Offset along;
  final Offset tip;
  switch (side) {
    case HintSide.top:
      // Bubble above the target: the caret hangs off the bottom edge.
      final double x = rect.left + rect.width * arrowFraction;
      baseCentre = Offset(x, rect.bottom - overlap);
      along = const Offset(1, 0);
      tip = Offset(x, rect.bottom + depth);
    case HintSide.bottom:
      final double x = rect.left + rect.width * arrowFraction;
      baseCentre = Offset(x, rect.top + overlap);
      along = const Offset(1, 0);
      tip = Offset(x, rect.top - depth);
    case HintSide.left:
      final double y = rect.top + rect.height * arrowFraction;
      baseCentre = Offset(rect.right - overlap, y);
      along = const Offset(0, 1);
      tip = Offset(rect.right + depth, y);
    case HintSide.right:
      final double y = rect.top + rect.height * arrowFraction;
      baseCentre = Offset(rect.left + overlap, y);
      along = const Offset(0, 1);
      tip = Offset(rect.left - depth, y);
  }

  assert(
    arrowShape != HintArrowShape.custom || arrowBuilder != null,
    'HintArrowShape.custom needs a HintThemeData.arrowBuilder to draw it. '
    'Falling back to a triangle.',
  );
  final Path arrow = switch (arrowShape) {
    HintArrowShape.custom when arrowBuilder != null => arrowBuilder(
        HintArrowGeometry(
          baseCentre: baseCentre,
          along: along,
          tip: tip,
          halfWidth: half,
          side: side,
          size: arrowSize,
        ),
      ),
    HintArrowShape.curved => _curvedArrow(
        baseCentre: baseCentre,
        along: along,
        tip: tip,
        half: half,
      ),
    // A custom shape with no builder lands here too, which is the documented
    // fallback for the release build of the assert above.
    HintArrowShape.triangle || HintArrowShape.custom => _triangleArrow(
        baseCentre: baseCentre,
        along: along,
        tip: tip,
        half: half,
      ),
  };

  return Path.combine(PathOperation.union, body, arrow);
}

/// A straight-sided caret: two lines from the base corners to the tip.
Path _triangleArrow({
  required Offset baseCentre,
  required Offset along,
  required Offset tip,
  required double half,
}) {
  final Offset a = baseCentre - along * half;
  final Offset b = baseCentre + along * half;
  return Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(b.dx, b.dy)
    ..close();
}

/// A tapered caret whose flanks curve out of the body edge.
///
/// Each flank is a cubic that leaves the base *parallel to the edge* — its
/// first control point lies on the edge itself — and then falls away towards
/// the tip. There is therefore no corner where the caret meets the body: the
/// two flow into one another, the way a speech balloon's tail does.
///
/// The consequence is that the flanks are concave, so between the base and the
/// tip the caret is slimmer than a straight taper would be. It still spans the
/// full base width, so the union never leaves a notch beside it.
Path _curvedArrow({
  required Offset baseCentre,
  required Offset along,
  required Offset tip,
  required double half,
}) {
  // How far the tangent runs along the edge before the flank turns: larger
  // values give a wider, softer sweep.
  const double sweep = 0.55;
  // How close to the tip the flank is still leaning sideways: smaller values
  // give a sharper point.
  const double taper = 0.08;
  // Where along the caret's depth the flank has finished turning.
  const double shoulder = 0.62;

  final Offset a = baseCentre - along * half;
  final Offset b = baseCentre + along * half;
  final Offset depth = tip - baseCentre;
  final Offset shoulderPoint = baseCentre + depth * shoulder;

  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(
      // Tangent along the edge, so the flank leaves the body smoothly.
      (a + along * (half * sweep)).dx,
      (a + along * (half * sweep)).dy,
      (shoulderPoint - along * (half * taper)).dx,
      (shoulderPoint - along * (half * taper)).dy,
      tip.dx,
      tip.dy,
    )
    ..cubicTo(
      (shoulderPoint + along * (half * taper)).dx,
      (shoulderPoint + along * (half * taper)).dy,
      (b - along * (half * sweep)).dx,
      (b - along * (half * sweep)).dy,
      b.dx,
      b.dy,
    )
    ..close();
}

/// Shrinks [radius] until it fits inside [size].
///
/// A radius larger than half the box makes [RRect] renormalise silently and
/// throws off the arrow inset maths, so it is clamped up front.
BorderRadius _clampRadius(BorderRadius radius, Size size) {
  final double limit = size.shortestSide / 2;
  if (limit <= 0) {
    return BorderRadius.zero;
  }
  Radius clamp(Radius r) => Radius.elliptical(
        r.x.clamp(0.0, limit),
        r.y.clamp(0.0, limit),
      );
  return BorderRadius.only(
    topLeft: clamp(radius.topLeft),
    topRight: clamp(radius.topRight),
    bottomLeft: clamp(radius.bottomLeft),
    bottomRight: clamp(radius.bottomRight),
  );
}

/// Paints a hint bubble: fill, optional border and optional drop shadow, all
/// from the single path built by [buildBubblePath].
///
/// Painted rather than composed from widgets so that the arrow and the body
/// share one outline. This is exposed for callers who want the bubble
/// chrome around their own content without the overlay machinery — a legend, a
/// static callout in a diagram, a screenshot in documentation.
class HintBubbleDecoration extends StatelessWidget {
  /// Creates the bubble chrome around [child].
  const HintBubbleDecoration({
    required this.side,
    required this.arrowFraction,
    required this.theme,
    required this.child,
    super.key,
  });

  /// The side of the target this bubble sits on.
  ///
  /// The arrow grows from the opposite edge: a bubble on [HintSide.top] has
  /// its caret on the bottom.
  final HintSide side;

  /// Where the arrow sits along the anchored edge, as a fraction in 0..1.
  final double arrowFraction;

  /// Resolved visual configuration. Obtain one with [HintThemeData.resolve].
  final ResolvedHintTheme theme;

  /// The bubble's content. It is padded by `theme.padding`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double blur = theme.backgroundBlur;
    final Widget painted = CustomPaint(
      painter: _BubblePainter(
        side: side,
        arrowFraction: arrowFraction,
        borderRadius: theme.borderRadius,
        arrowSize: theme.arrowSize,
        arrowShape: theme.arrowShape,
        arrowBuilder: theme.arrowBuilder,
        backgroundColor: theme.backgroundColor,
        borderColor: theme.borderColor,
        borderWidth: theme.borderWidth,
        // With a backdrop blur the shadow is painted outside the clip, by the
        // pass below; painting it here too would double it.
        elevation: blur > 0 ? 0 : theme.elevation,
        shadowColor: theme.shadowColor,
        textDirection: Directionality.of(context),
      ),
      child: Padding(padding: theme.padding, child: child),
    );
    if (blur <= 0) {
      return painted;
    }

    // Frosted glass: blur whatever is behind the bubble, clipped to the same
    // fused silhouette the fill uses, so the caret is frosted too.
    //
    // The shadow has to be painted *outside* the clip — it lies beyond the
    // path by definition, so a ClipPath would erase it.
    final _BubbleClipper clipper = _BubbleClipper(
      side: side,
      arrowFraction: arrowFraction,
      borderRadius: theme.borderRadius,
      arrowSize: theme.arrowSize,
      arrowShape: theme.arrowShape,
      arrowBuilder: theme.arrowBuilder,
    );
    return CustomPaint(
      painter: _ShadowPainter(
        clipper: clipper,
        elevation: theme.elevation,
        shadowColor: theme.shadowColor,
      ),
      child: ClipPath(
        clipper: clipper,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: painted,
        ),
      ),
    );
  }
}

/// Clips to the fused body-and-arrow silhouette.
///
/// Shared by the backdrop filter and the shadow pass so the two cannot
/// disagree about where the bubble's edge is.
class _BubbleClipper extends CustomClipper<Path> {
  const _BubbleClipper({
    required this.side,
    required this.arrowFraction,
    required this.borderRadius,
    required this.arrowSize,
    required this.arrowShape,
    required this.arrowBuilder,
  });

  final HintSide side;
  final double arrowFraction;
  final BorderRadius borderRadius;
  final Size arrowSize;
  final HintArrowShape arrowShape;
  final HintArrowBuilder? arrowBuilder;

  @override
  Path getClip(Size size) => buildBubblePath(
        rect: Offset.zero & size,
        borderRadius: borderRadius,
        side: side,
        arrowFraction: arrowFraction,
        arrowSize: arrowSize,
        arrowShape: arrowShape,
        arrowBuilder: arrowBuilder,
      );

  @override
  bool shouldReclip(_BubbleClipper old) =>
      old.side != side ||
      old.arrowFraction != arrowFraction ||
      old.borderRadius != borderRadius ||
      old.arrowSize != arrowSize ||
      old.arrowShape != arrowShape ||
      old.arrowBuilder != arrowBuilder;
}

/// Paints only the drop shadow, for the blurred variant.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter({
    required this.clipper,
    required this.elevation,
    required this.shadowColor,
  });

  final _BubbleClipper clipper;
  final double elevation;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || elevation <= 0) {
      return;
    }
    canvas.drawShadow(clipper.getClip(size), shadowColor, elevation, false);
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.elevation != elevation ||
      old.shadowColor != shadowColor ||
      clipper.shouldReclip(old.clipper);

  @override
  bool hitTest(Offset position) => false;
}

/// Paints the fused body-and-arrow path.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.side,
    required this.arrowFraction,
    required this.borderRadius,
    required this.arrowSize,
    required this.arrowShape,
    required this.arrowBuilder,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.elevation,
    required this.shadowColor,
    required this.textDirection,
  });

  final HintSide side;
  final double arrowFraction;
  final BorderRadius borderRadius;
  final Size arrowSize;
  final HintArrowShape arrowShape;
  final HintArrowBuilder? arrowBuilder;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double elevation;
  final Color shadowColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Path path = buildBubblePath(
      rect: Offset.zero & size,
      borderRadius: borderRadius,
      side: side,
      arrowFraction: arrowFraction,
      arrowSize: arrowSize,
      arrowShape: arrowShape,
      arrowBuilder: arrowBuilder,
    );

    if (elevation > 0) {
      // One shadow for the whole silhouette, arrow included.
      canvas.drawShadow(path, shadowColor, elevation, false);
    }
    canvas.drawPath(path, Paint()..color = backgroundColor);
    if (borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.side != side ||
      old.arrowFraction != arrowFraction ||
      old.borderRadius != borderRadius ||
      old.arrowSize != arrowSize ||
      old.arrowShape != arrowShape ||
      old.arrowBuilder != arrowBuilder ||
      old.backgroundColor != backgroundColor ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.elevation != elevation ||
      old.shadowColor != shadowColor ||
      old.textDirection != textDirection;

  /// The bubble is decorative; its content carries the semantics.
  @override
  bool hitTest(Offset position) => false;
}

/// The default contents of a hint bubble: an optional title above a message.
///
/// Used when a [Hint] is given a `message` and/or `title` rather than a
/// `contentBuilder`.
class HintBubbleContent extends StatelessWidget {
  /// Creates the default bubble content.
  ///
  /// At least one of [title] and [message] should be non-null; a bubble with
  /// neither renders as an empty box, which is almost always a mistake.
  const HintBubbleContent({
    required this.theme,
    this.title,
    this.message,
    super.key,
  });

  /// Bold line shown above [message].
  final String? title;

  /// The body text.
  final String? message;

  /// Resolved visual configuration.
  final ResolvedHintTheme theme;

  @override
  Widget build(BuildContext context) {
    assert(
      title != null || message != null,
      'HintBubbleContent needs a title or a message. Pass a contentBuilder to '
      'a Hint if you want arbitrary widget content.',
    );
    final String? titleText = title;
    final String? messageText = message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (titleText != null) Text(titleText, style: theme.titleStyle),
        if (titleText != null && messageText != null) const SizedBox(height: 2),
        if (messageText != null) Text(messageText, style: theme.messageStyle),
      ],
    );
  }
}
