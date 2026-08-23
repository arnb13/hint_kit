/// @docImport 'package:flutter/widgets.dart';
/// @docImport '../core/hint_trigger.dart';
/// @docImport '../tour/hint_target.dart';
/// @docImport '../tour/tour_scope.dart';
/// @docImport 'hint.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hint_controller.dart';

/// Shows a series of hints one after another, without a tour.
///
/// A tour dims the screen, traps focus and takes over. Sometimes all you want
/// is three tips in order, each waiting for the last to be dismissed:
///
/// ```dart
/// final HintQueue tips = HintQueue(<HintController>[
///   _filterTip,
///   _sortTip,
///   _exportTip,
/// ]);
///
/// // Anywhere: after the first build, on a button, once per install.
/// tips.start();
/// ```
///
/// Each entry is the [HintController] of a hint whose triggers include
/// [HintTrigger.manual]. The queue opens the first, waits for it to close —
/// however it closes: a tap outside, `showDuration`, Esc, another hint taking
/// the floor — then opens the next after [gap].
///
/// It never opens a hint whose controller is not attached to a mounted hint,
/// so a queue that reaches a step on a route the user has left simply stops
/// rather than opening a bubble with nothing to point at. Use [onFinished] to
/// learn how it ended.
///
/// This is deliberately not a [TourScope]: there is no scrim, no spotlight, no
/// step card and no persistence. For those, use [HintTarget].
class HintQueue extends ChangeNotifier {
  /// Creates a queue over [controllers], in the order they should appear.
  HintQueue(
    List<HintController> controllers, {
    this.gap = const Duration(milliseconds: 250),
    this.onFinished,
  })  : assert(controllers.isNotEmpty, 'A HintQueue needs at least one hint.'),
        _controllers = List<HintController>.unmodifiable(controllers);

  final List<HintController> _controllers;

  /// How long to wait after one hint closes before opening the next.
  ///
  /// A small pause reads as "here is the next thing" rather than as a flicker.
  /// [Duration.zero] opens the next hint on the same frame.
  final Duration gap;

  /// Called once when the queue stops, with `true` if every hint was shown.
  ///
  /// `false` means it stopped early: [stop] was called, or a hint's controller
  /// had no mounted hint to drive.
  final void Function({required bool completed})? onFinished;

  int _index = -1;
  bool _running = false;
  Timer? _gapTimer;
  HintController? _listening;

  /// Whether the queue is currently working through its hints.
  bool get isRunning => _running;

  /// The zero-based position of the hint being shown, or `-1` when idle.
  int get index => _index;

  /// How many hints the queue holds.
  int get length => _controllers.length;

  /// Opens the first hint and starts the sequence.
  ///
  /// A no-op while already running. Calling it again after the queue has
  /// finished starts over from the beginning.
  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _index = -1;
    notifyListeners();
    _advance();
  }

  /// Closes the current hint and moves on to the next one immediately.
  ///
  /// Useful for a "next tip" button inside an interactive bubble.
  void next() {
    if (!_running) {
      return;
    }
    _unlisten();
    _controllers[_index].hide();
    _advance();
  }

  /// Stops the sequence and closes whatever is open.
  void stop() {
    if (!_running) {
      return;
    }
    final HintController? current = _index >= 0 ? _controllers[_index] : null;
    _finish(completed: false);
    current?.hide();
  }

  void _advance() {
    _gapTimer?.cancel();
    final int next = _index + 1;
    if (next >= _controllers.length) {
      _finish(completed: true);
      return;
    }
    _index = next;
    notifyListeners();

    void open() {
      if (!_running) {
        return;
      }
      final HintController controller = _controllers[_index];
      if (!controller.isAttached) {
        // Nothing to point at: the hint's route was popped, or it has not been
        // built yet. Stopping is quieter than opening a bubble in a corner.
        _finish(completed: false);
        return;
      }
      _listen(controller);
      controller.show();
    }

    if (gap == Duration.zero || _index == 0) {
      open();
    } else {
      _gapTimer = Timer(gap, open);
    }
  }

  /// Waits for the open hint to close, whoever closes it.
  void _listen(HintController controller) {
    _unlisten();
    _listening = controller;
    controller.addListener(_onControllerChanged);
  }

  void _unlisten() {
    _listening?.removeListener(_onControllerChanged);
    _listening = null;
  }

  void _onControllerChanged() {
    final HintController? controller = _listening;
    if (controller == null || controller.isShown) {
      return;
    }
    _unlisten();
    _advance();
  }

  void _finish({required bool completed}) {
    _gapTimer?.cancel();
    _gapTimer = null;
    _unlisten();
    _running = false;
    _index = -1;
    notifyListeners();
    onFinished?.call(completed: completed);
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    _unlisten();
    super.dispose();
  }

  @override
  String toString() => 'HintQueue($_index of ${_controllers.length})';
}
