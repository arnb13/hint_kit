/// @docImport '../tooltip/hint.dart';
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/hint_side.dart';
import '../core/rect_tracker.dart';
import '../theme/hint_theme.dart';
import '../tooltip/anchored_bubble.dart';
import '../tooltip/hint_registry.dart';
import 'spotlight.dart';
import 'tour_controller.dart';
import 'tour_scope.dart';

/// Signature for building a custom tour step card.
typedef TourStepBuilder = Widget Function(
  BuildContext context,
  TourStepInfo info,
);

/// Everything a custom step card needs to render itself and drive the tour.
class TourStepInfo {
  /// Creates the info handed to a [TourStepBuilder].
  const TourStepInfo({
    required this.tour,
    required this.index,
    required this.length,
    required this.title,
    required this.description,
    required this.controller,
    required this.side,
  });

  /// The running tour's name.
  final String tour;

  /// The zero-based index of this step.
  final int index;

  /// How many steps the tour has.
  final int length;

  /// This step's title, if any.
  final String? title;

  /// This step's body text, if any.
  final String? description;

  /// The controller, for Back/Next/Skip buttons.
  final TourController controller;

  /// Which side of the target the card was placed on.
  final HintSide side;

  /// The human-facing step number, one-based.
  int get step => index + 1;

  /// Whether this is the first step.
  bool get isFirst => index <= 0;

  /// Whether this is the last step.
  bool get isLast => index >= length - 1;
}

/// Marks [child] as a step of a guided tour.
///
/// Register one per step, anywhere below a [TourScope]. Steps are ordered by
/// [order], not by tree position, so a step on another route slots into the
/// right place:
///
/// ```dart
/// HintTarget(
///   tour: 'onboarding',
///   order: 1,
///   title: 'Check in here',
///   description: 'Tap this once you arrive at the centre.',
///   spotlight: SpotlightShape.circle,
///   passthrough: true,
///   child: checkInButton,
/// )
/// ```
///
/// A step whose target is not mounted — a different route, a lazy list item
/// that has scrolled away — waits for it. The tour does not skip the step and
/// does not crash; nothing is drawn until the target registers, so pushing the
/// right route resumes the tour where it left off.
///
/// The step card is the same bubble a [Hint] uses, placed by the same
/// resolver, over a scrim drawn by [Spotlight].
class HintTarget extends StatefulWidget {
  /// Creates a tour step around [child].
  const HintTarget({
    required this.tour,
    required this.order,
    required this.child,
    this.title,
    this.description,
    this.contentBuilder,
    this.spotlight = SpotlightShape.roundedRect,
    this.spotlightPadding,
    this.direction = HintDirection.auto,
    this.passthrough = false,
    this.pulse = false,
    this.theme,
    this.showArrow = false,
    this.dismissOnTapOutside = false,
    this.scrollAlignment = 0.5,
    super.key,
  }) : assert(order >= 0, 'order must be non-negative.');

  /// The tour this step belongs to.
  final String tour;

  /// This step's position within the tour.
  ///
  /// Steps run in ascending order. Gaps are fine — numbering steps 10, 20, 30
  /// leaves room to insert one later without renumbering.
  final int order;

  /// The widget to spotlight.
  final Widget child;

  /// Heading of the step card.
  final String? title;

  /// Body text of the step card.
  final String? description;

  /// Replaces the default step card entirely.
  ///
  /// The builder gets a [TourStepInfo] with the controller, so custom cards
  /// can still drive the tour.
  final TourStepBuilder? contentBuilder;

  /// The shape of the hole cut around the target.
  final SpotlightShape spotlight;

  /// Padding added around the target before the hole is cut.
  ///
  /// Defaults to the theme's `spotlightPadding`.
  final EdgeInsets? spotlightPadding;

  /// Which side of the target the card prefers.
  final HintDirection direction;

  /// Whether a real tap on the target passes through the scrim.
  ///
  /// With this on, the step is a "do the thing" instruction: the user must
  /// actually press the button, and the tour advances when your own code says
  /// so — call `Tour.read(context).next()` from the button's callback. With it
  /// off the scrim is modal and only the card's buttons advance the tour.
  final bool passthrough;

  /// Whether to draw a pulsing ring around the spotlight.
  final bool pulse;

  /// Per-step visual overrides, merged over the scope's and the app's themes.
  final HintThemeData? theme;

  /// Whether the card draws a caret pointing at the target.
  ///
  /// Off by default: the spotlight already says what the card is about, and a
  /// caret on a large card tends to look like a mistake.
  final bool showArrow;

