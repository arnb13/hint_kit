import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Visual configuration shared by tooltips, hints and tour step cards.
///
/// [HintThemeData] is a [ThemeExtension], so the usual place to configure it
/// app-wide is on [ThemeData.extensions]:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     colorSchemeSeed: Colors.indigo,
///     extensions: const <ThemeExtension<dynamic>>[
///       HintThemeData(backgroundColor: Colors.black87),
///     ],
///   ),
/// )
/// ```
///
/// Every field is nullable. A `null` field means "fall back", and the
/// fallbacks are resolved in this order by [HintThemeData.resolve]:
///
/// 1. the per-instance `theme` passed to a `Hint` or `HintTarget`,
/// 2. the [HintThemeData] found on [ThemeData.extensions],
/// 3. defaults derived from the ambient [ColorScheme] and [TextTheme], which
///    are designed to look correct in both light and dark mode without any
///    configuration at all.
///
/// Because resolution is per-field, a per-instance override of a single colour
/// keeps every other value from the app-wide theme.
@immutable
class HintThemeData extends ThemeExtension<HintThemeData> with Diagnosticable {
  /// Creates a hint theme. Every argument is optional; see the class docs for
  /// how unset values are resolved.
  const HintThemeData({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.elevation,
    this.shadowColor,
    this.padding,
    this.arrowSize,
    this.arrowInset,
    this.gap,
    this.screenMargin,
    this.maxWidth,
    this.titleStyle,
    this.messageStyle,
    this.transitionDuration,
    this.reverseTransitionDuration,
    this.transitionCurve,
    this.scrimColor,
    this.scrimBlur,
    this.spotlightBorderRadius,
    this.spotlightPadding,
  });

  /// Fill colour of the bubble, arrow included.
  final Color? backgroundColor;

  /// Colour used for text and icons inside the bubble.
  ///
  /// This seeds [titleStyle] and [messageStyle] when they do not specify a
  /// colour of their own.
  final Color? foregroundColor;

  /// Stroke colour of the bubble outline. Defaults to transparent.
  final Color? borderColor;

  /// Stroke width of the bubble outline. A width of `0` disables the stroke.
  final double? borderWidth;

  /// Corner radius of the bubble body.
  ///
  /// The arrow is unioned into the body path, so a large radius never leaves a
  /// seam where the caret meets the corner; the arrow is nudged inwards by
  /// [arrowInset] instead.
  final BorderRadius? borderRadius;

  /// Material elevation used to derive the bubble's drop shadow.
  final double? elevation;

  /// Colour of the drop shadow. Ignored when [elevation] is `0`.
  final Color? shadowColor;

  /// Padding between the bubble edge and its content.
  final EdgeInsets? padding;

  /// Size of the arrow: width along the bubble edge, height away from it.
  final Size? arrowSize;

  /// Minimum distance between the arrow's centre and either end of the edge it
  /// sits on.
  ///
  /// Keeps the caret off the rounded corners. Defaults to the largest corner
  /// radius plus half the arrow width.
  final double? arrowInset;

  /// Distance between the target and the bubble, arrow tip included.
  final double? gap;

  /// Minimum distance the bubble keeps from the edges of the overlay.
  ///
  /// This is combined with the ambient [MediaQueryData.padding] so bubbles
  /// avoid notches and system bars.
  final EdgeInsets? screenMargin;

  /// Maximum width of the bubble before its text wraps.
  final double? maxWidth;

  /// Text style for the optional bubble title.
  final TextStyle? titleStyle;

  /// Text style for the bubble message and tour step body.
  final TextStyle? messageStyle;

  /// How long the show animation runs.
  ///
  /// Ignored when [MediaQuery.disableAnimationsOf] is true, in which case the
  /// bubble appears immediately.
  final Duration? transitionDuration;

  /// How long the hide animation runs. Defaults to [transitionDuration].
  final Duration? reverseTransitionDuration;

  /// Curve of the show and hide animation.
  final Curve? transitionCurve;

  /// Colour of the full-screen scrim painted behind a tour step.
  final Color? scrimColor;

  /// Gaussian blur sigma applied to the scrim.
  ///
  /// `0` (the default) paints a flat dim, which is markedly cheaper than a
  /// [BackdropFilter].
  final double? scrimBlur;

