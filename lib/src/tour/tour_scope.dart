/// @docImport 'hint_target.dart';
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/hint_theme.dart';
import 'tour_controller.dart';
import 'tour_labels.dart';
import 'tour_storage.dart';

/// Hosts guided tours for the subtree below it.
///
/// Put one above the app so a tour can span routes:
///
/// ```dart
/// void main() => runApp(
///   TourScope(
///     storage: PrefsTourStorage(prefs),
///     child: const MyApp(),
///   ),
/// );
/// ```
///
/// The scope owns three things: the [TourController], the registry of
/// [HintTarget]s that have announced themselves, and the keyboard shortcuts
/// that drive a running tour.
///
/// It does **not** paint anything. Each step is rendered by its own
/// [HintTarget] through an [OverlayPortal], which is what lets a tour cross
/// routes: the step is drawn into whatever overlay its target happens to live
/// in, and a step whose target is not mounted yet simply waits for it.
class TourScope extends StatefulWidget {
  /// Creates a tour scope.
  const TourScope({
    required this.child,
    this.controller,
    this.storage,
    this.theme,
    this.labels = const TourLabels(),
    this.tourLengths,
    this.enableKeyboardShortcuts = true,
    this.stepTimeout,
    this.onStepUnavailable,
    super.key,
  }) : assert(
          controller == null || storage == null,
          'Pass storage to the TourController you supply, not to TourScope: '
          'otherwise there would be two answers to "has this tour run?".',
        );

  /// The subtree that can start tours and host targets.
  final Widget child;

  /// The controller to drive. One is created and disposed internally when this
  /// is null.
  final TourController? controller;

  /// Where completed tours are remembered.
  ///
  /// Defaults to [InMemoryTourStorage], which forgets on restart. Only valid
  /// when [controller] is null — a supplied controller brings its own.
  final TourStorage? storage;

  /// Visual overrides applied to every step in this scope.
  ///
  /// Merged over the ambient [HintThemeData] the same way a per-hint theme is.
  final HintThemeData? theme;

  /// The words on the default step card.
  ///
  /// Defaults to English. Supply your own to localise the tour — see
  /// [TourLabels], which takes them one by one rather than by locale so they
  /// can come from whatever localisation the app already has.
  final TourLabels labels;

  /// Declares how many steps a tour has, by name.
  ///
  /// Without this a tour's length is the number of targets that have
  /// registered so far, so a tour spanning routes would start life reporting
  /// "1 of 2" and grow to "3 of 5" as the user navigates. Declaring the length
  /// makes the progress indicator honest from the first step:
  ///
  /// ```dart
  /// TourScope(
  ///   tourLengths: const <String, int>{'onboarding': 5},
  ///   child: const MyApp(),
  /// )
  /// ```
  final Map<String, int>? tourLengths;

  /// Whether arrow keys, Enter and Escape drive a running tour.
  ///
  /// Left/up go back, right/down and Enter advance, Escape skips.
  final bool enableKeyboardShortcuts;

  /// How long to wait for a step's target before giving up on it.
  ///
  /// A step whose target is not mounted waits — that is what lets a tour cross
  /// routes, and it is why this is **null by default**: the package cannot
  /// tell "the user has not opened that screen yet" apart from "this target
  /// will never exist", and waiting is the safe reading of the two.
  ///
  /// Set it when your tour has steps that may genuinely never appear — a
  /// feature flag, a permission, a role — and you would rather the tour move
  /// on than sit there:
  ///
  /// ```dart
  /// TourScope(
  ///   stepTimeout: const Duration(seconds: 5),
  ///   onStepUnavailable: (String tour, int index) =>
  ///       analytics.log('tour_step_missing', <String, Object?>{'i': index}),
  ///   child: const MyApp(),
  /// )
  /// ```
  ///
  /// Prefer `HintTarget(enabled: false)` where you *know* a step does not
  /// apply: it keeps the step count honest instead of showing "4 of 5" and
  /// then skipping one.
  final Duration? stepTimeout;

