/// @docImport 'package:flutter/widgets.dart';
library;

import 'package:flutter/foundation.dart';

/// Something that can be asked to close itself.
///
/// Implemented by the private state of `Hint`; exposed as an interface so the
/// registry does not depend on the widget layer.
abstract class DismissibleHint {
  /// Closes this hint because something else wants the floor.
  void dismissForExclusivity();
}

/// Keeps at most one exclusive hint open across the whole app.
///
/// Two tooltips open at once is nearly always a bug — a stray hover leaves one
/// behind, then a long press opens a second on top of it. Hints opt in via
/// `Hint.exclusive`, which defaults to true.
///
/// Non-exclusive hints are never registered, so a persistent hint that is
/// meant to stay open (a validation message pinned to a field) is not closed
/// by an unrelated tooltip.
///
/// This is process-global on purpose: an [InheritedWidget] would scope it to a
/// subtree, and the overlay it is protecting is not scoped that way.
class HintRegistry {
  HintRegistry._();

  /// The single registry instance.
  static final HintRegistry instance = HintRegistry._();

  DismissibleHint? _current;

  /// The hint currently holding the floor, if any.
  @visibleForTesting
  DismissibleHint? get current => _current;

  /// Registers [hint] as the open one, closing whichever hint held the floor.
  ///
  /// Called by a hint as it opens, before its entry animation starts.
  void open(DismissibleHint hint) {
    final DismissibleHint? previous = _current;
    _current = hint;
    if (previous != null && !identical(previous, hint)) {
      previous.dismissForExclusivity();
    }
  }

  /// Releases the floor if [hint] is holding it.
  ///
  /// Passing a hint that is not current is a no-op, which matters because a
  /// hint that was already displaced still calls this when it finishes
  /// closing.
  void close(DismissibleHint hint) {
    if (identical(_current, hint)) {
      _current = null;
    }
  }

  /// Closes whatever is open. Used by tour startup and by tests.
  void closeAll() {
    final DismissibleHint? previous = _current;
    _current = null;
    previous?.dismissForExclusivity();
  }
}
