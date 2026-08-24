/// @docImport 'package:flutter/widgets.dart';
/// @docImport 'hint_target.dart';
/// @docImport 'tour_scope.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/tour_end_reason.dart';
import '../tooltip/hint_registry.dart';
import 'tour_storage.dart';

/// Signature for [TourController.onStepChanged].
///
/// {@category Tours}
typedef TourStepCallback = void Function(String tour, int index);

/// Signature for [TourController.onEnd].
///
/// {@category Tours}
typedef TourEndCallback = void Function(String tour, TourEndReason reason);

/// Runs a guided tour: which tour is active, which step it is on, and how it
/// ends.
///
/// The controller holds no widgets and no [BuildContext]. It knows a step
/// *count*, supplied by the [TourScope] the targets register with, which is
/// what lets a tour span several routes: a step whose target is not mounted
/// yet simply has nothing to point at until it registers.
///
/// ```dart
/// final TourController tour = TourController(storage: myStorage);
///
/// TourScope(
///   controller: tour,
///   child: const MyApp(),
/// );
///
/// // Anywhere below the scope:
/// Tour.of(context).start('onboarding');
/// ```
///
/// {@category Tours}
class TourController extends ChangeNotifier {
  /// Creates a tour controller.
  ///
  /// [storage] defaults to an [InMemoryTourStorage], which forgets everything
  /// when the process ends. Pass your own to make "seen it already" stick —
  /// and remember that `Hint.showOnce` is remembered separately, in
  /// [HintRegistry.storage]. Passing the same instance to both is the usual
  /// answer; hint_kit says so in debug when only one of the two is set.
  TourController({TourStorage? storage, this.onStepChanged, this.onEnd})
      : _storage = storage {
    if (storage != null) {
      debugNoteExplicitTourStorage();
    }
  }

  /// The storage passed to the constructor, or null when it defaulted.
  ///
  /// Kept apart from [storage] so the debug wiring check can tell "the caller
  /// chose in-memory" from "the caller chose nothing".
  final TourStorage? _storage;

  /// Used only when no storage was supplied. Created once, not per read, or
  /// every lookup would consult an empty store.
  late final TourStorage _ownStorage = InMemoryTourStorage();

  /// Where completed tours are recorded.
  TourStorage get storage => _storage ?? _ownStorage;

  /// Whether this controller is running on the default in-memory storage.
  bool get _storageDefaulted => _storage == null;

  /// Called whenever the active step changes, including the first one.
  final TourStepCallback? onStepChanged;

  /// Called once when a tour ends, with the reason.
  final TourEndCallback? onEnd;

  String? _activeTour;
  int _index = 0;
  int _length = 0;

  /// notifyListeners is protected; this lets the package-internal helpers at
  /// the bottom of this file reach it.
  void _notify() => notifyListeners();

  /// The running tour's name, or null when no tour is running.
  String? get activeTour => _activeTour;

  /// Whether a tour is running.
  bool get isRunning => _activeTour != null;

  /// The zero-based index of the current step.
  int get index => _index;

  /// How many steps the active tour has.
  ///
  /// This is the number of [HintTarget]s registered for the tour *and*
  /// whichever unmounted orders the scope has been told about, so a tour that
  /// spans routes reports its true length from the start.
  int get length => _length;

  /// The human-facing step number, one-based. `0` when nothing is running.
  int get step => _activeTour == null ? 0 : _index + 1;

  /// Whether the current step is the last one.
  bool get isLast => _length == 0 || _index >= _length - 1;

  /// Whether the current step is the first one.
  bool get isFirst => _index <= 0;

  /// Starts [tour] at its first step.
  ///
  /// Does nothing when [TourStorage.isCompleted] reports the tour is done,
  /// unless [force] is set — which is what a "replay the tour" button wants.
  /// Also does nothing when the same tour is already running.
  ///
  /// With [resume], the tour picks up at the step it had reached when it was
  /// last interrupted, instead of at the beginning:
  ///
  /// ```dart
  /// // On launch: continue an onboarding the user walked away from.
  /// tour.start('onboarding', resume: true);
  /// ```
  ///
  /// The position is recorded on every step change and cleared when the tour
  /// finishes or is skipped, so only an *interrupted* tour resumes — a closed
  /// app, a killed process, a [cancel]. It needs a [TourStorage] that
  /// implements [TourStorage.lastIndex] and [TourStorage.saveIndex];
  /// [InMemoryTourStorage] does, for this session, and the default
  /// implementations of both do nothing, so a storage written before this
  /// existed simply never resumes.
  ///
  /// Awaiting the returned future is optional; the tour is visible as soon as
  /// storage answers.
  Future<void> start(
    String tour, {
    bool force = false,
    bool resume = false,
  }) async {
    assert(tour.isNotEmpty, 'A tour needs a name.');
    debugCheckTourStorageWiring(tourUsesDefaultStorage: _storageDefaulted);
    if (_activeTour == tour) {
      return;
    }
    if (!force && await storage.isCompleted(tour)) {
      return;
    }
    final int start = resume ? await _resumeIndex(tour) : 0;
    _activeTour = tour;
    _index = start;
    _length = _stepCountFor?.call(tour) ?? 0;
    notifyListeners();
    HintRegistry.instance.notifyTourStarted(tour);
    _stepChanged(tour);
  }