  /// Called when [stepTimeout] elapses with no target for the active step.
  ///
  /// The tour advances immediately afterwards. Use it to log the gap — a step
  /// that times out in production usually means a target was removed and its
  /// tour was not updated.
  final void Function(String tour, int index)? onStepUnavailable;

  @override
  State<TourScope> createState() => TourScopeState();

  /// The nearest scope state, or null when there is none.
  static TourScopeState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TourScopeMarker>()?.state;

  /// The nearest scope state.
  ///
  /// Throws a [FlutterError] with a fix-it message when there is no scope
  /// above [context].
  static TourScopeState of(BuildContext context) {
    final TourScopeState? state = maybeOf(context);
    assert(() {
      if (state == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('No TourScope found above this widget.'),
          ErrorDescription(
            'HintTarget and Tour.of() both need a TourScope ancestor.',
          ),
          ErrorHint(
            'Wrap your app in one:\n'
            '  TourScope(child: MaterialApp(...))',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return state!;
  }
}

/// The state of a [TourScope]: the controller, the target registry and the
/// keyboard shortcuts.
///
/// Reach it with [TourScope.of]. Most apps only need [Tour.of], which returns
/// the controller directly.
class TourScopeState extends State<TourScope> {
  late TourController _controller = widget.controller ??
      TourController(storage: widget.storage ?? InMemoryTourStorage());
  bool _ownsController = false;

  /// Orders ever registered per tour, in ascending order.
  ///
  /// Orders are remembered after their target unmounts, which is what keeps
  /// step indices stable while the user navigates between routes mid-tour.
  final Map<String, SplayTreeSet<int>> _seenOrders =
      <String, SplayTreeSet<int>>{};

  /// Currently mounted targets, per tour and order.
  final Map<String, Map<int, VoidCallback>> _mounted =
      <String, Map<int, VoidCallback>>{};

  /// Orders whose targets have opted out with `enabled: false`.
  final Map<String, Set<int>> _disabledOrders = <String, Set<int>>{};

  /// Counts down while the active step has no target to draw itself.
  Timer? _unavailableTimer;

  /// The controller this scope drives.
  TourController get controller => _controller;

  /// Visual overrides for every step in this scope.
  HintThemeData? get theme => widget.theme;

  /// The words on this scope's step cards.
  TourLabels get labels => widget.labels;

  /// Where the spotlight hole was on the step that just finished.
  ///
  /// Steps render through their own [HintTarget]s, so the incoming step cannot
  /// ask the outgoing one where the light was — the scope is the only thing
  /// both of them can see. Null before the first step of a tour, which is
  /// exactly when there is nothing to travel from.
  Rect? _lastSpotlight;

  /// The hole the next step should travel from, or null to appear in place.
  Rect? get lastSpotlight => _lastSpotlight;

  /// Records where a step's spotlight is, for the step after it.
  ///
  /// Called every time the hole moves, so a step whose target scrolled is
  /// handed off from where it actually ended up.
  void reportSpotlight(Rect rect) => _lastSpotlight = rect;

  /// Forgets the last spotlight, so the next step does not travel.
  ///
  /// Called when a tour ends: the first step of the next tour should light up
  /// where it is, not fly in from wherever the last one finished.
  void clearSpotlight() => _lastSpotlight = null;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _bind(_controller);
  }

  @override
  void didUpdateWidget(TourScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbind(_controller);
      if (_ownsController) {
        _controller.dispose();
      }
      _ownsController = widget.controller == null;
      _controller = widget.controller ??
          TourController(storage: widget.storage ?? InMemoryTourStorage());
      _bind(_controller);
    }
  }

  void _bind(TourController controller) {
    bindTourStepCounter(controller, stepCount);
    controller.addListener(_onTourChanged);
    if (widget.enableKeyboardShortcuts) {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    }
  }

  void _unbind(TourController controller) {
    bindTourStepCounter(controller, null);
    controller.removeListener(_onTourChanged);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
  }

  void _onTourChanged() {
    if (!_controller.isRunning) {
      clearSpotlight();
    }
    _watchForUnavailableStep();
    // Every mounted target re-evaluates whether it is the active step.
    for (final Map<int, VoidCallback> targets in _mounted.values) {
      for (final VoidCallback notify in List<VoidCallback>.of(targets.values)) {
        notify();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Registry
  // ---------------------------------------------------------------------------

  /// Registers a target for [tour] at [order].
  ///
  /// [onTourChanged] is invoked whenever the active step may have changed.
  /// Called by a [HintTarget] when it mounts.
  void registerTarget(String tour, int order, VoidCallback onTourChanged) {
    final Map<int, VoidCallback> targets =
        _mounted.putIfAbsent(tour, () => <int, VoidCallback>{});
    assert(
      !targets.containsKey(order),
      'Two HintTargets are mounted for tour "$tour" at order $order. Orders '
      'identify steps, so they must be unique within a tour.',
    );
    targets[order] = onTourChanged;
    _disabledOrders[tour]?.remove(order);
    final SplayTreeSet<int> seen =
        _seenOrders.putIfAbsent(tour, SplayTreeSet<int>.new);
    final bool isNew = seen.add(order);
    if (isNew && _controller.activeTour == tour) {
      updateTourLength(_controller, stepCount(tour));
    }
    // A target that mounts after its step became active must catch up.
    onTourChanged();
    _watchForUnavailableStep();
  }

  /// Records that the target for [tour] at [order] has opted out of the tour.
  ///
  /// Called by a [HintTarget] built with `enabled: false`. The step is removed
  /// from the count rather than merely unmounted, which is the difference that
  /// matters: an unmounted step is one the tour should *wait* for, and an
  /// opted-out one is a step this user does not get at all.
  void disableTarget(String tour, int order) {
    _mounted[tour]?.remove(order);
    _seenOrders[tour]?.remove(order);
    _disabledOrders.putIfAbsent(tour, () => <int>{}).add(order);
    if (_controller.activeTour != tour) {
      return;
    }
    // Targets register and opt out from didChangeDependencies, which runs
    // during build. Telling the other steps now would mark them dirty
    // mid-build and open an OverlayPortal from inside a build — both of which
    // assert. The work is the same, one frame later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.activeTour != tour) {
        return;
      }
      updateTourLength(_controller, stepCount(tour));
      _onTourChanged();
    });
  }

  /// Deregisters a target, called when a [HintTarget] is disposed.
  ///
  /// The order stays in the "seen" set on purpose: a step that scrolled out of
  /// a lazy list, or whose route was pushed over, has not stopped existing.
  /// Use [disableTarget] for a step that genuinely does not apply.
  void deregisterTarget(String tour, int order) {
    _mounted[tour]?.remove(order);
    _watchForUnavailableStep();
  }

  /// How many steps [tour] has.
  ///
  /// The declared length from [TourScope.tourLengths] when there is one, less
  /// any step that has opted out with `enabled: false`; otherwise the number
  /// of distinct orders seen so far. Subtracting matters because a declared
  /// length is a promise about *this* run: a card reading "3 of 5" when two
  /// steps do not apply to this user is simply wrong.
  int stepCount(String tour) {
    final int? declared = widget.tourLengths?[tour];
    if (declared == null) {
      return _seenOrders[tour]?.length ?? 0;
    }
    final int disabled = _disabledOrders[tour]?.length ?? 0;
    final int remaining = declared - disabled;
    return remaining < 0 ? 0 : remaining;
  }

  /// The order that step [index] of [tour] refers to, or null when no target
  /// has claimed that position yet.
  int? orderAt(String tour, int index) {
    final SplayTreeSet<int>? seen = _seenOrders[tour];
    if (seen == null || index < 0 || index >= seen.length) {
      return null;
    }
    return seen.elementAt(index);
  }

  /// Whether the target for [tour] at [order] is the active step.
  bool isActiveStep(String tour, int order) =>
      _controller.activeTour == tour &&
      orderAt(tour, _controller.index) == order;

  /// Whether some mounted target is currently drawing the active step.
  ///
  /// False in two different situations that look the same from here: no target
  /// has ever claimed this position, and one has but is not mounted right now
  /// — a step on a route the user has not pushed. Only a clock can tell them
  /// apart, which is what [TourScope.stepTimeout] is.
  bool get _activeStepIsDrawable {
    final String? tour = _controller.activeTour;
    if (tour == null) {
      return true;
    }
    final int? order = orderAt(tour, _controller.index);
    return order != null && (_mounted[tour]?.containsKey(order) ?? false);
  }

  /// Starts, restarts or cancels the countdown on an undrawable step.
  void _watchForUnavailableStep() {
    final Duration? timeout = widget.stepTimeout;
    final String? tour = _controller.activeTour;
    if (timeout == null || tour == null || _activeStepIsDrawable) {
      _unavailableTimer?.cancel();
      _unavailableTimer = null;
      return;
    }
    if (_unavailableTimer != null) {
      // Already counting down for this step; restarting it on every rebuild
      // would mean it never fires.
      return;
    }
    final int index = _controller.index;
    _unavailableTimer = Timer(timeout, () {
      _unavailableTimer = null;
      if (!mounted ||
          _controller.activeTour != tour ||
          _controller.index != index ||
          _activeStepIsDrawable) {
        return;
      }
      widget.onStepUnavailable?.call(tour, index);
      // next() finishes the tour when there is nothing after this, which is
      // the right ending for a last step that never arrived.
      _controller.next();
    });
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  bool _onKeyEvent(KeyEvent event) {
    if (!widget.enableKeyboardShortcuts ||
        !_controller.isRunning ||
        event is! KeyDownEvent) {
      return false;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _controller.skip();
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        _controller.next();
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
        _controller.previous();
      default:
        return false;
    }
    return true;
  }

  @override
  void dispose() {
    _unavailableTimer?.cancel();
    _unbind(_controller);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TourScopeMarker(
      state: this,
      child: Tour._(controller: _controller, child: widget.child),
    );
  }
}

/// Marks the scope so descendants can find its state.
class _TourScopeMarker extends InheritedWidget {
  const _TourScopeMarker({required this.state, required super.child});

  final TourScopeState state;

  @override
  bool updateShouldNotify(_TourScopeMarker oldWidget) =>
      oldWidget.state != state;
}

/// Access point for the running tour.
///
/// ```dart
/// Tour.of(context).start('onboarding');
/// ```
///
/// This is an [InheritedNotifier], so a widget that reads it with [Tour.of]
/// rebuilds whenever the tour advances — handy for a "step 2 of 5" label in
/// your own chrome. Use [Tour.read] to issue a command without subscribing.
class Tour extends InheritedNotifier<TourController> {
  const Tour._({required TourController controller, required super.child})
      : super(notifier: controller);

  /// The nearest tour controller, subscribing [context] to its changes.
  ///
  /// Throws when there is no [TourScope] above [context].
  static TourController of(BuildContext context) {
    final Tour? tour = context.dependOnInheritedWidgetOfExactType<Tour>();
    assert(() {
      if (tour == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Tour.of() called without a TourScope ancestor.'),
          ErrorHint('Wrap your app: TourScope(child: MaterialApp(...))'),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return tour!.notifier!;
  }

  /// The nearest tour controller, or null when there is no [TourScope].
  static TourController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Tour>()?.notifier;

  /// The nearest tour controller *without* subscribing to it.
  ///
  /// Use this in a callback — `onPressed: () => Tour.read(context).start(...)`
  /// — where rebuilding on every step change would be wasted work.
  static TourController read(BuildContext context) {
    final _TourScopeMarker? marker =
        context.getInheritedWidgetOfExactType<_TourScopeMarker>();
    assert(
      marker != null,
      'Tour.read() called without a TourScope ancestor. Wrap your app: '
      'TourScope(child: MaterialApp(...))',
    );
    return marker!.state.controller;
  }
}
