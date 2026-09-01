import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/hint_observer.dart';
import '../core/hint_side.dart';
import '../core/hint_trigger.dart';
import '../core/rect_tracker.dart';
import '../theme/hint_theme.dart';
import 'anchored_bubble.dart';
import 'hint_bubble.dart';
import 'hint_controller.dart';
import 'hint_registry.dart';

/// Signature for building rich hint content.
///
/// {@category Hints}
typedef HintContentBuilder = Widget Function(BuildContext context);

/// A tooltip, a persistent hint or a programmatic callout attached to [child].
///
/// One widget covers all three, because they differ only in what opens them:
///
/// ```dart
/// // A tooltip.
/// Hint(
///   message: 'Delete this shift',
///   triggers: const <HintTrigger>{HintTrigger.longPress, HintTrigger.hover},
///   child: IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
/// )
///
/// // A hint on a disabled control — the case other packages cannot do.
/// Hint(
///   message: 'You need an active shift to check in',
///   child: ElevatedButton(onPressed: null, child: const Text('Check in')),
/// )
///
/// // A programmatic hint.
/// Hint(
///   controller: _controller,
///   triggers: const <HintTrigger>{HintTrigger.manual},
///   message: 'Saved',
///   child: saveButton,
/// )
/// ```
///
/// ## Why it works on disabled widgets
///
/// Triggers are recognised from a [Listener], which reads raw pointer events
/// and never enters the gesture arena. That has two consequences, both of them
/// the point of this package:
///
/// * a child that ignores pointers — `ElevatedButton(onPressed: null)` — does
///   not stop the hint from seeing the touch, and
/// * a child that *does* handle pointers keeps its gesture: the hint never
///   competes for it, so wrapping an enabled button changes nothing about how
///   that button behaves.
///
/// The one case this cannot win is an [IgnorePointer] or [AbsorbPointer]
/// *above* the hint in the tree: it stops the pointer before it ever reaches
/// the hint. Put the `Hint` outside the `IgnorePointer` instead:
///
/// ```dart
/// // Does not work: the hint never sees the pointer.
/// IgnorePointer(child: Hint(message: '...', child: button))
///
/// // Works.
/// Hint(message: '...', child: IgnorePointer(child: button))
/// ```
///
/// ## Overlay lifetime
///
/// The bubble is shown with an [OverlayPortal], so its lifetime is tied to
/// this widget's element. Popping the route mid-tooltip takes the bubble with
/// it; there is no [OverlayEntry] left behind to leak.
///
/// {@category Hints}
class Hint extends StatefulWidget {
  /// Creates a hint attached to [child].
  ///
  /// Supply exactly one of [message]/[title] or [contentBuilder].
  const Hint({
    required this.child,
    this.message,
    this.title,
    this.contentBuilder,
    this.controller,
    this.triggers = const <HintTrigger>{
      HintTrigger.longPress,
      HintTrigger.hover,
    },
    this.direction = HintDirection.auto,
    this.theme,
    this.absorbChildInput = false,
    this.interactive = false,
    this.exclusive = true,
    this.dismissOnTapOutside = true,
    this.waitDuration = Duration.zero,
    this.showDuration,
    this.barrierColor,
    this.followTarget = false,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    this.showOnce,
    this.analyticsId,
    this.mouseCursor,
    this.followPointer = false,
    this.onShow,
    this.onDismiss,
    super.key,
  })  : assert(
          showOnce == null || showOnce.length > 0,
          'showOnce must be a non-empty key; it is stored verbatim.',
        ),
        assert(
          message != null || title != null || contentBuilder != null,
          'A Hint needs a message, a title or a contentBuilder.',
        ),
        assert(
          contentBuilder == null || (message == null && title == null),
          'Pass either a contentBuilder or a message/title, not both: the '
          'builder would win and the message would silently never appear.',
        );

  /// The widget the hint is attached to and points at.
  final Widget child;

  /// The bubble's body text.
  final String? message;

  /// An optional bold line above [message].
  final String? title;