  /// Where a resumed [tour] should pick up.
  ///
  /// Clamped against the *known* length only: a tour whose later targets have
  /// not registered yet legitimately reports a length of zero, and clamping to
  /// that would silently restart it from the beginning — the exact bug resuming
  /// exists to avoid.
  Future<int?> _savedIndex(String tour) => storage.lastIndex(tour);

  Future<int> _resumeIndex(String tour) async {
    final int? saved = await _savedIndex(tour);
    if (saved == null || saved <= 0) {
      return 0;
    }
    final int length = _stepCountFor?.call(tour) ?? 0;
    return length > 0 && saved >= length ? length - 1 : saved;
  }

  /// Whether [tour] has a recorded position to resume from.
  ///
  /// Use it to decide between "Start the tour" and "Continue where you left
  /// off" without starting anything:
  ///
  /// ```dart
  /// final bool canResume = await tour.hasProgress('onboarding');
  /// ```
  ///
  /// Always false for a storage that does not record positions, which is the
  /// default.
  Future<bool> hasProgress(String tour) async {
    final int? saved = await _savedIndex(tour);
    return saved != null && saved > 0;
  }

  /// Moves to the next step, or finishes the tour when on the last one.
  void next() {
    final String? tour = _activeTour;
    if (tour == null) {
      return;
    }
    if (isLast) {
      finish();
      return;
    }
    _index++;
    notifyListeners();
    _stepChanged(tour);
  }

  /// Moves back one step. A no-op on the first step.
  void previous() {
    final String? tour = _activeTour;
    if (tour == null || isFirst) {
      return;
    }
    _index--;
    notifyListeners();
    _stepChanged(tour);
  }

  /// Ends the tour early and records it as completed.
  ///
  /// Skipping marks the tour done on purpose: a user who dismissed the
  /// onboarding does not want to meet it again tomorrow. Use
  /// [TourStorage.reset] to offer it again.
  void skip() => _end(TourEndReason.skipped);

  /// Ends the tour normally and records it as completed.
  void finish() => _end(TourEndReason.finished);

  /// Ends the tour without recording it, so it runs again next time.
  void cancel() => _end(TourEndReason.cancelled, markCompleted: false);

  void _end(TourEndReason reason, {bool markCompleted = true}) {
    final String? tour = _activeTour;
    if (tour == null) {
      return;
    }
    _activeTour = null;
    _index = 0;
    _length = 0;
    if (markCompleted) {
      // Fire and forget: the UI must not wait on storage to close a tour.
      unawaited(storage.markCompleted(tour));
      // A tour that ran to its end — or was skipped — has no position worth
      // resuming; leaving one would drop a replay into the middle.
      unawaited(storage.saveIndex(tour, null));
    }
    notifyListeners();
    onEnd?.call(tour, reason);
    HintRegistry.instance.notifyTourEnded(tour, reason);
  }

  /// Announces the current step to the callback and to every observer, and
  /// records the position so the tour can be resumed.
  ///
  /// One place, so an app-wide observer, a per-controller callback and the
  /// saved position can never disagree about which step is showing.
  void _stepChanged(String tour) {
    onStepChanged?.call(tour, _index);
    HintRegistry.instance.notifyTourStep(tour, _index);
    // Fire and forget: a tour must not wait on storage to advance.
    unawaited(storage.saveIndex(tour, _index));
  }

  /// Jumps straight to [index] of the running tour.
  ///
  /// Out-of-range values are clamped rather than throwing, because step counts
  /// change as targets on other routes register and deregister.
  void goTo(int index) {
    final String? tour = _activeTour;
    if (tour == null || _length == 0) {
      return;
    }
    final int clamped = index.clamp(0, _length - 1);
    if (clamped == _index) {
      return;
    }
    _index = clamped;
    notifyListeners();
    _stepChanged(tour);
  }

  /// Set by the [TourScope] so the controller can ask how many steps a tour
  /// has without holding a reference to any widget.
  int Function(String tour)? _stepCountFor;

  @override
  String toString() =>
      'TourController(tour: $_activeTour, step: $step of $_length)';
}

// -----------------------------------------------------------------------------
// Package-internal plumbing; not exported from the barrel.
// -----------------------------------------------------------------------------

/// Lets the scope tell the controller how to count a tour's steps.
void bindTourStepCounter(
  TourController controller,
  int Function(String tour)? counter,
) {
  controller._stepCountFor = counter;
}

/// Updates the running tour's step count as targets register or deregister.
///
/// Keeps [TourController.index] inside the new range, and ends a tour whose
/// last target has gone away.
void updateTourLength(TourController controller, int length) {
  if (controller._activeTour == null || controller._length == length) {
    return;
  }
  controller._length = length;
  if (length == 0) {
    return;
  }
  if (controller._index > length - 1) {
    controller._index = length - 1;
  }
  controller._notify();
}
