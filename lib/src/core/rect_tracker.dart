import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How often a [HintRectTracker] re-measures its target.
enum RectTrackingMode {
  /// Measure on show, on scroll, on window metric changes and on an explicit
  /// `refresh()`.
  ///
  /// This is the tooltip default. The bubble is anchored with a [LayerLink],
  /// so the compositor already follows the target every frame for free; the
  /// measured rect only has to be fresh enough to decide *which side* the
  /// bubble goes on and whether it needs to shift away from a screen edge.
  onDemand,

  /// Re-measure at the end of every frame the app renders anyway.
  ///
  /// This is the tour default: a step is modal and short-lived, so the cost is
  /// irrelevant, and it keeps the spotlight glued to the target through a
  /// scroll-to-target animation.
  ///
  /// This never *schedules* frames of its own, so it does not prevent a test
  /// from settling or an idle app from staying idle.
  perFrame,
}

/// Measures a target widget's rect in overlay coordinates and notifies when it
/// changes.
///
/// The tracker is deliberately conservative: it only notifies when the rect
/// actually changed, because a tracker that notifies every frame rebuilds the
/// bubble every frame.
///
/// Typical use from a [State]:
///
/// ```dart
/// final HintRectTracker _tracker = HintRectTracker();
///
/// void _show() {
///   _tracker.start(
///     targetContext: context,
///     overlayContext: Overlay.of(context).context,
///   );
/// }
///
/// @override
/// void dispose() {
///   _tracker.dispose();
///   super.dispose();
/// }
/// ```
class HintRectTracker extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<Rect?> {
  /// Creates a tracker that measures in [mode].
  HintRectTracker({this.mode = RectTrackingMode.onDemand});

  /// How often the target is re-measured. See [RectTrackingMode].
  final RectTrackingMode mode;

  /// Trackers currently in [RectTrackingMode.perFrame], ticked by a single
  /// shared persistent frame callback.
  ///
  /// One callback for the whole app beats one per tracker: persistent frame
  /// callbacks cannot be unregistered, so registering per instance would leak.
  static final Set<HintRectTracker> _perFrameTrackers = <HintRectTracker>{};
  static bool _tickerInstalled = false;

  BuildContext? _targetContext;
  BuildContext? _overlayContext;
  ScrollPosition? _scrollPosition;
  Rect? _value;
  bool _running = false;

  /// The last measured target rect, in overlay coordinates.
  ///
  /// `null` before the first measurement, and after the target stops being
  /// measurable — it was scrolled out of a lazy list, or its route was popped.
  @override
  Rect? get value => _value;

  /// Whether the tracker is currently measuring.
  bool get isRunning => _running;

  /// Begins tracking [targetContext] relative to [overlayContext].
  ///
  /// Safe to call again to re-target; the previous subscriptions are dropped.
  /// The first measurement happens after the current frame, since the target
  /// may not have been laid out yet on the frame that triggered the show.
  void start({
    required BuildContext targetContext,
    required BuildContext overlayContext,
  }) {
    _detachScroll();
    _targetContext = targetContext;
    _overlayContext = overlayContext;
    if (!_running) {
      _running = true;
      WidgetsBinding.instance.addObserver(this);
      if (mode == RectTrackingMode.perFrame) {
        _perFrameTrackers.add(this);
        _installTicker();
      }
    }
    _attachScroll();
    // Measure now in case layout is already complete (a controller-driven show
    // from a button tap), and again after the frame for the case where it is
    // not (a show from initState).
    measure();
    _measureAfterFrame();
  }

  /// Stops tracking and clears [value].
  ///
  /// The tracker can be restarted with [start]; [dispose] is only needed when
  /// the owner itself is going away.
  void stop() {
    if (!_running) {
      return;
    }
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _perFrameTrackers.remove(this);
    _detachScroll();
    _targetContext = null;
    _overlayContext = null;
    if (_value != null) {
      _value = null;
      notifyListeners();
    }
  }

  /// Forces a re-measure on the next frame as well as right now.
  ///
  /// Use after changing the target's size or position in a way the tracker
  /// cannot observe, such as an external layout animation.
  void refresh() {
    if (!_running) {
      return;
    }
    // Scroll ancestry can change without the tracker restarting, e.g. when the
    // target moves into a different list.
    _detachScroll();
    _attachScroll();
    measure();
    _measureAfterFrame();
  }

