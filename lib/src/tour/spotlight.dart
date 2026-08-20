import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The shape of the hole a spotlight cuts in the scrim.
///
/// Construct one of the four constants, or [SpotlightShape.custom] for
/// anything else.
class SpotlightShape {
  const SpotlightShape._(this._kind, [this._builder]);

  /// A spotlight whose hole is built by [builder] from the padded target rect.
  ///
  /// The returned path is in the same coordinate space as the rect it is given
  /// — overlay coordinates — and must be closed.
  ///
  /// ```dart
  /// SpotlightShape.custom((Rect r) => Path()
  ///   ..moveTo(r.center.dx, r.top)
  ///   ..lineTo(r.right, r.bottom)
  ///   ..lineTo(r.left, r.bottom)
  ///   ..close());
  /// ```
  const SpotlightShape.custom(Path Function(Rect rect) builder)
      : this._(_SpotlightKind.custom, builder);

  final _SpotlightKind _kind;
  final Path Function(Rect rect)? _builder;

  /// A sharp-cornered rectangle around the target.
  static const SpotlightShape rect = SpotlightShape._(_SpotlightKind.rect);

  /// A rectangle with the theme's spotlight corner radius.
  static const SpotlightShape roundedRect =
      SpotlightShape._(_SpotlightKind.roundedRect);

  /// A circle that encloses the padded target rect.
  ///
  /// The radius comes from the rect's longest side, so a wide target gets a
  /// circle that contains it rather than one that crops it.
  static const SpotlightShape circle = SpotlightShape._(_SpotlightKind.circle);

  /// An ellipse inscribed in the padded target rect.
  static const SpotlightShape oval = SpotlightShape._(_SpotlightKind.oval);

  /// Builds the hole path for [rect], using [radius] where relevant.
  Path toPath(Rect rect, BorderRadius radius) {
    switch (_kind) {
      case _SpotlightKind.rect:
        return Path()..addRect(rect);
      case _SpotlightKind.roundedRect:
        return Path()..addRRect(radius.toRRect(rect));
      case _SpotlightKind.circle:
        return Path()
          ..addOval(
            Rect.fromCircle(
              center: rect.center,
              radius: rect.longestSide / 2,
            ),
          );
      case _SpotlightKind.oval:
        return Path()..addOval(rect);
      case _SpotlightKind.custom:
        final Path path = _builder!(rect);
        assert(
          path.getBounds().isFinite,
          'SpotlightShape.custom produced a non-finite path for $rect.',
        );
        return path;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotlightShape &&
          other._kind == _kind &&
          other._builder == _builder;

  @override
  int get hashCode => Object.hash(_kind, _builder);
}

enum _SpotlightKind { rect, roundedRect, circle, oval, custom }

/// A full-screen scrim with a hole cut out of it, sized to a target.
///
/// The scrim is a single path — `screen difference hole` — so there is one
/// draw call and no seam, and the hole is genuinely transparent rather than
/// four rectangles arranged around a gap.
///
/// Pointer behaviour is a real hit-test decision, not an approximation. In
/// [passthrough] mode the render object reports `hitTestSelf` false for
/// positions inside the hole, so the widget underneath — the actual target —
/// receives the pointer, and everything else is blocked.
class Spotlight extends StatelessWidget {
  /// Creates a scrim with a hole around [holeRect].
  const Spotlight({
    required this.holeRect,
    required this.shape,
    required this.borderRadius,
    required this.color,
    this.blur = 0,
    this.passthrough = false,
    this.pulse,
    this.onTapOutside,
    super.key,
  });

  /// The hole, in the coordinate space of this widget, padding already added.
  ///
  /// Passing [Rect.zero] paints an undisturbed scrim, which is what a step
  /// whose target is not currently on screen should do.
  final Rect holeRect;

  /// The shape of the hole.
  final SpotlightShape shape;

  /// Corner radius for [SpotlightShape.roundedRect].
  final BorderRadius borderRadius;

  /// The scrim colour.
  final Color color;

  /// Gaussian blur sigma applied to everything behind the scrim.
  ///
  /// `0` skips the [BackdropFilter] entirely, which is much cheaper — a blur
  /// forces a saveLayer for the whole screen every frame.
  final double blur;

  /// Whether pointers inside the hole reach the widget beneath.
  ///
  /// With this off the scrim is fully modal: the tour advances only through
  /// its own buttons and keyboard shortcuts.
  final bool passthrough;

  /// Drives an expanding ring around the hole, if any.
  ///
  /// Supply a repeating animation; `null` disables the pulse.
  final Animation<double>? pulse;

  /// Called when a pointer goes down on the scrim, outside the hole.
  final VoidCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    Widget scrim = _SpotlightHitTestBlocker(
      holeRect: holeRect,
      shape: shape,
      borderRadius: borderRadius,
      passthrough: passthrough,
      child: CustomPaint(
        painter: _ScrimPainter(
          holeRect: holeRect,
          shape: shape,
          borderRadius: borderRadius,
          color: color,
          pulse: pulse,
        ),
        child: const SizedBox.expand(),
      ),
    );

    if (onTapOutside != null) {
      scrim = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent event) {
          if (!_holeContains(event.localPosition)) {
            onTapOutside?.call();
          }
        },
        child: scrim,
      );
    }

    if (blur > 0) {
      // The filter has to be clipped to the scrim path, or the target would be
      // blurred too — which defeats the point of spotlighting it.
      scrim = ClipPath(
        clipper: _ScrimClipper(
          holeRect: holeRect,
          shape: shape,
          borderRadius: borderRadius,
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: scrim,
        ),
      );
    }
    return scrim;
  }

  bool _holeContains(Offset position) =>
      !holeRect.isEmpty &&
      shape.toPath(holeRect, borderRadius).contains(position);
}

