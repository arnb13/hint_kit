/// @docImport '../tooltip/hint.dart';
/// @docImport '../tooltip/hint_registry.dart';
/// @docImport '../tour/tour_controller.dart';
/// @docImport '../widgets/beacon.dart';
library;

import 'package:flutter/foundation.dart';

import 'hint_trigger.dart';
import 'tour_end_reason.dart';

/// What happened to one hint.
///
/// Handed to [HintObserver.didShowHint] and [HintObserver.didDismissHint].
@immutable
class HintEvent {
  /// Creates a hint event.
  const HintEvent({this.id, this.label, this.trigger, this.showOnce});

  /// The hint's [Hint.analyticsId], when it has one.
  ///
  /// The only field meant as a stable key. Text changes when a copywriter
  /// touches it; an id does not.
  final String? id;

  /// The hint's text: its semantics label, message or title, whichever it has.
  ///
  /// Null for a rich bubble that carries neither and was given no
  /// `semanticsLabel`.
  final String? label;

  /// What opened the hint, when it was opened by a trigger.
  ///
  /// Null when the hint was opened from code through a `HintController`, and
  /// for a hint opened by a tour.
  final HintTrigger? trigger;

  /// The [Hint.showOnce] key, when the hint has one.
  final String? showOnce;

  @override
  String toString() => 'HintEvent(id: $id, label: $label, trigger: $trigger)';
}

/// Watches every hint and tour in the app.
///
/// Register one on the [HintRegistry] — which is process-global, so an
/// observer sees hints on every route and inside every overlay:
///
/// ```dart
/// class HintAnalytics extends HintObserver {
///   @override
///   void didShowHint(HintEvent event) =>
///       analytics.log('hint_shown', <String, Object?>{'id': event.id});
///
///   @override
///   void didEndTour(String tour, TourEndReason reason) =>
///       analytics.log('tour_${reason.name}', <String, Object?>{'tour': tour});
/// }
///
/// void main() {
///   HintRegistry.instance.addObserver(HintAnalytics());
///   runApp(const MyApp());
/// }
/// ```
///
/// Every method has an empty default body, so an observer overrides only what
/// it cares about. Extend it rather than implementing it, for the same reason:
/// methods added in a later version will not break your class.
///
/// Callbacks run synchronously, inside the show or hide that caused them. Do
/// not build widgets or call `setState` from one — queue the work.
abstract class HintObserver {
  /// Allows subclasses to be const.
  const HintObserver();

  /// A hint bubble opened.
  ///
  /// Fires for every [Hint] and [Beacon], however it was opened — trigger,
  /// controller or `onAppear` — but not for tour steps, which report through
  /// [didChangeTourStep].
  void didShowHint(HintEvent event) {}

  /// A hint bubble closed.
  ///
  /// Fires once per show, including when the hint was closed by something
  /// else taking the floor or by its own auto-hide timer.
  void didDismissHint(HintEvent event) {}

  /// A tour started, before its first step is shown.
  ///
  /// Not called for a `start()` that did nothing because the tour was already
  /// completed.
  void didStartTour(String tour) {}

  /// A tour moved to [index], including to its first step.
  void didChangeTourStep(String tour, int index) {}

  /// A tour ended, for [reason].
  void didEndTour(String tour, TourEndReason reason) {}
}