  /// Measures the target now and notifies listeners if the rect changed.
  ///
  /// Returns the new value. Called automatically; exposed because a caller
  /// that already knows layout is settled can avoid waiting a frame.
  Rect? measure() {
    final Rect? next = _computeRect();
    if (next == _value) {
      return _value;
    }
    _value = next;
    notifyListeners();
    return next;
  }

  /// Reads the target's rect in overlay coordinates, or `null` when it cannot
  /// currently be measured.
  Rect? _computeRect() {
    final BuildContext? target = _targetContext;
    final BuildContext? overlay = _overlayContext;
    if (target == null || overlay == null) {
      return null;
    }
    // A target scrolled out of a lazy list is legitimately gone; that is not
    // an error, it just means there is nothing to point at right now.
    if (!target.mounted || !overlay.mounted) {
      return null;
    }
    final RenderObject? targetObject = target.findRenderObject();
    final RenderObject? overlayObject = overlay.findRenderObject();
    if (targetObject == null || overlayObject == null) {
      return null;
    }
    assert(
      targetObject is RenderBox,
      'HintRectTracker: the target must be a box, but its render object is '
      '${targetObject.runtimeType}. Hints cannot anchor to slivers directly; '
      'wrap the target in a box widget inside the sliver.',
    );
    assert(
      overlayObject is RenderBox,
      'HintRectTracker: the overlay render object must be a box, got '
      '${overlayObject.runtimeType}.',
    );
    if (targetObject is! RenderBox || overlayObject is! RenderBox) {
      return null;
    }
    if (!targetObject.attached || !overlayObject.attached) {
      return null;
    }
    assert(
      targetObject.hasSize,
      'HintRectTracker: the target render object is attached but has not been '
      'laid out. This usually means the rect was read during build; measure '
      'from a post-frame callback instead.',
    );
    if (!targetObject.hasSize || !overlayObject.hasSize) {
      return null;
    }
    final Offset origin = targetObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    if (!origin.isFinite) {
      // A degenerate transform (a zero-scale animation, for instance) is not
      // an error, but it is not measurable either.
      return null;
    }
    return origin & targetObject.size;
  }

  /// Schedules a measurement for the end of the current frame.
  void _measureAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_running) {
        measure();
      }
    });
    // The show may have been triggered outside a frame (a timer, a callback
    // from platform code), in which case no frame is pending.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _attachScroll() {
    final BuildContext? target = _targetContext;
    if (target == null || !target.mounted) {
      return;
    }
    final ScrollableState? scrollable = Scrollable.maybeOf(target);
    final ScrollPosition? position = scrollable?.position;
    if (position == null) {
      return;
    }
    _scrollPosition = position..addListener(_onScroll);
  }

  void _detachScroll() {
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = null;
  }

  void _onScroll() {
    if (_running && mode == RectTrackingMode.onDemand) {
      measure();
    }
  }

  @override
  void didChangeMetrics() {
    // Window resize, keyboard show/hide, rotation. Layout has not run yet, so
    // measuring now would read the old rect.
    if (_running) {
      _measureAfterFrame();
    }
  }

  @override
  void dispose() {
    // Not `stop()`: notifying listeners from dispose is a use-after-free
    // waiting to happen.
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _perFrameTrackers.remove(this);
    _detachScroll();
    _targetContext = null;
    _overlayContext = null;
    super.dispose();
  }

  /// Installs the one shared per-frame tick, at most once per isolate.
  static void _installTicker() {
    if (_tickerInstalled) {
      return;
    }
    _tickerInstalled = true;
    // Persistent callbacks run after `drawFrame`, so layout for this frame is
    // already complete and the measurement is current rather than one frame
    // stale. It never asks for a frame of its own.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_perFrameTrackers.isEmpty) {
        return;
      }
      for (final HintRectTracker tracker
          in List<HintRectTracker>.of(_perFrameTrackers)) {
        if (tracker._running) {
          tracker.measure();
        }
      }
    });
  }

  @override
  String toString() =>
      'HintRectTracker(mode: ${mode.name}, running: $_running, value: $_value)';
}
