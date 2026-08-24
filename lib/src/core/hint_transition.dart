/// @docImport '../theme/hint_theme.dart';
/// @docImport '../tooltip/hint.dart';
library;

import 'package:flutter/widgets.dart';

import 'hint_side.dart';

/// Signature for a bubble's show and hide animation.
///
/// Set one on [HintThemeData.transitionBuilder] to animate a bubble any way
/// you like. [child] is the finished bubble — chrome, arrow and content — and
/// the returned widget replaces it, so wrap rather than rebuild.
///
/// ```dart
/// HintThemeData(
///   transitionBuilder: (BuildContext context, HintTransitionInfo info,
///       Widget child) {
///     return FadeTransition(
///       opacity: info.opacity,
///       child: RotationTransition(
///         turns: Tween<double>(begin: -0.02, end: 0).animate(info.animation),
///         alignment: info.origin,
///         child: child,
///       ),
///     );
///   },
/// )
/// ```
///
/// {@category Theming}
typedef HintTransitionBuilder = Widget Function(
  BuildContext context,
  HintTransitionInfo info,
  Widget child,
);

/// Everything a [HintTransitionBuilder] needs to animate a bubble.
///
/// {@category Theming}
@immutable
class HintTransitionInfo {
  /// Creates the info handed to a transition builder.
  const HintTransitionInfo({
    required this.animation,
    required this.opacity,
    required this.side,
    required this.origin,
  });

  /// The show/hide animation, with [HintThemeData.transitionCurve] applied.
  ///
  /// `0` is hidden and `1` is shown. It runs forwards on show and backwards on
  /// hide, so a transition never needs to know which way it is going.
  ///
  /// An overshooting curve — [Curves.easeOutBack], say — drives this **past**
  /// 1, which is exactly what makes a bounce read. Never pass it to something
  /// that requires 0..1, such as [FadeTransition]; use [opacity] there.
  final Animation<double> animation;

  /// [animation] clamped to 0..1, safe for opacity.
  final Animation<double> opacity;

  /// The side of the target the bubble was placed on.
  ///
  /// A bubble on [HintSide.top] sits *above* its target with its caret
  /// pointing down.
  final HintSide side;

  /// Where the caret meets the bubble, as an [Alignment] of the bubble's box.
  ///
  /// The natural anchor for a scale or rotation: growing from the caret reads
  /// as "this belongs to the thing you just touched", growing from the centre
  /// reads as a dialog.
  final Alignment origin;

  /// A unit vector pointing from the bubble towards its target.
  ///
  /// Useful for a slide: starting a few percent along this and ending at zero
  /// means the bubble always arrives *away* from what it explains, whichever
  /// side placement chose.
  Offset get towardsTarget => switch (side) {
        HintSide.top => const Offset(0, 1),
        HintSide.bottom => const Offset(0, -1),
        HintSide.left => const Offset(1, 0),
        HintSide.right => const Offset(-1, 0),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HintTransitionInfo &&
          other.animation == animation &&
          other.opacity == opacity &&
          other.side == side &&
          other.origin == origin;

  @override
  int get hashCode => Object.hash(animation, opacity, side, origin);
}

/// A ready-made show/hide animation for a hint bubble.
///
/// Set it on [HintThemeData.transition], app-wide or per hint. For anything
/// these do not cover, [HintThemeData.transitionBuilder] takes a closure and
/// wins over this.
///
/// Every one of them is driven by the same animation, so
/// [HintThemeData.transitionDuration], [HintThemeData.transitionCurve] and
/// [HintThemeData.reverseTransitionDuration] all still apply — and all of them
/// collapse to an instant appearance under
/// [MediaQueryData.disableAnimations].
///
/// {@category Theming}
enum HintTransition {
  /// Fade and a small scale out of the caret. The default.
  ///
  /// The scale is deliberately slight: a bubble that pops is noise, a bubble
  /// that grows a few percent reads as attached to the thing you touched.
  scale,

  /// Opacity only.
  ///
  /// The quietest option, and the right one when the bubble is large enough
  /// that scaling it would look like a zoom.
  fade,

  /// Fade plus a scale that overshoots slightly before settling.
  ///
  /// Playful; pairs with a rounded design. Needs a curve that does not
  /// overshoot as well ([Curves.easeOutCubic] is fine) or the two compound.
  pop,

  /// Fade plus a short slide away from the target.
  ///
  /// The bubble arrives from the direction of what it explains, which makes
  /// the connection without any scaling at all.
  slide,

  /// No animation: the bubble is simply there, then gone.
  ///
  /// Not the same as a zero duration — nothing is wrapped at all, so there is
  /// no transition widget in the tree. Useful for tests and for UIs where
  /// motion is unwelcome.
  none;

  /// Applies this transition to [child].
  ///
  /// Exposed so a custom [HintTransitionBuilder] can build on one instead of
  /// starting from nothing:
  ///
  /// ```dart
  /// transitionBuilder: (BuildContext context, HintTransitionInfo info,
  ///         Widget child) =>
  ///     HintTransition.fade.build(context, info, myWrapper(child)),
  /// ```
  Widget build(BuildContext context, HintTransitionInfo info, Widget child) {
    switch (this) {
      case HintTransition.none:
        return child;

      case HintTransition.fade:
        return FadeTransition(opacity: info.opacity, child: child);

      case HintTransition.scale:
        return FadeTransition(
          opacity: info.opacity,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(info.animation),
            alignment: info.origin,
            child: child,
          ),
        );

      case HintTransition.pop:
        return FadeTransition(
          opacity: info.opacity,
          child: ScaleTransition(
            scale: TweenSequence<double>(<TweenSequenceItem<double>>[
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: 0.82, end: 1.04)
                    .chain(CurveTween(curve: Curves.easeOut)),
                weight: 70,
              ),
              TweenSequenceItem<double>(
                tween: Tween<double>(begin: 1.04, end: 1)
                    .chain(CurveTween(curve: Curves.easeIn)),
                weight: 30,
              ),
            ]).animate(info.opacity),
            alignment: info.origin,
            child: child,
          ),
        );

      case HintTransition.slide:
        return FadeTransition(
          opacity: info.opacity,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: info.towardsTarget * 0.12,
              end: Offset.zero,
            ).animate(info.animation),
            child: child,
          ),
        );
    }
  }
}

/// Wraps [animation] so its value never leaves 0..1.
///
/// [HintThemeData.transitionCurve] may overshoot, and an opacity that does is
/// an assertion failure rather than a nice bounce. Clamping is done here, once,
/// so neither the built-in transitions nor a custom builder has to think about
/// it.
Animation<double> clampHintAnimation(Animation<double> animation) =>
    _ClampedAnimation(animation);

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);

  @override
  String toString() => 'ClampedAnimation($parent → $value)';
}
