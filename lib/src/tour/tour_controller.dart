/// @docImport 'package:flutter/widgets.dart';
/// @docImport 'hint_target.dart';
/// @docImport 'tour_scope.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tour_storage.dart';

/// Why a tour ended.
enum TourEndReason {
  /// The user reached the last step and confirmed it.
  finished,

  /// The user dismissed the tour early.
  skipped,

  /// The tour was stopped in code, or its scope was disposed.
  cancelled,
}

/// Signature for [TourController.onStepChanged].
typedef TourStepCallback = void Function(String tour, int index);

/// Signature for [TourController.onEnd].
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
/// final TourController tour = TourController();
///
/// TourScope(
///   controller: tour,
///   storage: myStorage,
///   child: const MyApp(),
/// );
///
/// // Anywhere below the scope:
/// Tour.of(context).start('onboarding');
/// ```
class TourController extends ChangeNotifier {
  /// Creates a tour controller.
  ///
  /// [storage] defaults to an [InMemoryTourStorage], which forgets everything
  /// when the process ends. Pass your own to make "seen it already" stick.
  TourController({TourStorage? storage, this.onStepChanged, this.onEnd})
      : storage = storage ?? InMemoryTourStorage();

  /// Where completed tours are recorded.
  final TourStorage storage;

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
  /// Awaiting the returned future is optional; the tour is visible as soon as
  /// storage answers.
  Future<void> start(String tour, {bool force = false}) async {
    assert(tour.isNotEmpty, 'A tour needs a name.');
    if (_activeTour == tour) {
      return;
    }
    if (!force && await storage.isCompleted(tour)) {
      return;
    }
    _activeTour = tour;
    _index = 0;
    _length = _stepCountFor?.call(tour) ?? 0;
    notifyListeners();
    onStepChanged?.call(tour, 0);
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
    onStepChanged?.call(tour, _index);
  }

  /// Moves back one step. A no-op on the first step.
  void previous() {
    final String? tour = _activeTour;
    if (tour == null || isFirst) {
      return;
    }
    _index--;
    notifyListeners();
    onStepChanged?.call(tour, _index);
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
    }
    notifyListeners();
    onEnd?.call(tour, reason);
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
    onStepChanged?.call(tour, _index);
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
