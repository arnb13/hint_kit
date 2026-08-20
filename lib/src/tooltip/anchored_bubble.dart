import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/hint_side.dart';
import '../core/measure_size.dart';
import '../core/placement.dart';
import '../theme/hint_theme.dart';
import 'hint_bubble.dart';

/// Positions, animates and paints a hint bubble against a target rect.
///
/// This is the shared engine: a tooltip, a persistent hint and a tour step
/// card are all this widget with different content and different triggers.
/// There is exactly one implementation of "measure, resolve, place, animate"
/// in the package, so all three cannot drift apart.
///
/// The widget is meant to live inside an overlay, and [targetRect] must be in
/// that overlay's coordinate space.
///
/// ## How the first frame is hidden
///
/// Placement needs the bubble's size, which is only known after it has been
/// laid out. On the very first frame the bubble is therefore laid out at a
/// provisional position with the entry animation still at zero, i.e. fully
/// transparent. [MeasureSize] reports the real size, placement resolves, and
/// the animation starts. The provisional frame is never visible.
class AnchoredHintBubble extends StatefulWidget {
  /// Creates an anchored bubble.
  const AnchoredHintBubble({
    required this.targetRect,
    required this.overlaySize,
    required this.margin,
    required this.direction,
    required this.theme,
    required this.animation,
    required this.builder,
    this.link,
    this.showArrow = true,
    this.onPlacement,
    super.key,
  });

  /// The target's rect, in overlay coordinates.
  ///
  /// Used to decide the side, the shift and the arrow position. When [link] is
  /// supplied the compositor — not this rect — does the frame-to-frame
  /// following, so this only has to be fresh enough for those decisions.
  final Rect targetRect;

  /// The size of the overlay the bubble is placed in.
  final Size overlaySize;

  /// The smallest distance the bubble may come to the overlay edges.
  final EdgeInsets margin;

  /// The requested side. See [HintDirection].
  final HintDirection direction;

  /// Resolved visual configuration.
  final ResolvedHintTheme theme;

  /// Drives the entry and exit transition. `0` is hidden, `1` is shown.
  final Animation<double> animation;

  /// Builds the bubble's content.
  final WidgetBuilder builder;

  /// Links the bubble to a [CompositedTransformTarget] around the target
  /// widget.
  ///
  /// When set, the bubble tracks the target at the layer level: it follows
  /// through scrolling and animation with no per-frame Dart work at all. When
  /// null the bubble is positioned absolutely from [targetRect], which is what
  /// a tour step wants when its target lives on another route.
  final LayerLink? link;

  /// Whether to draw the caret. Tour step cards usually do not want one.
  final bool showArrow;

  /// Called whenever the resolved placement changes.
  ///
  /// A spotlight uses this to learn which side the card ended up on.
  final ValueChanged<HintPlacement>? onPlacement;

  @override
  State<AnchoredHintBubble> createState() => _AnchoredHintBubbleState();
}

class _AnchoredHintBubbleState extends State<AnchoredHintBubble> {
  Size? _bubbleSize;
  HintPlacement? _placement;

  void _onSizeChanged(Size size) {
    if (!mounted || _bubbleSize == size) {
      return;
    }
    setState(() => _bubbleSize = size);
  }

  /// Resolves placement for the current target and measured bubble size.
  HintPlacement? _resolve() {
    final Size? bubble = _bubbleSize;
    if (bubble == null || bubble.isEmpty) {
      return null;
    }
    if (widget.overlaySize.isEmpty) {
      return null;
    }
    final HintPlacement placement = resolvePlacement(
      target: widget.targetRect,
      overlay: widget.overlaySize,
      bubble: bubble,
      preferred: widget.direction,
      gap: widget.theme.gap,
      margin: widget.margin,
      arrowInset: widget.theme.arrowInset,
      textDirection: Directionality.of(context),
    );
    if (placement != _placement) {
      _placement = placement;
      final ValueChanged<HintPlacement>? callback = widget.onPlacement;
      if (callback != null) {
        // Placement is resolved during build; defer the notification so the
        // listener may safely rebuild.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            callback(placement);
          }
        });
      }
    }
    return placement;
  }

  /// Where the scale animation grows from: the arrow, when there is one.
  Alignment _transformOrigin(HintPlacement? placement) {
    if (placement == null) {
      return Alignment.center;
    }
    final double along = placement.arrowFraction * 2 - 1;
    return switch (placement.side) {
      HintSide.top => Alignment(along, 1),
      HintSide.bottom => Alignment(along, -1),
      HintSide.left => Alignment(1, along),
      HintSide.right => Alignment(-1, along),
    };
  }

  @override
  Widget build(BuildContext context) {
    final HintPlacement? placement = _resolve();
    final double maxWidth = _maxBubbleWidth();

    // A card with no caret is the same chrome with a zero-sized arrow, not a
    // second bubble implementation.
    final ResolvedHintTheme theme =
        widget.showArrow ? widget.theme : widget.theme.withoutArrow();

    Widget bubble = MeasureSize(
      onChange: _onSizeChanged,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: HintBubbleDecoration(
          side: placement?.side ?? HintSide.bottom,
          arrowFraction: placement?.arrowFraction ?? 0.5,
          theme: theme,
          child: Builder(builder: widget.builder),
        ),
      ),
    );

    // Fade plus a slight scale out of the anchored edge. The scale is small on
    // purpose: a bubble that pops is noise, a bubble that grows a few percent
    // reads as "this belongs to the thing you just touched".
    final Alignment origin = _transformOrigin(placement);
    bubble = FadeTransition(
      opacity: widget.animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(widget.animation),
        alignment: origin,
        child: bubble,
      ),
    );

    // Until the size is known the bubble must still be laid out, so it is
    // parked at the target's top-left with the animation at zero.
    final Offset offset = placement == null
        ? widget.targetRect.topLeft
        : placement.bubbleRect.topLeft;
    final LayerLink? link = widget.link;
    if (link == null) {
      return Positioned(left: offset.dx, top: offset.dy, child: bubble);
    }
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: offset - widget.targetRect.topLeft,
        child: bubble,
      ),
    );
  }

  /// The widest the bubble may be: the theme's cap, but never wider than the
  /// space between the margins.
  double _maxBubbleWidth() {
    final double available =
        widget.overlaySize.width - widget.margin.horizontal;
    if (available <= 0) {
      return widget.theme.maxWidth;
    }
    return widget.theme.maxWidth < available
        ? widget.theme.maxWidth
        : available;
  }
}
