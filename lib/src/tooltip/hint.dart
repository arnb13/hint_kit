import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/hint_side.dart';
import '../core/hint_trigger.dart';
import '../core/rect_tracker.dart';
import '../theme/hint_theme.dart';
import 'anchored_bubble.dart';
import 'hint_bubble.dart';
import 'hint_controller.dart';
import 'hint_registry.dart';

/// Signature for building rich hint content.
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
    this.onShow,
    this.onDismiss,
    super.key,
  })  : assert(
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

  /// Overrides the semantic tooltip announced for the target.
  ///
  /// Defaults to [message]. Ignored when [excludeFromSemantics] is true.
  final String? semanticsLabel;

  /// Whether to skip adding a semantic tooltip to the target.
  ///
  /// Set this when the child already carries the same information — otherwise
  /// a screen reader reads it twice.
  final bool excludeFromSemantics;

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
  bool _pointerInTarget = false;
  bool _pointerInBubble = false;
  bool _isShown = false;
  bool _keyHandlerInstalled = false;

  /// Whether the bubble is open, i.e. showing or animating in.
  bool get isShown => _isShown;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    if (widget.triggers.contains(HintTrigger.onAppear)) {
      // The target has not been laid out yet; showing now would measure an
      // empty rect.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          show();
        }
      });
    }
  }

  @override
  void didUpdateWidget(Hint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
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
  void show() {
    if (!mounted || _isShown) {
      return;
    }
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
    _announce();
    setState(() {});
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

  void _announce() {
    if (widget.excludeFromSemantics) {
      return;
    }
    final String? text =
        widget.semanticsLabel ?? widget.message ?? widget.title;
    if (text == null || text.isEmpty) {
      return;
    }
    // Rich content has no text to announce automatically; a caller that wants
    // one passes semanticsLabel.
    //
    // `sendAnnouncement` supersedes this, but only from Flutter 3.35. The
    // package supports 3.24, so the deprecated call stays until the floor
    // moves.
    // ignore: deprecated_member_use
    SemanticsService.announce(text, Directionality.of(context));
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

  bool get _wantsLongPress => widget.triggers.contains(HintTrigger.longPress);

  bool get _wantsHover => widget.triggers.contains(HintTrigger.hover);

  bool get _wantsFocus => widget.triggers.contains(HintTrigger.focus);

  void _onPointerDown(PointerDownEvent event) {
    if (!_wantsTap && !_wantsLongPress) {
      return;
    }
    _pointerDownPosition = event.position;
    _pointerDownId = event.pointer;
    _pointerMoved = false;
    if (_wantsLongPress) {
      // Recognised by hand rather than with a LongPressGestureDetector: a
      // gesture recogniser would join the arena and could beat the child's own
      // long press, which would break an enabled child.
      _longPressTimer = Timer(kLongPressTimeout, () {
        if (!_pointerMoved && _pointerDownId == event.pointer) {
          _toggleFromTrigger();
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
    if (isTap && _wantsTap) {
      _toggleFromTrigger();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _pointerDownPosition = null;
    _pointerDownId = null;
    _pointerMoved = false;
  }

  /// Opens on a trigger, or closes if this hint is already the open one.
  void _toggleFromTrigger() {
    if (_isShown) {
      hide();
    } else {
      show();
    }
  }

  void _onEnter(PointerEnterEvent event) {
    _pointerInTarget = true;
    _exitTimer?.cancel();
    if (!_wantsHover || _isShown) {
      return;
    }
    if (widget.waitDuration == Duration.zero) {
      show();
      return;
    }
    _cancelWait();
    _waitTimer = Timer(widget.waitDuration, () {
      if (_pointerInTarget) {
        show();
      }
    });
  }

  void _onExit(PointerExitEvent event) {
    _pointerInTarget = false;
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
      show();
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
      listenable: _tracker,
      builder: (BuildContext context, Widget? _) => _buildBubble(context),
    );
  }

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
          targetRect: target,
          overlaySize: _overlaySize(),
          margin: _margin(theme),
          direction: widget.direction,
          theme: theme,
          animation: _animation,
          link: _link,
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
      onEnter: _onEnter,
      onExit: _onExit,
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
    HintRegistry.instance.close(this);
    _detachController(widget.controller);
    _tracker.dispose();
    _animation.dispose();
    super.dispose();
  }
}