/// Paints the scrim and the optional pulse ring.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({
    required this.holeRect,
    required this.shape,
    required this.borderRadius,
    required this.color,
    required this.pulse,
  }) : super(repaint: pulse);

  final Rect holeRect;
  final SpotlightShape shape;
  final BorderRadius borderRadius;
  final Color color;
  final Animation<double>? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect screen = Offset.zero & size;
    if (holeRect.isEmpty) {
      canvas.drawRect(screen, Paint()..color = color);
      return;
    }
    final Path hole = shape.toPath(holeRect, borderRadius);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(screen),
        hole,
      ),
      Paint()..color = color,
    );

    final Animation<double>? pulseAnimation = pulse;
    if (pulseAnimation != null) {
      final double t = pulseAnimation.value;
      // One ring, expanding and fading: an attention cue, not a light show.
      final double grow = 1 + t * 0.35;
      final Rect ring = Rect.fromCenter(
        center: holeRect.center,
        width: holeRect.width * grow,
        height: holeRect.height * grow,
      );
      canvas.drawPath(
        shape.toPath(ring, borderRadius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          // withAlpha rather than withValues: the latter needs Flutter 3.27,
          // and the package supports 3.24.
          ..color = color.withAlpha((255 * (1 - t) * 0.6).round()),
      );
    }
  }

  /// The scrim never claims a pointer itself.
  ///
  /// [RenderCustomPaint.hitTestSelf] treats a painter that returns null as a
  /// hit, which would make the CustomPaint swallow every pointer and defeat
  /// [RenderSpotlightBlocker] — the object that is supposed to decide.
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.holeRect != holeRect ||
      old.shape != shape ||
      old.borderRadius != borderRadius ||
      old.color != color ||
      old.pulse != pulse;
}

/// Clips a [BackdropFilter] to everything except the hole.
class _ScrimClipper extends CustomClipper<Path> {
  _ScrimClipper({
    required this.holeRect,
    required this.shape,
    required this.borderRadius,
  });

  final Rect holeRect;
  final SpotlightShape shape;
  final BorderRadius borderRadius;

  @override
  Path getClip(Size size) {
    final Path screen = Path()..addRect(Offset.zero & size);
    if (holeRect.isEmpty) {
      return screen;
    }
    return Path.combine(
      PathOperation.difference,
      screen,
      shape.toPath(holeRect, borderRadius),
    );
  }

  @override
  bool shouldReclip(_ScrimClipper old) =>
      old.holeRect != holeRect ||
      old.shape != shape ||
      old.borderRadius != borderRadius;
}

/// Decides, per pointer, whether the scrim swallows the event.
class _SpotlightHitTestBlocker extends SingleChildRenderObjectWidget {
  const _SpotlightHitTestBlocker({
    required this.holeRect,
    required this.shape,
    required this.borderRadius,
    required this.passthrough,
    required Widget super.child,
  });

  final Rect holeRect;
  final SpotlightShape shape;
  final BorderRadius borderRadius;
  final bool passthrough;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSpotlightBlocker(
        holeRect: holeRect,
        shape: shape,
        borderRadius: borderRadius,
        passthrough: passthrough,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSpotlightBlocker renderObject,
  ) {
    renderObject
      ..holeRect = holeRect
      ..shape = shape
      ..borderRadius = borderRadius
      ..passthrough = passthrough;
  }
}

/// The render object behind a [Spotlight]'s pointer behaviour.
///
/// This is the honest implementation of passthrough: [hitTestSelf] returns
/// false for a position inside the hole, so the hit test walks past the scrim
/// to whatever is underneath — the real target, with its real gesture
/// recognisers. Nothing is simulated and nothing is repositioned.
class RenderSpotlightBlocker extends RenderProxyBox {
  /// Creates a blocker for the given hole.
  RenderSpotlightBlocker({
    required Rect holeRect,
    required SpotlightShape shape,
    required BorderRadius borderRadius,
    required bool passthrough,
  })  : _holeRect = holeRect,
        _shape = shape,
        _borderRadius = borderRadius,
        _passthrough = passthrough;

  Rect _holeRect;
  SpotlightShape _shape;
  BorderRadius _borderRadius;
  bool _passthrough;
  Path? _cachedPath;

  /// The hole, in this render object's local coordinates.
  Rect get holeRect => _holeRect;
  set holeRect(Rect value) {
    if (_holeRect == value) {
      return;
    }
    _holeRect = value;
    _cachedPath = null;
  }

  /// The hole's shape.
  SpotlightShape get shape => _shape;
  set shape(SpotlightShape value) {
    if (_shape == value) {
      return;
    }
    _shape = value;
    _cachedPath = null;
  }

  /// The corner radius used by [SpotlightShape.roundedRect].
  BorderRadius get borderRadius => _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) {
      return;
    }
    _borderRadius = value;
    _cachedPath = null;
  }

  /// Whether pointers inside the hole fall through to the widget below.
  bool get passthrough => _passthrough;
  set passthrough(bool value) {
    if (_passthrough == value) {
      return;
    }
    _passthrough = value;
  }

  /// The hole path, rebuilt only when its inputs change.
  ///
  /// A hit test can run several times per frame; rebuilding a path each time
  /// would be wasteful for a shape that almost never changes.
  Path get _holePath => _cachedPath ??= _shape.toPath(_holeRect, _borderRadius);

  @override
  bool hitTestSelf(Offset position) {
    if (!_passthrough || _holeRect.isEmpty) {
      // Modal: the scrim owns every pointer on screen.
      return true;
    }
    return !_holePath.contains(position);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Rect>('holeRect', _holeRect))
      ..add(FlagProperty('passthrough', value: _passthrough, ifTrue: 'passes'));
  }
}
