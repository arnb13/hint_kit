/// @docImport 'package:flutter/widgets.dart';
/// @docImport '../tour/tour_controller.dart';
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
///
/// {@category Hints}
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
  /// startup. With `shared_preferences`, in full:
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   // Both lines: getInstance is async, and awaiting anything before
  ///   // runApp needs the binding to exist first.
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   final SharedPreferences prefs = await SharedPreferences.getInstance();
  ///
  ///   HintRegistry.instance.storage = CallbackTourStorage(
  ///     isCompleted: (String key) async =>
  ///         prefs.getBool('hint_kit.$key') ?? false,
  ///     setCompleted: (String key, bool seen) async => seen
  ///         ? prefs.setBool('hint_kit.$key', true)
  ///         : prefs.remove('hint_kit.$key'),
  ///     // Both or neither: this pair is what `start(resume: true)` reads.
  ///     lastIndex: (String tour) async => prefs.getInt('hint_kit.$tour.step'),
  ///     saveIndex: (String tour, int? index) async => index == null
  ///         ? prefs.remove('hint_kit.$tour.step')
  ///         : prefs.setInt('hint_kit.$tour.step', index),
  ///   );
  ///
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Tours are remembered separately, in the [TourStorage] a [TourController]
  /// or [TourScope] was given. Handing both the same instance is the usual
  /// answer — hint_kit says so in debug when only one of the two is set. Keys
  /// then share one space: a hint's key is whatever string it was given and a
  /// tour's is its name, so keep the two distinct.
  TourStorage get storage => _storage;

  set storage(TourStorage value) {
    _storage = value;
    _storageWasSet = true;
  }

  TourStorage _storage = InMemoryTourStorage();

  /// Whether [storage] was assigned, as opposed to left at its default.
  ///
  /// The difference is the whole basis of the debug wiring check: an explicit
  /// [InMemoryTourStorage] is a decision, the default one is an oversight
  /// waiting to happen.
  bool _storageWasSet = false;

  /// Whether any [TourController] was handed a storage of its own.
  bool _explicitTourStorage = false;

  /// Whether the wiring check has already had its say.
  bool _warnedAboutWiring = false;

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

// -----------------------------------------------------------------------------
// The two-places check
// -----------------------------------------------------------------------------
//
// hint_kit remembers two different things in two different places: showOnce
// keys in HintRegistry.storage, and finished tours in the TourStorage a
// TourController holds. Setting one and leaving the other at its in-memory
// default is the easiest mistake to make with this package, and it fails
// silently - half the app forgets on every launch and nothing says why.
//
// These are debug-only and package-internal: the barrel exports HintRegistry
// alone, so none of them reach a caller.

/// Records that a [TourController] was handed a storage of its own.
void debugNoteExplicitTourStorage() {
  assert(() {
    HintRegistry.instance._explicitTourStorage = true;
    return true;
  }());
}

/// Puts the wiring flags back to a fresh process's state, for tests.
void debugResetStorageWiring() {
  assert(() {
    HintRegistry.instance
      .._storageWasSet = false
      .._explicitTourStorage = false
      .._warnedAboutWiring = false;
    return true;
  }());
}

/// Checks the wiring as a tour starts.
///
/// [tourUsesDefaultStorage] is whether the tour about to run is on the
/// package's own in-memory storage rather than one its author chose.
void debugCheckTourStorageWiring({required bool tourUsesDefaultStorage}) {
  assert(() {
    if (tourUsesDefaultStorage && HintRegistry.instance._storageWasSet) {
      _warnAboutWiring(
        'HintRegistry.instance.storage is set, but this tour is using the '
        'default in-memory storage, so finished tours are forgotten on the '
        'next launch while Hint.showOnce keys are kept.\n'
        'Give the tour the same storage:\n'
        '  TourScope(storage: myStorage, ...)\n'
        '  TourController(storage: myStorage)',
      );
    }
    return true;
  }());
}

/// Checks the wiring when a `Hint.showOnce` key is consulted.
void debugCheckShowOnceStorageWiring() {
  assert(() {
    final HintRegistry registry = HintRegistry.instance;
    if (!registry._storageWasSet && registry._explicitTourStorage) {
      _warnAboutWiring(
        'A TourController was given persistent storage, but '
        'HintRegistry.instance.storage is still the default in-memory one, so '
        'Hint.showOnce keys are forgotten on the next launch while finished '
        'tours are kept.\n'
        'Set it once at startup, to the same storage:\n'
        '  HintRegistry.instance.storage = myStorage;',
      );
    }
    return true;
  }());
}

/// Says [message] once per process, and never again.
void _warnAboutWiring(String message) {
  final HintRegistry registry = HintRegistry.instance;
  if (registry._warnedAboutWiring) {
    return;
  }
  registry._warnedAboutWiring = true;
  debugPrint(
    'hint_kit: persistence is set in one of its two places, not both.\n'
    '$message\n'
    'Pass an InMemoryTourStorage() explicitly for the half you want to '
    'forget. This message is debug-only and is said once.',
  );
}
