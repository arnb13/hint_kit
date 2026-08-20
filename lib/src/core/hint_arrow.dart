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
}
