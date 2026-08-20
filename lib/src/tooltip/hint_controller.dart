/// @docImport 'package:flutter/widgets.dart';
/// @docImport 'hint.dart';
library;

import 'package:flutter/foundation.dart';

/// Drives a [Hint] programmatically.
///
/// Attach one to a hint to show, hide or toggle it from anywhere — a bloc, a
/// button, a failed validation:
///
/// ```dart
/// final HintController _hint = HintController();
///
/// Hint(
///   controller: _hint,
///   triggers: const <HintTrigger>{HintTrigger.manual},
///   message: 'You need an active shift to check in',
///   child: checkInButton,
/// )
///
/// // later
/// _hint.show();
/// ```
///
/// A controller drives exactly one hint at a time. Attaching the same
/// controller to two mounted hints asserts in debug builds, because [isShown]
/// could not then describe either of them honestly.
///
/// Dispose it with the [State] that owns it.
class HintController extends ChangeNotifier {
  /// Creates a controller for a hint that starts hidden.
  HintController();

  bool _isShown = false;
  bool _isAttached = false;
  final ValueNotifier<int> _refreshRequests = ValueNotifier<int>(0);

  /// notifyListeners is protected; this lets the package-internal helpers
  /// below reach it without tripping the protected-member lint.
  void _notify() => notifyListeners();

  /// Whether the attached hint is currently open.
  ///
  /// This flips as soon as [show] is called — at the *start* of the entry
  /// animation — and stays true until something hides the hint. It does not
  /// mean "the bubble has finished animating in".
  ///
  /// It also tracks dismissals the hint initiated itself, such as a tap
  /// outside or an auto-hide timer, so it never goes stale.
  bool get isShown => _isShown;

  /// Whether a mounted [Hint] is currently listening to this controller.
  ///
  /// A `show()` issued while detached is remembered, so calling it in
  /// `initState` before the hint has mounted still works.
  bool get isAttached => _isAttached;

  /// Opens the hint. A no-op if it is already open.
  void show() {
    if (_isShown) {
      return;
    }
    _isShown = true;
    notifyListeners();
  }

  /// Closes the hint. A no-op if it is already closed.
  void hide() {
    if (!_isShown) {
      return;
    }
    _isShown = false;
    notifyListeners();
  }

  /// Closes the hint if it is open, opens it otherwise.
  void toggle() => _isShown ? hide() : show();

  /// Forces the attached hint to re-measure its target and re-resolve its
  /// placement.
  ///
  /// Needed only when the target moves in a way the tracker cannot observe: an
  /// externally driven layout animation, or a parent that resizes without
  /// scrolling and without a window metrics change. A no-op while the hint is
  /// closed, since it will measure on the way open anyway.
  void refresh() {
    if (!_isShown) {
      return;
    }
    _refreshRequests.value++;
  }

  @override
  void dispose() {
    _refreshRequests.dispose();
    super.dispose();
  }

  @override
  String toString() =>
      'HintController(isShown: $_isShown, isAttached: $_isAttached)';
}

// -----------------------------------------------------------------------------
// Package-internal plumbing.
//
// These are top-level functions rather than methods so that they can reach the
// controller's private state from elsewhere in the package without appearing
// in the public API: the barrel exports this file with a `show` clause that
// names only HintController.
// -----------------------------------------------------------------------------

/// Marks [controller] as driven by a mounted hint.
void attachHintController(HintController controller) {
  assert(
    !controller._isAttached,
    'This HintController is already attached to a mounted Hint. A controller '
    'drives exactly one hint; give the second hint its own controller.',
  );
  controller._isAttached = true;
}

/// Undoes [attachHintController].
void detachHintController(HintController controller) {
  controller._isAttached = false;
}

/// Records a show or hide that the hint itself initiated, without bouncing the
/// call back into the hint.
void syncHintController(HintController controller, {required bool shown}) {
  if (controller._isShown == shown) {
    return;
  }
  controller._isShown = shown;
  controller._notify();
}

/// Fires whenever [HintController.refresh] is called.
ValueListenable<int> hintRefreshRequests(HintController controller) =>
    controller._refreshRequests;