  /// Builds arbitrary bubble content.
  ///
  /// Use with `interactive: true` when the content contains buttons or links,
  /// so moving the pointer into the bubble does not dismiss it.
  final HintContentBuilder? contentBuilder;

  /// Drives the hint programmatically. See [HintController].
  final HintController? controller;

  /// What opens the hint. See [HintTrigger].
  final Set<HintTrigger> triggers;

  /// Which side of the target the bubble prefers. See [HintDirection].
  final HintDirection direction;

  /// Per-instance visual overrides, merged over the ambient theme field by
  /// field.
  final HintThemeData? theme;

  /// Inserts a transparent hit layer above [child].
  ///
  /// The default pointer path already works for children that ignore pointers,
  /// including disabled buttons. This escape hatch is for children that do not
  /// hit-test *at all* — a platform view that swallows events, a custom render
  /// box with `hitTestSelf` false over a transparent area.
  ///
  /// It also stops the child from receiving the pointer, so do not use it on
  /// an interactive child.
  final bool absorbChildInput;

  /// Whether the pointer may move from the target into the bubble without
  /// dismissing it.
  ///
  /// Required for bubbles with buttons or links inside.
  final bool interactive;

  /// Whether opening this hint closes any other open hint.
  ///
  /// Defaults to true, which is what you want for tooltips. Set it to false
  /// for a persistent hint that should survive an unrelated tooltip opening —
  /// a validation message pinned to a field, for instance.
  final bool exclusive;

  /// Whether a pointer down outside the bubble dismisses it.
  ///
  /// When [barrierColor] is null the dismissing tap still reaches the app, so
  /// a hover tooltip never eats a click. With a [barrierColor] the barrier is
  /// modal and absorbs it.
  final bool dismissOnTapOutside;

  /// How long the pointer must rest on the target before a hover shows the
  /// hint.
  final Duration waitDuration;

  /// Auto-hide delay. Null keeps the hint open until something closes it.
  ///
  /// Ignored under [MediaQueryData.accessibleNavigation]: a screen-reader user
  /// cannot read a bubble that disappears on a timer.
  final Duration? showDuration;

  /// Paints a full-screen scrim behind the bubble.
  ///
  /// Also makes the barrier modal — see [dismissOnTapOutside].
  final Color? barrierColor;

  /// Re-measures the target every frame instead of on scroll and resize.
  ///
  /// The bubble already follows the target at the layer level, so this is only
  /// needed when the *decision* — which side, how far to shift — has to update
  /// continuously, e.g. while the target animates across a screen edge.
  ///
  /// Read once, when the hint is first created: changing it later has no
  /// effect. Give the hint a new [Key] if you need to switch modes at runtime.
  final bool followTarget;

  /// Overrides the text a screen reader gets, in both places the hint speaks:
  /// the target's semantic tooltip, and the open bubble.
  ///
  /// Defaults to [message] for the tooltip, and to [title] and [message]
  /// together for the bubble. Content from a [contentBuilder] has no text of
  /// its own, so it is spoken as it opens only when this is set — the content's
  /// own semantics stay readable either way.
  ///
  /// Ignored when [excludeFromSemantics] is true.
  final String? semanticsLabel;

  /// Whether to skip adding a semantic tooltip to the target.
  ///
  /// Set this when the child already carries the same information — otherwise
  /// a screen reader reads it twice. Also stops the bubble from being spoken
  /// as it opens.
  final bool excludeFromSemantics;

  /// Shows this hint only the first time, ever, under this key.
  ///
  /// The key is recorded in [HintRegistry.storage] as the bubble opens, and
  /// every later attempt to show it — by trigger, by controller, by
  /// [HintTrigger.onAppear] — does nothing. This is the "new feature" callout
  /// that must not nag:
  ///
  /// ```dart
  /// Hint(
  ///   showOnce: 'payslip-tip',
  ///   triggers: const <HintTrigger>{HintTrigger.onAppear},
  ///   message: 'Payslips live here now',
  ///   child: payslipTab,
  /// )
  /// ```
  ///
  /// The default storage forgets on restart; point
  /// [HintRegistry.storage] at real persistence to make it stick, and use
  /// [HintRegistry.resetShowOnce] to let a hint appear again.
  ///
  /// Reading the flag is asynchronous, so a hint that is already open when the
  /// answer arrives is left alone: the guard applies to opening, never to
  /// closing something the user is reading.
  final String? showOnce;

