/// @docImport 'package:flutter/widgets.dart';
/// @docImport '../tour/tour_scope.dart';
/// @docImport 'hint.dart';
library;

import 'package:flutter/foundation.dart';

import '../core/hint_observer.dart';
import '../core/tour_end_reason.dart';
import '../tour/tour_storage.dart';

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

  // ---------------------------------------------------------------------------
  // Show-once storage
  // ---------------------------------------------------------------------------

  /// Where [Hint.showOnce] keys are remembered.
  ///
  /// Defaults to an [InMemoryTourStorage], so a "seen it" hint comes back on
  /// the next launch until you point this at real persistence — once, at
  /// startup:
  ///
  /// ```dart
  /// void main() {
  ///   HintRegistry.instance.storage = CallbackTourStorage(
  ///     isCompleted: (String key) async => prefs.getBool(key) ?? false,
  ///     setCompleted: (String key, bool seen) async =>
  ///         seen ? prefs.setBool(key, true) : prefs.remove(key),
  ///   );
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// It is the same interface tours use, and the same instance can serve both
  /// — pass it to [TourScope.storage] as well. Keys are whatever string a hint
  /// was given, so keep hint keys and tour names distinct.
  TourStorage storage = InMemoryTourStorage();

  /// Forgets the "already shown" flag for a [Hint.showOnce] key, so that hint
  /// appears again.
  ///
  /// The counterpart to a "replay the tour" button, and the reset a test needs
  /// between cases.
  Future<void> resetShowOnce(String key) => storage.reset(key);

  // ---------------------------------------------------------------------------
  // Observers
  // ---------------------------------------------------------------------------

  final List<HintObserver> _observers = <HintObserver>[];

  /// Starts reporting hint and tour lifecycle events to [observer].
  ///
  /// Adding the same observer twice makes it hear everything twice; the
  /// registry does not deduplicate, so that two identical const observers are
  /// still two subscriptions.
  void addObserver(HintObserver observer) => _observers.add(observer);

  /// Stops reporting to [observer]. Unknown observers are ignored.
  void removeObserver(HintObserver observer) => _observers.remove(observer);

  /// Drops every observer.
  ///
  /// For tests: the registry outlives a widget tree, so an observer registered
  /// in one test is still listening in the next. `resetHintKit()` from
  /// `package:hint_kit/testing.dart` calls this.
  void removeAllObservers() => _observers.clear();

  /// Reports that a hint opened. Called by `Hint`, not by app code.
  void notifyShown(HintEvent event) => _each((HintObserver o) {
        o.didShowHint(event);
      });

  /// Reports that a hint closed. Called by `Hint`, not by app code.
  void notifyDismissed(HintEvent event) => _each((HintObserver o) {
        o.didDismissHint(event);
      });

  /// Reports that a tour started. Called by `TourController`.
  void notifyTourStarted(String tour) => _each((HintObserver o) {
        o.didStartTour(tour);
      });

  /// Reports that a tour reached a step. Called by `TourController`.
  void notifyTourStep(String tour, int index) => _each((HintObserver o) {
        o.didChangeTourStep(tour, index);
      });

  /// Reports that a tour ended. Called by `TourController`.
  void notifyTourEnded(String tour, TourEndReason reason) =>
      _each((HintObserver o) {
        o.didEndTour(tour, reason);
      });

  /// Visits every observer over a copy of the list.
  ///
  /// An observer that adds or removes one from its callback is legal — and
  /// would otherwise throw a concurrent-modification error.
  void _each(void Function(HintObserver observer) visit) {
    if (_observers.isEmpty) {
      return;
    }
    for (final HintObserver observer in List<HintObserver>.of(_observers)) {
      visit(observer);
    }
  }
}