  /// Whether a tap on the scrim skips the tour.
  ///
  /// Off by default, so a stray tap cannot lose an onboarding flow.
  final bool dismissOnTapOutside;

  /// Where in the viewport to bring the target when scrolling to it.
  ///
  /// `0.0` is the leading edge, `0.5` the middle, `1.0` the trailing edge.
  final double scrollAlignment;

  @override
  State<HintTarget> createState() => _HintTargetState();
}

class _HintTargetState extends State<HintTarget>
    with TickerProviderStateMixin
    implements DismissibleHint {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'HintTarget',
  );
  final LayerLink _link = LayerLink();
  // Tour steps track every frame: they are modal and short-lived, so the cost
  // is irrelevant and the spotlight stays glued through scroll animations.
  final HintRectTracker _tracker = HintRectTracker(
    mode: RectTrackingMode.perFrame,
  );
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  TourScopeState? _scope;
  bool _isActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TourScopeState scope = TourScope.of(context);
    if (identical(scope, _scope)) {
      return;
    }
    _scope?.deregisterTarget(widget.tour, widget.order);
    _scope = scope;
    scope.registerTarget(widget.tour, widget.order, _onTourChanged);
  }

  @override
  void didUpdateWidget(HintTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tour != widget.tour || oldWidget.order != widget.order) {
      _scope?.deregisterTarget(oldWidget.tour, oldWidget.order);
      _scope?.registerTarget(widget.tour, widget.order, _onTourChanged);
    }
  }

  /// Called by the scope whenever the active step may have changed.
  void _onTourChanged() {
    final TourScopeState? scope = _scope;
    if (scope == null || !mounted) {
      return;
    }
    final bool active = scope.isActiveStep(widget.tour, widget.order);
    if (active == _isActive) {
      return;
    }
    if (active) {
      _activate();
    } else {
      _deactivate();
    }
  }

  void _activate() {
    _isActive = true;
    // A tour takes the floor: any tooltip left open would sit on top of the
    // scrim looking like part of the step.
    HintRegistry.instance.closeAll();
    _portal.show();
    _tracker.start(
      targetContext: context,
      overlayContext: Overlay.of(context, debugRequiredFor: widget).context,
    );
    if (_reduceMotion) {
      _animation.value = 1;
    } else {
      unawaited(_animation.forward());
      if (widget.pulse) {
        unawaited(_pulse.repeat());
      }
    }
    unawaited(_scrollIntoView());
    setState(() {});
  }

  void _deactivate() {
    _isActive = false;
    _pulse.stop();
    if (_reduceMotion) {
      _animation.value = 0;
      _finishHide();
    } else {
      _animation.reverse().whenComplete(() {
        if (!_isActive) {
          _finishHide();
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _finishHide() {
    if (!mounted || _isActive) {
      return;
    }
    _portal.hide();
    _tracker.stop();
  }

  @override
  void dismissForExclusivity() {
    // A tour step outranks a tooltip; it is never the one asked to leave.
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Brings the target into view before the user has to look for it.
  ///
  /// The rect tracker measures every frame, so the spotlight follows the
  /// scroll animation rather than waiting for it to settle and jumping.
  Future<void> _scrollIntoView() async {
    if (!mounted || Scrollable.maybeOf(context) == null) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      alignment: widget.scrollAlignment,
      duration:
          _reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
    if (mounted && _isActive) {
      _tracker.refresh();
    }
  }

  ResolvedHintTheme _resolveTheme() {
    final HintThemeData? scopeTheme = _scope?.theme;
    final HintThemeData? own = widget.theme;
    final HintThemeData? merged = scopeTheme == null
        ? own
        : (own == null ? scopeTheme : scopeTheme.merge(own));
    return HintThemeData.resolve(context, merged);
  }

  EdgeInsets _margin(ResolvedHintTheme theme) {
    final EdgeInsets padding =
        MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final EdgeInsets margin = theme.screenMargin;
    double biggest(double a, double b) => a > b ? a : b;
    return EdgeInsets.fromLTRB(
      biggest(margin.left, padding.left),
      biggest(margin.top, padding.top),
      biggest(margin.right, padding.right),
      biggest(margin.bottom, padding.bottom),
    );
  }

  Size _overlaySize() {
    final RenderObject? box = Overlay.of(
      context,
      debugRequiredFor: widget,
    ).context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.size;
    }
    return MediaQuery.sizeOf(context);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    return ListenableBuilder(
      listenable: _tracker,
      builder: (BuildContext context, Widget? _) => _buildStep(context),
    );
  }

  Widget _buildStep(BuildContext overlayContext) {
    final TourScopeState? scope = _scope;
    if (scope == null) {
      return const SizedBox.shrink();
    }
    final ResolvedHintTheme theme = _resolveTheme();
    final Rect? target = _tracker.value;
    final EdgeInsets padding =
        widget.spotlightPadding ?? theme.spotlightPadding;
    final Rect hole = target == null ? Rect.zero : padding.inflateRect(target);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: FadeTransition(
            opacity: _animation,
            child: Spotlight(
              holeRect: hole,
              shape: widget.spotlight,
              borderRadius: theme.spotlightBorderRadius,
              color: theme.scrimColor,
              blur: theme.scrimBlur,
              passthrough: widget.passthrough,
              pulse: widget.pulse && !_reduceMotion ? _pulse : null,
              onTapOutside:
                  widget.dismissOnTapOutside ? scope.controller.skip : null,
            ),
          ),
        ),
        if (target != null)
          AnchoredHintBubble(
            targetRect: target,
            overlaySize: _overlaySize(),
            margin: _margin(theme),
            direction: widget.direction,
            theme: theme,
            animation: _animation,
            link: _link,
            showArrow: widget.showArrow,
            builder: (BuildContext context) => _buildCard(context, theme),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, ResolvedHintTheme theme) {
    final TourScopeState scope = _scope!;
    final TourController controller = scope.controller;
    final TourStepInfo info = TourStepInfo(
      tour: widget.tour,
      index: controller.index,
      length: controller.length,
      title: widget.title,
      description: widget.description,
      controller: controller,
      side: HintSide.bottom,
    );
    final TourStepBuilder? builder = widget.contentBuilder;
    // A nested focus scope traps Tab inside the card while the step is up, so
    // focus cannot wander into the dimmed UI behind the scrim. Tearing the
    // scope down hands focus back to the enclosing scope's previously focused
    // child, which is the restore half — done by the framework rather than by
    // stashing a FocusNode and hoping it is still mounted later.
    return FocusScope(
      autofocus: true,
      child: FocusTraversalGroup(
        child: builder != null
            ? builder(context, info)
            : TourStepCard(info: info, theme: theme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }

  @override
  void dispose() {
    _scope?.deregisterTarget(widget.tour, widget.order);
    _tracker.dispose();
    _animation.dispose();
    _pulse.dispose();
    super.dispose();
  }
}

/// The default tour step card: title, body, progress and controls.
///
/// Replace it per step with [HintTarget.contentBuilder]. It is exported so a
/// custom card can reuse the pieces — or wrap this one and add to it.
class TourStepCard extends StatelessWidget {
  /// Creates the default step card.
  const TourStepCard({
    required this.info,
    required this.theme,
    super.key,
  });

  /// The step being rendered.
  final TourStepInfo info;

  /// Resolved visual configuration.
  final ResolvedHintTheme theme;

  @override
  Widget build(BuildContext context) {
    final String? title = info.title;
    final String? description = info.description;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(title, style: theme.titleStyle),
          const SizedBox(height: 4),
        ],
        if (description != null) Text(description, style: theme.messageStyle),
        const SizedBox(height: 12),
        // A Wrap, not a Row: at a large text scale, or in a narrow bubble,
        // three buttons and a progress label do not fit on one line, and a
        // step card that overflows is worse than one that is two lines tall.
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (info.length > 1)
              Text('${info.step} of ${info.length}', style: theme.messageStyle),
            if (!info.isLast)
              _TourButton(
                label: 'Skip',
                onPressed: info.controller.skip,
                theme: theme,
              ),
            if (!info.isFirst)
              _TourButton(
                label: 'Back',
                onPressed: info.controller.previous,
                theme: theme,
              ),
            _TourButton(
              label: info.isLast ? 'Done' : 'Next',
              onPressed: info.controller.next,
              theme: theme,
              emphasised: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// A text button styled from the hint theme.
///
/// Deliberately not a Material `TextButton`: the card is painted on the hint
/// background colour, which is usually the inverse surface, and Material's
/// button colours would be resolved against the *page* colour scheme and come
/// out invisible.
class _TourButton extends StatelessWidget {
  const _TourButton({
    required this.label,
    required this.onPressed,
    required this.theme,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onPressed;
  final ResolvedHintTheme theme;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Focus(
          child: Builder(
            builder: (BuildContext context) {
              final bool focused = Focus.of(context).hasFocus;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  color: emphasised
                      ? theme.foregroundColor.withAlpha(38)
                      : const Color(0x00000000),
                  border: Border.all(
                    color: theme.foregroundColor.withAlpha(focused ? 200 : 60),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.messageStyle.copyWith(
                    fontWeight:
                        emphasised ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