  /// The cursor shown while the pointer is over the target.
  ///
  /// Defaults to whatever the child asks for. [SystemMouseCursors.help] is the
  /// conventional choice for a target whose whole job is to explain itself.
  final MouseCursor? mouseCursor;

  /// Anchors the bubble to the pointer instead of to the target.
  ///
  /// The bubble follows the cursor while it moves over the target, which is
  /// what a chart, a map or a canvas wants: the thing being explained is the
  /// position, not the widget. Placement still runs, so the bubble flips sides
  /// near a screen edge rather than sliding off it.
  ///
  /// Mouse only — a finger is already covering the thing the bubble explains —
  /// so pair it with [HintTrigger.hover]. With no pointer to follow, e.g. a
  /// hint opened from a controller, it anchors on the target as usual.
  ///
  /// Not compatible with layer-level target tracking: a bubble that follows
  /// the cursor is positioned in overlay coordinates every move, so it does
  /// not also follow a scroll on the compositor.
  final bool followPointer;

  /// A stable identifier reported to a [HintObserver].
  ///
  /// Text is the fallback, but text changes; an id does not. Ignored when no
  /// observer is registered.
  final String? analyticsId;

  /// Called when the hint opens. Useful for onboarding funnels.
  final VoidCallback? onShow;

  /// Called when the hint closes, for any reason.
  final VoidCallback? onDismiss;

  @override
  State<Hint> createState() => _HintState();
}