  /// Corner radius for `SpotlightShape.roundedRect` holes.
  final BorderRadius? spotlightBorderRadius;

  /// Padding added around the target rect when cutting the spotlight hole.
  final EdgeInsets? spotlightPadding;

  /// Resolves every field against [context], producing a theme whose getters
  /// are all non-null.
  ///
  /// [overrides] takes precedence over the ambient [ThemeData.extensions],
  /// which in turn takes precedence over the [ColorScheme]-derived defaults.
  static ResolvedHintTheme resolve(
    BuildContext context, [
    HintThemeData? overrides,
  ]) {
    final ThemeData theme = Theme.of(context);
    final HintThemeData? ambient = theme.extension<HintThemeData>();
    final HintThemeData merged = switch ((ambient, overrides)) {
      (null, null) => const HintThemeData(),
      (final HintThemeData a, null) => a,
      (null, final HintThemeData o) => o,
      (final HintThemeData a, final HintThemeData o) => a.merge(o),
    };
    return ResolvedHintTheme._(merged, theme);
  }

  /// Returns a copy of this theme with every non-null field of [other]
  /// applied on top.
  HintThemeData merge(HintThemeData? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      backgroundColor: other.backgroundColor,
      foregroundColor: other.foregroundColor,
      borderColor: other.borderColor,
      borderWidth: other.borderWidth,
      borderRadius: other.borderRadius,
      elevation: other.elevation,
      shadowColor: other.shadowColor,
      padding: other.padding,
      arrowSize: other.arrowSize,
      arrowInset: other.arrowInset,
      gap: other.gap,
      screenMargin: other.screenMargin,
      maxWidth: other.maxWidth,
      titleStyle: other.titleStyle,
      messageStyle: other.messageStyle,
      transitionDuration: other.transitionDuration,
      reverseTransitionDuration: other.reverseTransitionDuration,
      transitionCurve: other.transitionCurve,
      scrimColor: other.scrimColor,
      scrimBlur: other.scrimBlur,
      spotlightBorderRadius: other.spotlightBorderRadius,
      spotlightPadding: other.spotlightPadding,
    );
  }

  @override
  HintThemeData copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    double? borderWidth,
    BorderRadius? borderRadius,
    double? elevation,
    Color? shadowColor,
    EdgeInsets? padding,
    Size? arrowSize,
    double? arrowInset,
    double? gap,
    EdgeInsets? screenMargin,
    double? maxWidth,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    Curve? transitionCurve,
    Color? scrimColor,
    double? scrimBlur,
    BorderRadius? spotlightBorderRadius,
    EdgeInsets? spotlightPadding,
  }) {
    return HintThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      padding: padding ?? this.padding,
      arrowSize: arrowSize ?? this.arrowSize,
      arrowInset: arrowInset ?? this.arrowInset,
      gap: gap ?? this.gap,
      screenMargin: screenMargin ?? this.screenMargin,
      maxWidth: maxWidth ?? this.maxWidth,
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      reverseTransitionDuration:
          reverseTransitionDuration ?? this.reverseTransitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
      scrimColor: scrimColor ?? this.scrimColor,
      scrimBlur: scrimBlur ?? this.scrimBlur,
      spotlightBorderRadius:
          spotlightBorderRadius ?? this.spotlightBorderRadius,
      spotlightPadding: spotlightPadding ?? this.spotlightPadding,
    );
  }

  @override
  HintThemeData lerp(covariant HintThemeData? other, double t) {
    if (other == null) {
      return this;
    }
    return HintThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth: _lerpDouble(borderWidth, other.borderWidth, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      elevation: _lerpDouble(elevation, other.elevation, t),
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t),
      padding: EdgeInsets.lerp(padding, other.padding, t),
      arrowSize: Size.lerp(arrowSize, other.arrowSize, t),
      arrowInset: _lerpDouble(arrowInset, other.arrowInset, t),
      gap: _lerpDouble(gap, other.gap, t),
      screenMargin: EdgeInsets.lerp(screenMargin, other.screenMargin, t),
      maxWidth: _lerpDouble(maxWidth, other.maxWidth, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
      // Durations and curves are not meaningfully interpolable; they snap at
      // the halfway point like the rest of the Material theme extensions do.
      transitionDuration:
          t < 0.5 ? transitionDuration : other.transitionDuration,
      reverseTransitionDuration:
          t < 0.5 ? reverseTransitionDuration : other.reverseTransitionDuration,
      transitionCurve: t < 0.5 ? transitionCurve : other.transitionCurve,
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t),
      scrimBlur: _lerpDouble(scrimBlur, other.scrimBlur, t),
      spotlightBorderRadius: BorderRadius.lerp(
        spotlightBorderRadius,
        other.spotlightBorderRadius,
        t,
      ),
      spotlightPadding: EdgeInsets.lerp(
        spotlightPadding,
        other.spotlightPadding,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HintThemeData &&
        other.backgroundColor == backgroundColor &&
        other.foregroundColor == foregroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.elevation == elevation &&
        other.shadowColor == shadowColor &&
        other.padding == padding &&
        other.arrowSize == arrowSize &&
        other.arrowInset == arrowInset &&
        other.gap == gap &&
        other.screenMargin == screenMargin &&
        other.maxWidth == maxWidth &&
        other.titleStyle == titleStyle &&
        other.messageStyle == messageStyle &&
        other.transitionDuration == transitionDuration &&
        other.reverseTransitionDuration == reverseTransitionDuration &&
        other.transitionCurve == transitionCurve &&
        other.scrimColor == scrimColor &&
        other.scrimBlur == scrimBlur &&
        other.spotlightBorderRadius == spotlightBorderRadius &&
        other.spotlightPadding == spotlightPadding;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        backgroundColor,
        foregroundColor,
        borderColor,
        borderWidth,
        borderRadius,
        elevation,
        shadowColor,
        padding,
        arrowSize,
        arrowInset,
        gap,
        screenMargin,
        maxWidth,
        titleStyle,
        messageStyle,
        transitionDuration,
        reverseTransitionDuration,
        transitionCurve,
        scrimColor,
        scrimBlur,
        spotlightBorderRadius,
        spotlightPadding,
      ]);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const Object? none = null;
    properties
      ..add(ColorProperty('backgroundColor', backgroundColor))
      ..add(ColorProperty('foregroundColor', foregroundColor))
      ..add(ColorProperty('borderColor', borderColor))
      ..add(DoubleProperty('borderWidth', borderWidth))
      ..add(
        DiagnosticsProperty<BorderRadius>(
          'borderRadius',
          borderRadius,
          defaultValue: none,
        ),
      )
      ..add(DoubleProperty('elevation', elevation))
      ..add(
        DiagnosticsProperty<EdgeInsets>('padding', padding, defaultValue: none),
      )
      ..add(
        DiagnosticsProperty<Size>('arrowSize', arrowSize, defaultValue: none),
      )
      ..add(DoubleProperty('gap', gap))
      ..add(DoubleProperty('maxWidth', maxWidth))
      ..add(ColorProperty('scrimColor', scrimColor))
      ..add(DoubleProperty('scrimBlur', scrimBlur));
  }
}

