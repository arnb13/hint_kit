/// @docImport 'package:flutter/rendering.dart';
/// @docImport '../theme/hint_theme.dart';
library;

import 'dart:ui' show Offset, Path, Size;

import 'package:flutter/foundation.dart';

import 'hint_side.dart';

/// Signature for a caret of your own.
///
/// Set one on [HintThemeData.arrowBuilder] together with
/// [HintArrowShape.custom]. Return a closed [Path] in the same coordinate
/// space as [HintArrowGeometry.tip] — the bubble's own space. It is unioned
/// into the body, so the border and the shadow stay continuous however odd
/// the silhouette is.
typedef HintArrowBuilder = Path Function(HintArrowGeometry geometry);

/// Where the caret sits and which way it points, handed to a
/// [HintArrowBuilder].
///
/// Everything is already resolved for the side the bubble landed on, so a
/// custom caret is written once and works on all four edges: build it from
/// [baseCentre], [along] and [tip] rather than from raw x/y.
@immutable
class HintArrowGeometry {
  /// Creates the geometry handed to a custom arrow builder.
  const HintArrowGeometry({
    required this.baseCentre,
    required this.along,
    required this.tip,
    required this.halfWidth,
    required this.side,
    required this.size,
  });

  /// The midpoint of the caret's base, on the bubble's edge.
  final Offset baseCentre;

  /// A unit vector along that edge.
  ///
  /// `baseCentre - along * halfWidth` and `baseCentre + along * halfWidth` are
  /// the two ends of the base.
  final Offset along;

  /// The point of the caret, [HintThemeData.arrowSize]`.height` away from the
  /// bubble in the direction of the target.
  final Offset tip;

  /// Half the caret's width along the edge.
  final double halfWidth;

  /// The side of the *target* the bubble sits on.
  ///
  /// The caret grows from the opposite edge of the bubble: on
  /// [HintSide.top] the bubble is above the target and the caret hangs off its
  /// bottom edge.
  final HintSide side;

  /// The caret's box: width along the edge, height away from it.
  final Size size;

  /// The base corner on the [along]-negative side.
  Offset get baseStart => baseCentre - along * halfWidth;

  /// The base corner on the [along]-positive side.
  Offset get baseEnd => baseCentre + along * halfWidth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HintArrowGeometry &&
          other.baseCentre == baseCentre &&
          other.along == along &&
          other.tip == tip &&
          other.halfWidth == halfWidth &&
          other.side == side &&
          other.size == size;

  @override
  int get hashCode =>
      Object.hash(baseCentre, along, tip, halfWidth, side, size);
}

/// The silhouette of the caret that connects a bubble to its target.
///
/// Set it on `HintThemeData.arrowShape`, per hint or app-wide:
///
/// ```dart
/// HintThemeData(arrowShape: HintArrowShape.curved)
/// ```
///
/// Whichever shape is used, the caret is unioned into the bubble body as a
/// single path, so the border stroke and the drop shadow stay continuous.
enum HintArrowShape {
  /// A straight-sided triangle. The default.
  ///
  /// Crisp at any size and the conventional tooltip caret on every platform.
  triangle,

  /// A tapered caret whose flanks curve out of the bubble edge.
  ///
  /// The flanks leave the body edge horizontally and converge on the tip, so
  /// there is no visible corner where the caret meets the body — the effect a
  /// speech balloon has. It reads better on a large caret, on a bubble with a
  /// visible border, and against a generous corner radius; at very small sizes
  /// the curvature is not worth the extra path.
  curved,

  /// A caret of your own, drawn by [HintThemeData.arrowBuilder].
  ///
  /// Without a builder this falls back to [triangle] and asserts in debug: the
  /// shape and the builder are two halves of one setting.
  custom,
}
