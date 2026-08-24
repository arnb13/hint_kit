/// @docImport '../tour/tour_controller.dart';
library;

/// Why a tour ended.
///
/// Lives here rather than beside [TourController] so that the observer
/// interface — which is in the hint layer, below the tour — can name it
/// without the two layers importing each other.
///
/// {@category Tours}
enum TourEndReason {
  /// The user reached the last step and confirmed it.
  finished,

  /// The user dismissed the tour early.
  skipped,

  /// The tour was stopped in code, or its scope was disposed.
  cancelled,
}