/// Interpolates two nullable doubles, treating `null` as "keep the other".
double? _lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) {
    return null;
  }
  return lerpDouble(a ?? b, b ?? a, t);
}

/// A [HintThemeData] with every value filled in.
///
/// Obtain one with [HintThemeData.resolve]. Widgets in this package read from
/// this rather than from [HintThemeData] so they never have to repeat fallback
/// logic, and so the defaults live in exactly one place.
@immutable
class ResolvedHintTheme {
  ResolvedHintTheme._(this._data, this._theme)
      : _colors = _theme.colorScheme,
        _text = _theme.textTheme;

  final HintThemeData _data;
  final ThemeData _theme;
  final ColorScheme _colors;
  final TextTheme _text;

  /// Whether the ambient theme is dark.
  ///
  /// The default palette inverts on a dark theme so the bubble always reads as
  /// a raised surface rather than a hole.
  bool get isDark => _theme.brightness == Brightness.dark;

  /// See [HintThemeData.backgroundColor].
  Color get backgroundColor => _data.backgroundColor ?? _colors.inverseSurface;

  /// See [HintThemeData.foregroundColor].
  Color get foregroundColor =>
      _data.foregroundColor ?? _colors.onInverseSurface;

  /// See [HintThemeData.borderColor].
  Color get borderColor => _data.borderColor ?? const Color(0x00000000);

