/// @docImport 'package:flutter/painting.dart';
library;

/// The side of a target a hint bubble may be asked to appear on.
///
/// This is the *requested* direction. Use [HintSide] for the side the
/// placement resolver actually settled on.
///
/// {@category Hints}
enum HintDirection {
  /// Place the bubble above the target.
  top,

  /// Place the bubble below the target.
  bottom,

  /// Place the bubble to the left of the target.
  ///
  /// In a right-to-left [TextDirection] this resolves to the visual *right*.
  left,

  /// Place the bubble to the right of the target.
  ///
  /// In a right-to-left [TextDirection] this resolves to the visual *left*.
  right,

  /// Let the resolver choose, preferring [bottom], then [top], then whichever
  /// of [right]/[left] has more free space.
  auto,
}

/// The side a hint bubble was actually placed on, after resolution.
///
/// Unlike [HintDirection] this is always a concrete, visual side: text
/// direction has already been applied and `auto` has already been decided.
///
/// {@category Advanced}
enum HintSide {
  /// The bubble sits above the target; its arrow points down.
  top,

  /// The bubble sits below the target; its arrow points up.
  bottom,

  /// The bubble sits to the visual left of the target; its arrow points right.
  left,

  /// The bubble sits to the visual right of the target; its arrow points left.
  right;

  /// Whether this side stacks the bubble vertically relative to the target.
  bool get isVertical => this == HintSide.top || this == HintSide.bottom;

  /// Whether this side stacks the bubble horizontally relative to the target.
  bool get isHorizontal => !isVertical;

  /// The side directly opposite this one.
  HintSide get opposite => switch (this) {
        HintSide.top => HintSide.bottom,
        HintSide.bottom => HintSide.top,
        HintSide.left => HintSide.right,
        HintSide.right => HintSide.left,
      };
}
