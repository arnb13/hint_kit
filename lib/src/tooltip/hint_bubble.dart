/// @docImport 'hint.dart';
library;

import 'package:flutter/material.dart';

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
Path buildBubblePath({
  required Rect rect,
  required BorderRadius borderRadius,
  required HintSide side,
  required double arrowFraction,
  required Size arrowSize,
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

  // The arrow is a triangle whose base sits *on* the body edge and whose apex
  // points away from the bubble, towards the target. Its base is widened by a
  // hair so the union never leaves a hairline crack along the shared edge.
  const double overlap = 0.5;
  final double half = arrowSize.width / 2;
  final double depth = arrowSize.height;
  final Path arrow = Path();

  switch (side) {
    case HintSide.top:
      // Bubble above the target: arrow hangs off the bottom edge.
      final double x = rect.left + rect.width * arrowFraction;
      arrow
        ..moveTo(x - half, rect.bottom - overlap)
        ..lineTo(x, rect.bottom + depth)
        ..lineTo(x + half, rect.bottom - overlap);
    case HintSide.bottom:
      final double x = rect.left + rect.width * arrowFraction;
      arrow
        ..moveTo(x - half, rect.top + overlap)
        ..lineTo(x, rect.top - depth)
        ..lineTo(x + half, rect.top + overlap);
    case HintSide.left:
      final double y = rect.top + rect.height * arrowFraction;
      arrow
        ..moveTo(rect.right - overlap, y - half)
        ..lineTo(rect.right + depth, y)
        ..lineTo(rect.right - overlap, y + half);
    case HintSide.right:
      final double y = rect.top + rect.height * arrowFraction;
      arrow
        ..moveTo(rect.left + overlap, y - half)
        ..lineTo(rect.left - depth, y)
        ..lineTo(rect.left + overlap, y + half);
  }
  arrow.close();

  return Path.combine(PathOperation.union, body, arrow);
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
    return CustomPaint(
      painter: _BubblePainter(
        side: side,
        arrowFraction: arrowFraction,
        borderRadius: theme.borderRadius,
        arrowSize: theme.arrowSize,
        backgroundColor: theme.backgroundColor,
        borderColor: theme.borderColor,
        borderWidth: theme.borderWidth,
        elevation: theme.elevation,
        shadowColor: theme.shadowColor,
        textDirection: Directionality.of(context),
      ),
      child: Padding(padding: theme.padding, child: child),
    );
  }
}

/// Paints the fused body-and-arrow path.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.side,
    required this.arrowFraction,
    required this.borderRadius,
    required this.arrowSize,
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
