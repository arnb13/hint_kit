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
  Future<void> reset(String tour) async => _completed.remove(tour);

  @override
  String toString() => 'InMemoryTourStorage($_completed)';
}
