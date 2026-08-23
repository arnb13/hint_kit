/// @docImport 'tour_controller.dart';
library;

/// Remembers which tours a user has already seen.
///
/// The package has zero runtime dependencies, so it ships an interface and an
/// in-memory implementation rather than picking a persistence library for you.
/// Wire it to whatever the app already uses — `shared_preferences`, Hive,
/// SQLite, a server flag:
///
/// ```dart
/// class PrefsTourStorage implements TourStorage {
///   PrefsTourStorage(this.prefs);
///   final SharedPreferences prefs;
///
///   @override
///   Future<bool> isCompleted(String tour) async =>
///       prefs.getBool('tour.$tour') ?? false;
///
///   @override
///   Future<void> markCompleted(String tour) async =>
///       prefs.setBool('tour.$tour', true);
///
///   @override
///   Future<void> reset(String tour) async => prefs.remove('tour.$tour');
/// }
/// ```
///
/// Implementations must tolerate being called concurrently and must not throw
/// for an unknown tour name.
abstract class TourStorage {
  /// Creates a storage. Const so implementations can be too.
  const TourStorage();

  /// Whether [tour] has been finished before.
  ///
  /// [TourController.start] consults this and does nothing when it returns
  /// true, unless it was called with `force: true`.
  Future<bool> isCompleted(String tour);

  /// Records [tour] as finished.
  ///
  /// Called when a tour runs to its end *and* when it is skipped: a user who
  /// dismissed the onboarding does not want it again tomorrow.
  Future<void> markCompleted(String tour);

  /// Forgets that [tour] was finished, so it can run again.
  ///
  /// Useful for a "replay the tour" button and for tests.
  Future<void> reset(String tour);

  /// The step [tour] had reached when the app last stopped, if it was recorded.
  ///
  /// Read by `TourController.start` when it is called with `resume: true`.
  /// Returning `null` — the default — means "start at the beginning", so a
  /// storage written before this existed keeps working and simply never
  /// resumes.
  Future<int?> lastIndex(String tour) async => null;

  /// Records that [tour] is on step [index], or forgets the position when
  /// [index] is null.
  ///
  /// Called on every step change and once more when the tour ends, so a
  /// finished tour does not resume in the middle next time. The default does
  /// nothing, which is what makes resuming opt-in per storage.
  Future<void> saveIndex(String tour, int? index) async {}
}

/// A [TourStorage] made of two closures, for when writing a class is more
/// ceremony than the job deserves.
///
/// This is the shortest path from the in-memory default to real persistence:
/// no subclass, no dependency, and it works with any key-value store the app
/// already has.
///
/// ```dart
/// TourScope(
///   storage: CallbackTourStorage(
///     isCompleted: (String tour) async => prefs.getBool('tour.$tour') ?? false,
///     setCompleted: (String tour, bool done) async =>
///         done ? prefs.setBool('tour.$tour', true) : prefs.remove('tour.$tour'),
///   ),
///   child: const MyApp(),
/// )
/// ```
///
/// One setter covers both writes: [markCompleted] calls it with `true` and
/// [reset] with `false`, so the two can never disagree about where the flag
/// lives.
class CallbackTourStorage implements TourStorage {
  /// Creates a storage backed by [isCompleted] and [setCompleted].
  ///
  /// [lastIndex] and [saveIndex] are optional: supply both to support
  /// [TourController.start] with `resume: true`, or neither to keep tours
  /// starting from the beginning.
  const CallbackTourStorage({
    required Future<bool> Function(String tour) isCompleted,
    required Future<void> Function(String tour, bool completed) setCompleted,
    Future<int?> Function(String tour)? lastIndex,
    Future<void> Function(String tour, int? index)? saveIndex,
  })  : _isCompleted = isCompleted,
        _setCompleted = setCompleted,
        _lastIndex = lastIndex,
        _saveIndex = saveIndex;

  final Future<bool> Function(String tour) _isCompleted;
  final Future<void> Function(String tour, bool completed) _setCompleted;
  final Future<int?> Function(String tour)? _lastIndex;
  final Future<void> Function(String tour, int? index)? _saveIndex;

  @override
  Future<bool> isCompleted(String tour) => _isCompleted(tour);

  @override
  Future<void> markCompleted(String tour) => _setCompleted(tour, true);

  @override
  Future<void> reset(String tour) async {
    await _setCompleted(tour, false);
    await _saveIndex?.call(tour, null);
  }

  @override
  Future<int?> lastIndex(String tour) async => _lastIndex?.call(tour);

  @override
  Future<void> saveIndex(String tour, int? index) async =>
      _saveIndex?.call(tour, index);

  @override
  String toString() => 'CallbackTourStorage(resumable: ${_lastIndex != null})';
}

/// The default [TourStorage]: remembers completions for this session only.
///
/// Every tour therefore runs again on the next launch. That is the right
/// default for a package with no dependencies — it is obvious, it never
/// silently loses data, and it makes the "wire up your own persistence" step
/// impossible to forget by accident.
class InMemoryTourStorage implements TourStorage {
  /// Creates an empty in-memory storage.
  InMemoryTourStorage();

  final Set<String> _completed = <String>{};
  final Map<String, int> _indices = <String, int>{};

  /// The tours recorded as completed so far.
  ///
  /// Exposed so a host app can persist the whole set in one go if it prefers
  /// that to implementing [TourStorage].
  Set<String> get completed => Set<String>.unmodifiable(_completed);

  @override
  Future<bool> isCompleted(String tour) async => _completed.contains(tour);

  @override
  Future<void> markCompleted(String tour) async => _completed.add(tour);

  @override
  Future<void> reset(String tour) async {
    _completed.remove(tour);
    _indices.remove(tour);
  }

  @override
  Future<int?> lastIndex(String tour) async => _indices[tour];

  @override
  Future<void> saveIndex(String tour, int? index) async {
    if (index == null) {
      _indices.remove(tour);
    } else {
      _indices[tour] = index;
    }
  }

  @override
  String toString() => 'InMemoryTourStorage($_completed)';
}