  /// See [HintThemeData.borderWidth].
  double get borderWidth => _data.borderWidth ?? 0;

  /// See [HintThemeData.borderRadius].
  BorderRadius get borderRadius =>
      _data.borderRadius ?? const BorderRadius.all(Radius.circular(8));

  /// See [HintThemeData.elevation].
  double get elevation => _data.elevation ?? 4;

  /// See [HintThemeData.shadowColor].
  Color get shadowColor => _data.shadowColor ?? _theme.shadowColor;

  /// See [HintThemeData.padding].
  EdgeInsets get padding =>
      _data.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// See [HintThemeData.arrowSize].
  Size get arrowSize => _data.arrowSize ?? const Size(14, 7);

  /// See [HintThemeData.arrowInset].
  ///
  /// Defaults to the largest corner radius plus half the arrow width, which is
  /// the smallest inset that guarantees the caret never overlaps a corner.
  double get arrowInset {
    final double? explicit = _data.arrowInset;
    if (explicit != null) {
      return explicit;
    }
    final BorderRadius r = borderRadius;
    final double maxRadius = <double>[
      r.topLeft.x,
      r.topRight.x,
      r.bottomLeft.x,
      r.bottomRight.x,
      r.topLeft.y,
      r.topRight.y,
      r.bottomLeft.y,
      r.bottomRight.y,
    ].reduce((double a, double b) => a > b ? a : b);
    return maxRadius + arrowSize.width / 2;
  }

  /// See [HintThemeData.gap].
  ///
  /// The arrow lives inside the gap, so the default leaves a small margin
  /// between the caret tip and the target.
  double get gap => _data.gap ?? arrowSize.height + 4;

  /// See [HintThemeData.screenMargin].
  EdgeInsets get screenMargin => _data.screenMargin ?? const EdgeInsets.all(8);

  /// See [HintThemeData.maxWidth].
  double get maxWidth => _data.maxWidth ?? 280;

  /// See [HintThemeData.titleStyle].
  TextStyle get titleStyle => (_data.titleStyle ??
          _text.titleSmall ??
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
      .copyWith(color: _data.titleStyle?.color ?? foregroundColor);

  /// See [HintThemeData.messageStyle].
  TextStyle get messageStyle =>
      (_data.messageStyle ?? _text.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(color: _data.messageStyle?.color ?? foregroundColor);

  /// See [HintThemeData.transitionDuration].
  Duration get transitionDuration =>
      _data.transitionDuration ?? const Duration(milliseconds: 150);

  /// See [HintThemeData.reverseTransitionDuration].
  Duration get reverseTransitionDuration =>
      _data.reverseTransitionDuration ?? transitionDuration;

  /// See [HintThemeData.transitionCurve].
  Curve get transitionCurve => _data.transitionCurve ?? Curves.easeOutCubic;

  /// See [HintThemeData.scrimColor].
  Color get scrimColor =>
      _data.scrimColor ??
      (isDark ? const Color(0xCC000000) : const Color(0xB3000000));

  /// See [HintThemeData.scrimBlur].
  double get scrimBlur => _data.scrimBlur ?? 0;

  /// See [HintThemeData.spotlightBorderRadius].
  BorderRadius get spotlightBorderRadius =>
      _data.spotlightBorderRadius ?? const BorderRadius.all(Radius.circular(8));

  /// See [HintThemeData.spotlightPadding].
  EdgeInsets get spotlightPadding =>
      _data.spotlightPadding ?? const EdgeInsets.all(8);

  /// A copy of this theme with no arrow.
  ///
  /// Used for bubbles that are not visually anchored to an edge, such as a
  /// tour step card. It keeps every other value, so a card and a tooltip in
  /// the same app cannot drift apart.
  ResolvedHintTheme withoutArrow() =>
      ResolvedHintTheme._(_data.copyWith(arrowSize: Size.zero), _theme);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedHintTheme &&
          other._data == _data &&
          other._colors == _colors &&
          other._text == _text;

  @override
  int get hashCode => Object.hash(_data, _colors, _text);
}
