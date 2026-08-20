import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Signature for [MeasureSize.onChange].
typedef SizeChangedCallback = void Function(Size size);

/// Reports the laid-out size of [child] to [onChange].
///
/// Placement needs the bubble's size, but a widget's size is only known after
/// layout. This reports it exactly once per change, from the layout phase,
/// which is one frame earlier than a post-frame callback would manage — and
/// that frame is the difference between a bubble that appears in place and one
/// the user watches jump.
///
/// [onChange] fires during layout, so it must not mark anything dirty
/// synchronously. The callback is deferred to the end of the frame internally;
/// callers can simply `setState`.
class MeasureSize extends SingleChildRenderObjectWidget {
  /// Wraps [child] in a size-reporting box.
  const MeasureSize({
    required this.onChange,
    required Widget super.child,
    super.key,
  });

  /// Called whenever the child's size changes, including the first layout.
  final SizeChangedCallback onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

/// The render object behind [MeasureSize]: a proxy box that reports its size
/// after each layout that changes it.
class RenderMeasureSize extends RenderProxyBox {
  /// Creates a size-reporting proxy box.
  RenderMeasureSize(this.onChange);

  /// Callback invoked after each layout that changes the size.
  SizeChangedCallback onChange;

  Size? _lastReported;
  bool _scheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastReported == size) {
      return;
    }
    _lastReported = size;
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    // Reporting synchronously would mean mutating widget state during layout.
    // Defer to the end of this frame instead: the notification still lands
    // before the frame is rasterised for the *next* pump.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final Size? reported = _lastReported;
      if (reported == null || !attached) {
        return;
      }
      onChange(reported);
    });
  }

  @override
  void detach() {
    _lastReported = null;
    super.detach();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Size>('lastReported', _lastReported));
  }
}
