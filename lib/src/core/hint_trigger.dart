/// @docImport 'package:flutter/widgets.dart';
/// @docImport '../tooltip/hint.dart';
/// @docImport '../tooltip/hint_controller.dart';
library;

/// What makes a [Hint] appear.
///
/// A hint takes a *set* of triggers, so a widget can respond to both a long
/// press on touch and a hover on desktop from one declaration:
///
/// ```dart
/// Hint(
///   message: 'Check in',
///   triggers: const <HintTrigger>{HintTrigger.longPress, HintTrigger.hover},
///   child: button,
/// )
/// ```
///
/// Triggers are read from a raw [Listener], not a [GestureDetector], so they
/// fire even when the child ignores pointers — a disabled button, for example
/// — without stealing the gesture from a child that does handle it.
enum HintTrigger {
  /// Show on a tap, hide on the next tap.
  ///
  /// The tap is recognised from raw pointer events using a slop radius, so it
  /// does not enter the gesture arena and cannot beat the child's own
  /// [GestureDetector].
  tap,

  /// Show on a long press.
  ///
  /// This is the platform-conventional tooltip trigger on touch devices.
  longPress,

  /// Show on a right-click, hide on the next one.
  ///
  /// The desktop conventional gesture for "tell me about this thing" when the
  /// primary click already does something. Recognised from the pointer's
  /// buttons, so it never competes with a child's own secondary-tap handler,
  /// and a primary click does not open it.
  secondaryTap,

  /// Show while the pointer is over the target.
  ///
  /// Respects `waitDuration` before showing. When the hint is `interactive`,
  /// moving the pointer from the target into the bubble does not dismiss it.
  hover,

  /// Show while the target holds keyboard focus.
  ///
  /// Pair with [HintTrigger.hover] to make a form field explain itself to both
  /// mouse and keyboard users.
  focus,

  /// Never shown automatically; only a [HintController] can open it.
  ///
  /// This is the trigger for genuinely programmatic hints — validation
  /// messages, a "you have an unsaved draft" nudge.
  manual,

  /// Show as soon as the target is mounted and laid out.
  ///
  /// Combine with `showDuration` for a transient nudge, or leave it open as a
  /// persistent hint. Under [MediaQueryData.accessibleNavigation] the
  /// auto-hide timer is suppressed, since a screen-reader user cannot read a
  /// bubble that vanishes after two seconds.
  onAppear,
}
