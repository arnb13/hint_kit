import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/hint_side.dart';
import '../core/hint_trigger.dart';
import '../theme/hint_theme.dart';
import '../tooltip/hint.dart';
import '../tooltip/hint_controller.dart';

/// A pulsing dot that draws the eye, and opens a hint when tapped.
///
/// The quiet alternative to a tour: leave one next to a feature people keep
/// missing, and let them find it in their own time.
///
/// ```dart
/// Beacon(
///   message: 'Long-press a shift to duplicate it',
///   child: const Icon(Icons.calendar_month),
/// )
/// ```
///
/// With no [child] the beacon is just the dot, which is what you want when it
/// sits in a [Stack] over something else. With a child, the dot is positioned
/// at [alignment] over it.
///
/// The pulse stops under [MediaQueryData.disableAnimations], and the dot
/// carries a semantic label so it is not an invisible affordance to a screen
/// reader.
///
/// ## Testing
///
/// A pulsing beacon always has a frame scheduled, so `tester.pumpAndSettle()`
/// on a page containing one never returns. Either pass `autoStart: false` in
/// widget tests, or pump a fixed number of frames:
///
/// ```dart
/// await tester.pump(const Duration(milliseconds: 300));
/// ```
///
/// {@category Hints}
class Beacon extends StatefulWidget {
  /// Creates a beacon.
  ///
  /// Supply [message]/[title] or [contentBuilder] for the hint it opens.
  const Beacon({
    this.message,
    this.title,
    this.contentBuilder,
    this.child,
    this.color,
    this.size = 10,
    this.alignment = Alignment.topRight,
    this.period = const Duration(milliseconds: 1800),
    this.autoStart = true,
    this.pulseCount,
    this.direction = HintDirection.auto,
    this.theme,
    this.interactive = false,
    this.semanticsLabel = 'More information',
    this.onShow,
    this.onDismiss,
    super.key,
  })  : assert(
          message != null || title != null || contentBuilder != null,
          'A Beacon needs a message, a title or a contentBuilder to show.',
        ),
        assert(size > 0, 'size must be positive.');

  /// Body text of the hint the beacon opens.
  final String? message;

  /// Title of the hint the beacon opens.
  final String? title;

  /// Rich content for the hint the beacon opens.
  final HintContentBuilder? contentBuilder;

  /// The widget the dot is placed over.
  ///
  /// When null the beacon is only the dot and takes up [size] square.
  final Widget? child;

  /// The dot's colour. Defaults to the theme's background colour, which is the
  /// same colour the bubble it opens will be.
  final Color? color;

  /// Diameter of the solid dot. The ring grows to twice this.
  final double size;

  /// Where the dot sits over [child].
  final AlignmentGeometry alignment;

  /// How long one pulse takes.
  final Duration period;

  /// Whether the pulse runs on its own.
  ///
  /// Turn it off to draw a static dot — for a list where a dozen animating
  /// beacons would be a distraction rather than a hint.
  final bool autoStart;

  /// How many times to pulse before settling into a static dot.
  ///
  /// Null — the default — pulses forever. A finite count is usually the
  /// better UX: it catches the eye when the screen appears and then stops
  /// competing with everything else on it.
  ///
  /// It also makes the beacon testable: a forever-pulsing beacon always has a
  /// frame scheduled, so `pumpAndSettle` never returns while one is on screen.
  final int? pulseCount;

  /// Which side the hint prefers.
  final HintDirection direction;

  /// Visual overrides for the hint and the dot.
  final HintThemeData? theme;

  /// Whether the hint's bubble may contain interactive content.
  final bool interactive;

  /// Screen-reader label for the dot.
  final String semanticsLabel;

  /// Called when the hint opens.
  final VoidCallback? onShow;

  /// Called when the hint closes.
  final VoidCallback? onDismiss;

  @override
  State<Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<Beacon> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  final HintController _hint = HintController();

  /// Pulses still to run, or null for "forever".
  int? _pulsesLeft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(Beacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _pulse.duration = widget.period;
    }
    if (oldWidget.autoStart != widget.autoStart) {
      _syncPulse();
    }
  }

  /// Runs or stops the pulse to match the widget and the accessibility
  /// settings.
  void _syncPulse() {
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.autoStart && !reduceMotion) {
      if (!_pulse.isAnimating) {
        _pulsesLeft = widget.pulseCount;
        _runPulse();
      }
    } else {
      _pulsesLeft = null;
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  /// Runs one pulse, or repeats forever when there is no count.
  ///
  /// A counted pulse is driven one cycle at a time rather than with
  /// `repeat(count:)`, which needs a newer Flutter than this package's floor.
  void _runPulse() {
    final int? left = _pulsesLeft;
    if (left == null) {
      unawaited(_pulse.repeat());
      return;
    }
    if (left <= 0) {
      _pulse.value = 0;
      return;
    }
    _pulsesLeft = left - 1;
    unawaited(
      _pulse.forward(from: 0).then((_) {
        if (mounted) {
          _runPulse();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ResolvedHintTheme theme =
        HintThemeData.resolve(context, widget.theme);
    final Color color = widget.color ?? theme.backgroundColor;

    final Widget dot = Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: Hint(
        message: widget.message,
        title: widget.title,
        contentBuilder: widget.contentBuilder,
        controller: _hint,
        triggers: const <HintTrigger>{HintTrigger.tap, HintTrigger.manual},
        direction: widget.direction,
        theme: widget.theme,
        interactive: widget.interactive,
        excludeFromSemantics: true,
        onShow: widget.onShow,
        onDismiss: widget.onDismiss,
        child: SizedBox.square(
          // The tappable area is the ring, not the dot: a 10px target is below
          // every platform's minimum.
          dimension: widget.size * 2,
          child: Center(
            child: CustomPaint(
              painter: _BeaconPainter(
                animation: _pulse,
                color: color,
                dotRadius: widget.size / 2,
              ),
              size: Size.square(widget.size * 2),
            ),
          ),
        ),
      ),
    );

    final Widget? child = widget.child;
    if (child == null) {
      return dot;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: Align(alignment: widget.alignment, child: dot),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _hint.dispose();
    super.dispose();
  }
}

/// Paints the solid dot and the ring expanding out of it.
class _BeaconPainter extends CustomPainter {
  _BeaconPainter({
    required this.animation,
    required this.color,
    required this.dotRadius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double t = animation.value;
    if (t > 0) {
      // The ring starts at the dot and fades as it grows, so the eye is drawn
      // outwards rather than to a blinking spot.
      canvas.drawCircle(
        centre,
        dotRadius + (size.shortestSide / 2 - dotRadius) * t,
        Paint()..color = color.withAlpha((255 * 0.35 * (1 - t)).round()),
      );
    }
    canvas.drawCircle(centre, dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BeaconPainter old) =>
      old.color != color ||
      old.dotRadius != dotRadius ||
      old.animation != animation;

  /// The dot is decorative; the [Hint] around it takes the pointer.
  @override
  bool hitTest(Offset position) => false;
}
