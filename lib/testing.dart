/// Helpers for testing code that uses hint_kit.
///
/// Import it from your tests only:
///
/// ```dart
/// import 'package:hint_kit/testing.dart';
///
/// setUp(resetHintKit);
/// ```
///
/// It deliberately does not depend on `flutter_test`: everything here is plain
/// Dart and Flutter, so it adds nothing to your app's dependency graph and can
/// be used from an integration test, a golden harness or a driver script
/// equally well. Finding a bubble needs no helper — `find.text('…')` already
/// works, because the bubble is ordinary widgets in the overlay.
///
/// @docImport 'hint_kit.dart';
library;

import 'src/core/hint_observer.dart';
import 'src/core/tour_end_reason.dart';
import 'src/tooltip/hint_registry.dart';
import 'src/tour/tour_storage.dart';

export 'src/core/hint_observer.dart' show HintEvent, HintObserver;
export 'src/tour/tour_storage.dart' show TourStorage;

/// Puts the package's process-global state back to how it starts.
///
/// [HintRegistry] outlives any widget tree — that is the point of it, since
/// the overlay it arbitrates is not scoped to a subtree — so without this a
/// test inherits the previous test's open hint, `showOnce` keys and observers.
/// Symptoms are a hint that mysteriously refuses to appear, or an observer
/// that counts events from two tests at once.
///
/// Call it in `setUp`:
///
/// ```dart
/// setUp(resetHintKit);
/// ```
///
/// It closes whatever hint holds the floor, drops every registered observer,
/// and replaces [HintRegistry.storage] with a fresh [InMemoryTourStorage].
void resetHintKit() {
  HintRegistry.instance
    ..closeAll()
    ..removeAllObservers()
    ..storage = InMemoryTourStorage();
  // Last: assigning storage above counts as setting it, and a fresh process
  // has not. Otherwise every test that runs a tour would be told off for
  // wiring persistence in one place only.
  debugResetStorageWiring();
}

/// A [TourStorage] with the state a test wants to arrange up front.
///
/// Saves you writing the same five-line fake in every suite:
///
/// ```dart
/// final storage = FakeTourStorage(completed: <String>{'onboarding'});
/// // ... the tour does not start, because it is already done.
///
/// final resumable = FakeTourStorage(indices: <String, int>{'onboarding': 2});
/// await controller.start('onboarding', resume: true);
/// expect(controller.index, 2);
/// ```
///
/// Every call is recorded in [calls], in order, so a test can assert *that*
/// storage was consulted rather than only what it answered.
class FakeTourStorage implements TourStorage {
  /// Creates a storage pre-loaded with [completed] tours and [indices].
  FakeTourStorage({
    Set<String>? completed,
    Map<String, int>? indices,
  })  : completed = <String>{...?completed},
        indices = <String, int>{...?indices};

  /// The tours currently recorded as finished.
  final Set<String> completed;

  /// The saved step index per tour, for `start(resume: true)`.
  final Map<String, int> indices;

  /// Every call made to this storage, as `'method:argument'` strings.
  final List<String> calls = <String>[];

  @override
  Future<bool> isCompleted(String tour) async {
    calls.add('isCompleted:$tour');
    return completed.contains(tour);
  }

  @override
  Future<void> markCompleted(String tour) async {
    calls.add('markCompleted:$tour');
    completed.add(tour);
  }

  @override
  Future<void> reset(String tour) async {
    calls.add('reset:$tour');
    completed.remove(tour);
    indices.remove(tour);
  }

  @override
  Future<int?> lastIndex(String tour) async {
    calls.add('lastIndex:$tour');
    return indices[tour];
  }

  @override
  Future<void> saveIndex(String tour, int? index) async {
    calls.add('saveIndex:$tour:$index');
    if (index == null) {
      indices.remove(tour);
    } else {
      indices[tour] = index;
    }
  }

  @override
  String toString() => 'FakeTourStorage(completed: $completed)';
}

/// A [HintObserver] that records what it hears.
///
/// Register it with `HintRegistry.instance.addObserver(...)` — and remember
/// [resetHintKit], or it will still be listening in the next test:
///
/// ```dart
/// final recorder = RecordingHintObserver();
/// HintRegistry.instance.addObserver(recorder);
/// // ...
/// expect(recorder.events, <String>['show:save-tip', 'dismiss:save-tip']);
/// ```
class RecordingHintObserver extends HintObserver {
  /// Creates an empty recorder.
  RecordingHintObserver();

  /// Everything heard so far, in order, as short `'kind:subject'` strings.
  ///
  /// A hint is identified by its `analyticsId` when it has one and by its text
  /// otherwise — the same fallback [HintEvent] itself uses.
  final List<String> events = <String>[];

  /// The full events for hints that were shown, when the strings are not
  /// enough.
  final List<HintEvent> shown = <HintEvent>[];

  /// The full events for hints that were dismissed.
  final List<HintEvent> dismissed = <HintEvent>[];

  String _name(HintEvent event) => event.id ?? event.label ?? '?';

  @override
  void didShowHint(HintEvent event) {
    events.add('show:${_name(event)}');
    shown.add(event);
  }

  @override
  void didDismissHint(HintEvent event) {
    events.add('dismiss:${_name(event)}');
    dismissed.add(event);
  }

  @override
  void didStartTour(String tour) => events.add('tour-start:$tour');

  @override
  void didChangeTourStep(String tour, int index) =>
      events.add('tour-step:$tour:$index');

  @override
  void didEndTour(String tour, TourEndReason reason) =>
      events.add('tour-end:$tour:${reason.name}');

  /// Forgets everything recorded so far.
  void clear() {
    events.clear();
    shown.clear();
    dismissed.clear();
  }

  @override
  String toString() => 'RecordingHintObserver($events)';
}