class _HintState extends State<Hint>
    with SingleTickerProviderStateMixin
    implements DismissibleHint {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'Hint',
  );
  final LayerLink _link = LayerLink();
  late final HintRectTracker _tracker = HintRectTracker(
    mode: widget.followTarget
        ? RectTrackingMode.perFrame
        : RectTrackingMode.onDemand,
  );
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );

  Timer? _waitTimer;
  Timer? _showTimer;
  Timer? _longPressTimer;
  Timer? _exitTimer;

  Offset? _pointerDownPosition;
  int? _pointerDownId;
  bool _pointerMoved = false;
  bool _pointerDownSecondary = false;
  bool _pointerInTarget = false;
  bool _pointerInBubble = false;
  bool _isShown = false;
  bool _keyHandlerInstalled = false;

  /// Whether [Hint.showOnce] has already been recorded for this key.
  ///
  /// Starts pessimistic when there is a key: the flag is read asynchronously,
  /// and showing a hint that turns out to have been seen is the mistake that
  /// matters. It is cleared as soon as storage answers "not yet".
  bool _showOnceBlocked = false;

  /// Completes when the [Hint.showOnce] flag has been read.
  ///
  /// Null when the hint has no key, in which case nothing waits.
  Future<void>? _showOnceReady;

  /// What opened the bubble, for [HintObserver] and nothing else.
  HintTrigger? _openedBy;

  /// The pointer's position in global coordinates, for [Hint.followPointer].
  ///
  /// A [ValueNotifier] rather than state: the bubble rebuilds on every mouse
  /// move while following, and rebuilding the *target* subtree that often
  /// would be wasteful. The overlay listens to it, nothing else does.
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  /// Whether the bubble is open, i.e. showing or animating in.
  bool get isShown => _isShown;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    _readShowOnce();
    addShowOnceResetListener(_onShowOnceReset);
    if (widget.triggers.contains(HintTrigger.onAppear)) {
      // The target has not been laid out yet; showing now would measure an
      // empty rect.
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        // A showOnce hint waits for storage first, so the very case the key
        // exists for — "do not show it again on launch" — is not lost to a
        // race with the first frame.
        await _showOnceReady;
        if (mounted) {
          _showFrom(HintTrigger.onAppear);
        }
      });
    }
  }

  /// Re-arms this hint when its own [Hint.showOnce] key is forgotten.
  ///
  /// The flag is cached in this state — it is latched as the bubble opens, so
  /// that the same hint cannot open twice in one session — and a reset has to
  /// clear that cache as well as the storage, or "show it again" would only
  /// work after a restart.
  void _onShowOnceReset(String key) {
    if (key != widget.showOnce) {
      return;
    }
    _readShowOnce();
  }

  /// Reads the [Hint.showOnce] flag, if there is a key.
  void _readShowOnce() {
    final String? key = widget.showOnce;
    if (key == null) {
      _showOnceBlocked = false;
      _showOnceReady = null;
      return;
    }
    debugCheckShowOnceStorageWiring();
    _showOnceBlocked = true;
    _showOnceReady = HintRegistry.instance.storage.isCompleted(key).then(
      (bool seen) {
        if (mounted) {
          _showOnceBlocked = seen;
        }
      },
      onError: (Object _) {
        // A storage that throws must not silence the hint forever; an
        // unreadable flag is treated as "not seen yet".
        if (mounted) {
          _showOnceBlocked = false;
        }
      },
    );
  }

  /// The event describing this hint, for observers.
  HintEvent get _event => HintEvent(
        id: widget.analyticsId,
        label: widget.semanticsLabel ?? widget.message ?? widget.title,
        trigger: _openedBy,
        showOnce: widget.showOnce,
      );

  /// Opens the bubble and remembers which trigger did it.
  void _showFrom(HintTrigger? trigger) {
    _openedBy = trigger;
    show();
  }

  @override
  void didUpdateWidget(Hint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
    }
    if (oldWidget.showOnce != widget.showOnce) {
      // A new key is a new question; the answer cached for the old one says
      // nothing about it.
      _readShowOnce();
    }
    if (_isShown &&
        oldWidget.triggers != widget.triggers &&
        widget.triggers.isEmpty) {
      // A hint with no triggers left has nothing that could close it either.
      hide();
    }
  }

  void _attachController(HintController? controller) {
    if (controller == null) {
      return;
    }
    attachHintController(controller);
    controller.addListener(_onControllerChanged);
    hintRefreshRequests(controller).addListener(_onRefreshRequested);
    if (controller.isShown && !_isShown) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.isShown) {
          show();
        }
      });
    }
  }

  void _detachController(HintController? controller) {
    if (controller == null) {
      return;
    }
    controller.removeListener(_onControllerChanged);
    hintRefreshRequests(controller).removeListener(_onRefreshRequested);
    detachHintController(controller);
  }

  void _onControllerChanged() {
    final HintController controller = widget.controller!;
    if (controller.isShown && !_isShown) {
      show();
    } else if (!controller.isShown && _isShown) {
      hide();
    }
  }

  void _onRefreshRequested() => _tracker.refresh();

  void _syncController({required bool shown}) {
    final HintController? controller = widget.controller;
    if (controller != null) {
      syncHintController(controller, shown: shown);
    }
  }

  // ---------------------------------------------------------------------------
  // Show / hide
  // ---------------------------------------------------------------------------

  /// Opens the bubble.
  ///
  /// Does nothing when [Hint.showOnce] names a key that has already been
  /// recorded — including when called from a [HintController], which is the
  /// point: "show it once" must hold however the hint is opened.
  void show() {
    if (!mounted || _isShown) {
      return;
    }
    if (_showOnceBlocked) {
      // Keep a controller's idea of the world honest: it asked for a bubble
      // that is never going to appear.
      _syncController(shown: false);
      return;
    }
    _markShownOnce();
    _isShown = true;
    _cancelWait();
    if (widget.exclusive) {
      HintRegistry.instance.open(this);
    }
    _portal.show();
    _tracker.start(
      targetContext: context,
      overlayContext: Overlay.of(context, debugRequiredFor: widget).context,
    );
    _animation.duration = _resolvedTheme().transitionDuration;
    _animation.reverseDuration = _resolvedTheme().reverseTransitionDuration;
    if (_animationsDisabled) {
      _animation.value = 1;
    } else {
      unawaited(_animation.forward());
    }
    _installKeyHandler();
    _startAutoHideTimer();
    _syncController(shown: true);
    widget.onShow?.call();
    HintRegistry.instance.notifyShown(_event);
    setState(() {});
  }

  /// Records the [Hint.showOnce] key as seen, as the bubble opens.
  ///
  /// Written on show rather than on dismiss: a user who saw the hint has seen
  /// it, whether or not they stayed to read it, and a write that waits for the
  /// dismissal is a write that a killed app loses.
  void _markShownOnce() {
    final String? key = widget.showOnce;
    if (key == null) {
      return;
    }
    _showOnceBlocked = true;
    unawaited(HintRegistry.instance.storage.markCompleted(key));
  }

  /// Closes the bubble.
  void hide() {
    if (!mounted || !_isShown) {
      return;
    }
    _isShown = false;
    _cancelWait();
    _showTimer?.cancel();
    _exitTimer?.cancel();
    _removeKeyHandler();
    HintRegistry.instance.close(this);
    _syncController(shown: false);
    widget.onDismiss?.call();
    HintRegistry.instance.notifyDismissed(_event);
    _openedBy = null;
    if (_animationsDisabled) {
      _animation.value = 0;
      _finishHide();
    } else {
      _animation.reverse().whenComplete(() {
        if (!_isShown) {
          _finishHide();
        }
      });
    }
    setState(() {});
  }

  /// Tears the overlay down once the exit animation has finished.
  void _finishHide() {
    if (!mounted || _isShown) {
      return;
    }
    _portal.hide();
    _tracker.stop();
  }

  @override
  void dismissForExclusivity() => hide();

  /// What a screen reader reads out when the bubble opens.
  ///
  /// Null when the hint opts out of semantics, or when there is nothing to
  /// read: rich content has no text of its own, so a caller who wants it
  /// spoken passes [Hint.semanticsLabel].
  String? get _bubbleSemanticsLabel {
    if (widget.excludeFromSemantics) {
      return null;
    }
    final String? explicit = widget.semanticsLabel;
    if (explicit != null) {
      return explicit.isEmpty ? null : explicit;
    }
    if (widget.contentBuilder != null) {
      return null;
    }
    // Both lines, in reading order: the bubble node stands in for the text it
    // hides from the tree, so dropping the title would lose it entirely.
    final String text = <String?>[widget.title, widget.message]
        .whereType<String>()
        .where((String part) => part.isNotEmpty)
        .join('\n');
    return text.isEmpty ? null : text;
  }

  bool get _animationsDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _accessibleNavigation =>
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

  void _startAutoHideTimer() {
    _showTimer?.cancel();
    final Duration? duration = widget.showDuration;
    if (duration == null) {
      return;
    }
    if (_accessibleNavigation) {
      // Deliberately no timer: see Hint.showDuration.
      return;
    }
    _showTimer = Timer(duration, hide);
  }

  void _cancelWait() {
    _waitTimer?.cancel();
    _waitTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  void _installKeyHandler() {
    if (_keyHandlerInstalled) {
      return;
    }
    _keyHandlerInstalled = true;
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  void _removeKeyHandler() {
    if (!_keyHandlerInstalled) {
      return;
    }
    _keyHandlerInstalled = false;
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
  }

  /// Dismisses on Escape without taking focus from whatever has it.
  bool _onKeyEvent(KeyEvent event) {
    if (!_isShown ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    hide();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Raw pointer triggers
  // ---------------------------------------------------------------------------

  bool get _wantsTap => widget.triggers.contains(HintTrigger.tap);

  bool get _wantsSecondaryTap =>
      widget.triggers.contains(HintTrigger.secondaryTap);

  bool get _wantsLongPress => widget.triggers.contains(HintTrigger.longPress);

  bool get _wantsHover => widget.triggers.contains(HintTrigger.hover);

  bool get _wantsFocus => widget.triggers.contains(HintTrigger.focus);

  void _onPointerDown(PointerDownEvent event) {
    if (!_wantsTap && !_wantsLongPress && !_wantsSecondaryTap) {
      return;
    }
    _pointerDownPosition = event.position;
    _pointerDownId = event.pointer;
    _pointerMoved = false;
    // Which button went down decides which trigger the release belongs to, so
    // a right-click never opens a tap hint and vice versa.
    _pointerDownSecondary = event.buttons & kSecondaryButton != 0;
    if (_wantsLongPress && !_pointerDownSecondary) {
      // Recognised by hand rather than with a LongPressGestureDetector: a
      // gesture recogniser would join the arena and could beat the child's own
      // long press, which would break an enabled child.
      _longPressTimer = Timer(kLongPressTimeout, () {
        if (!_pointerMoved && _pointerDownId == event.pointer) {
          _toggleFromTrigger(HintTrigger.longPress);
        }
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final Offset? origin = _pointerDownPosition;
    if (origin == null || event.pointer != _pointerDownId) {
      return;
    }
    if ((event.position - origin).distance > kTouchSlop) {
      _pointerMoved = true;
      _longPressTimer?.cancel();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    final Offset? origin = _pointerDownPosition;
    final bool isTap = origin != null &&
        !_pointerMoved &&
        event.pointer == _pointerDownId &&
        (event.position - origin).distance <= kTouchSlop;
    _pointerDownPosition = null;
    _pointerDownId = null;
    if (!isTap) {
      return;
    }
    if (_pointerDownSecondary) {
      if (_wantsSecondaryTap) {
        _toggleFromTrigger(HintTrigger.secondaryTap);
      }
    } else if (_wantsTap) {
      _toggleFromTrigger(HintTrigger.tap);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _pointerDownPosition = null;
    _pointerDownId = null;
    _pointerMoved = false;
  }

  /// Opens on a trigger, or closes if this hint is already the open one.
  void _toggleFromTrigger(HintTrigger trigger) {
    if (_isShown) {
      hide();
    } else {
      _showFrom(trigger);
    }
  }

  void _onEnter(PointerEnterEvent event) {
    _pointerInTarget = true;
    _exitTimer?.cancel();
    if (widget.followPointer) {
      _pointer.value = event.position;
    }
    if (!_wantsHover || _isShown) {
      return;
    }
    if (widget.waitDuration == Duration.zero) {
      _showFrom(HintTrigger.hover);
      return;
    }
    _cancelWait();
    _waitTimer = Timer(widget.waitDuration, () {
      if (_pointerInTarget) {
        _showFrom(HintTrigger.hover);
      }
    });
  }

  void _onExit(PointerExitEvent event) {
    _pointerInTarget = false;
    _pointer.value = null;
    _cancelWait();
    if (!_wantsHover || !_isShown) {
      return;
    }
    _scheduleHoverExit();
  }

  /// Hides after a grace period, unless the pointer landed in the bubble.
  ///
  /// The grace period exists because the target and the bubble are separated
  /// by [ResolvedHintTheme.gap]: moving between them means leaving both for a
  /// frame or two.
  void _scheduleHoverExit() {
    _exitTimer?.cancel();
    if (!widget.interactive) {
      hide();
      return;
    }
    _exitTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_pointerInTarget && !_pointerInBubble) {
        hide();
      }
    });
  }

  void _onFocusChange(bool hasFocus) {
    if (!_wantsFocus) {
      return;
    }
    if (hasFocus) {
      _showFrom(HintTrigger.focus);
    } else {
      hide();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  ResolvedHintTheme _resolvedTheme() =>
      HintThemeData.resolve(context, widget.theme);

  /// The margin the bubble keeps from the overlay edges: the theme's value,
  /// widened by the safe area so bubbles clear notches and system bars.
  EdgeInsets _margin(ResolvedHintTheme theme) {
    final EdgeInsets padding =
        MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final EdgeInsets margin = theme.screenMargin;
    double max(double a, double b) => a > b ? a : b;
    return EdgeInsets.fromLTRB(
      max(margin.left, padding.left),
      max(margin.top, padding.top),
      max(margin.right, padding.right),
      max(margin.bottom, padding.bottom),
    );
  }

  Size _overlaySize() {
    final RenderObject? box = Overlay.of(context, debugRequiredFor: widget)
        .context
        .findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.size;
    }
    return MediaQuery.sizeOf(context);
  }

  /// Dismisses on a pointer down that is genuinely *outside* the target.
  ///
  /// The barrier covers the whole overlay, target included, so without this a
  /// second tap on the target would be handled twice: the barrier would close
  /// the hint and the trigger would immediately reopen it.
  void _onBarrierPointerDown(PointerDownEvent event) {
    final Rect? target = _tracker.value;
    if (target != null) {
      final RenderObject? overlayObject = Overlay.of(
        context,
        debugRequiredFor: widget,
      ).context.findRenderObject();
      if (overlayObject is RenderBox && overlayObject.hasSize) {
        final Offset local = overlayObject.globalToLocal(event.position);
        if (target.contains(local)) {
          return;
        }
      }
    }
    hide();
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    // Rebuilding on the tracker rather than with setState keeps a re-measure
    // from rebuilding the target subtree, which is the expensive half.
    return ListenableBuilder(
      // While following the pointer the bubble also has to rebuild on every
      // mouse move, which is a second source of "where does this go".
      listenable: widget.followPointer
          ? Listenable.merge(<Listenable>[_tracker, _pointer])
          : _tracker,
      builder: (BuildContext context, Widget? _) => _buildBubble(context),
    );
  }

  /// Whether the bubble is currently anchored to the cursor.
  ///
  /// False until a mouse has actually been over the target, so a
  /// [Hint.followPointer] hint opened from a controller still points at the
  /// widget rather than at the origin.
  bool get _followingPointer => widget.followPointer && _pointer.value != null;

  /// The rect placement should work from: the target, or the pointer.
  ///
  /// A cursor has no size, so it becomes a zero-sized rect — the resolver
  /// treats it like any other target, which is what keeps the bubble on screen
  /// and flips it near an edge.
  Rect _anchorRect(Rect target) {
    final Offset? global = _pointer.value;
    if (!widget.followPointer || global == null) {
      return target;
    }
    final Offset? local = _toOverlay(global);
    return local == null
        ? target
        : Rect.fromCenter(center: local, width: 0, height: 0);
  }

  /// Converts a global position into the overlay's coordinate space.
  Offset? _toOverlay(Offset global) {
    final RenderObject? box = Overlay.of(
      context,
      debugRequiredFor: widget,
    ).context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.globalToLocal(global);
    }
    return null;
  }

  void _onHover(PointerHoverEvent event) => _pointer.value = event.position;

  Widget _buildBubble(BuildContext overlayContext) {
    final ResolvedHintTheme theme = _resolvedTheme();
    final Rect? target = _tracker.value;
    if (target == null) {
      // Nothing measurable to point at — the target was scrolled out of a lazy
      // list, or its first layout has not landed yet.
      return const SizedBox.shrink();
    }
    final Color? barrierColor = widget.barrierColor;
    return Stack(
      children: <Widget>[
        if (widget.dismissOnTapOutside || barrierColor != null)
          Positioned.fill(
            child: Listener(
              // A coloured barrier is modal and eats the tap; a transparent one
              // lets it through, so a hover tooltip never swallows a click.
              behavior: barrierColor == null
                  ? HitTestBehavior.translucent
                  : HitTestBehavior.opaque,
              onPointerDown:
                  widget.dismissOnTapOutside ? _onBarrierPointerDown : null,
              child: barrierColor == null
                  ? const SizedBox.expand()
                  : FadeTransition(
                      opacity: _animation,
                      child: ColoredBox(
                        color: barrierColor,
                        child: const SizedBox.expand(),
                      ),
                    ),
            ),
          ),
        AnchoredHintBubble(
          targetRect: _anchorRect(target),
          overlaySize: _overlaySize(),
          margin: _margin(theme),
          direction: widget.direction,
          theme: theme,
          animation: _animation,
          // A bubble anchored to the cursor is positioned in overlay
          // coordinates on every move, so there is nothing for the compositor
          // to follow.
          link: _followingPointer ? null : _link,
          builder: (BuildContext context) => _buildContent(context, theme),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ResolvedHintTheme theme) {
    final HintContentBuilder? builder = widget.contentBuilder;
    final Widget content = builder != null
        ? builder(context)
        : HintBubbleContent(
            theme: theme,
            title: widget.title,
            message: widget.message,
          );
    return _asLiveRegion(
      _withPointerBehaviour(content),
      isCustom: builder != null,
    );
  }

  /// Marks the bubble as a live region so a screen reader speaks it as it
  /// appears.
  ///
  /// This replaces a `SemanticsService.announce` call: the bubble *is* the
  /// announcement, so it is both spoken on arrival and still there to be read
  /// afterwards, where a fire-and-forget announcement was gone the moment it
  /// was missed. `announce` is also deprecated on Android
  /// (flutter/flutter#165510).
  ///
  /// The label sits on this node rather than on the text inside it because
  /// Android only announces a live region whose own label changed — a live
  /// region labelled only by its children is silently skipped.
  Widget _asLiveRegion(Widget content, {required bool isCustom}) {
    final String? label = _bubbleSemanticsLabel;
    if (label == null) {
      return content;
    }
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      // The default bubble is text this label already repeats word for word,
      // so it is excluded and the bubble reads as one node. Custom content can
      // hold buttons, which have to keep their own semantics — and their own
      // nodes: without explicitChildNodes a child's label, and its button
      // flag, would be merged into this one node instead.
      excludeSemantics: !isCustom,
      explicitChildNodes: true,
      child: content,
    );
  }

  /// Applies [Hint.interactive] to the built content.
  Widget _withPointerBehaviour(Widget content) {
    if (!widget.interactive) {
      // A non-interactive bubble must never eat a pointer: it is decoration.
      return IgnorePointer(child: content);
    }
    return MouseRegion(
      onEnter: (PointerEnterEvent _) {
        _pointerInBubble = true;
        _exitTimer?.cancel();
      },
      onExit: (PointerExitEvent _) {
        _pointerInBubble = false;
        if (_wantsHover) {
          _scheduleHoverExit();
        }
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (widget.absorbChildInput) {
      // A transparent layer above the child, for children that do not
      // hit-test at all.
      child = Stack(
        children: <Widget>[
          child,
          const Positioned.fill(
            child: Listener(behavior: HitTestBehavior.opaque),
          ),
        ],
      );
    }

    if (_wantsFocus) {
      child = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _onFocusChange,
        child: child,
      );
    }

    // MouseRegion first so hover is seen even when the child consumes hover
    // itself, then Listener for the raw pointer stream.
    child = MouseRegion(
      opaque: false,
      cursor: widget.mouseCursor ?? MouseCursor.defer,
      onEnter: _onEnter,
      onExit: _onExit,
      onHover: widget.followPointer ? _onHover : null,
      child: child,
    );

    child = Listener(
      // Translucent, so the listener is hit whether or not the child is: a
      // disabled button still yields a hint, and an enabled one still gets its
      // own tap.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: child,
    );

    child = CompositedTransformTarget(link: _link, child: child);

    if (!widget.excludeFromSemantics) {
      final String? label =
          widget.semanticsLabel ?? widget.message ?? widget.title;
      if (label != null) {
        child = Semantics(tooltip: label, child: child);
      }
    }

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: child,
    );
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _showTimer?.cancel();
    _longPressTimer?.cancel();
    _exitTimer?.cancel();
    _removeKeyHandler();
    removeShowOnceResetListener(_onShowOnceReset);
    HintRegistry.instance.close(this);
    _detachController(widget.controller);
    _tracker.dispose();
    _animation.dispose();
    _pointer.dispose();
    super.dispose();
  }
}
