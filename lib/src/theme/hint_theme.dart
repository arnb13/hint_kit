import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/hint_arrow.dart';
import '../core/hint_transition.dart';
import 'hint_preset.dart';

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
/// For a ready-made design, name a [HintPreset] and override only what you
/// want to differ:
///
/// ```dart
/// HintThemeData(preset: HintPreset.soft, maxWidth: 360)
/// ```
///
/// Every field is nullable. A `null` field means "fall back", and the
/// fallbacks are resolved in this order by [HintThemeData.resolve]:
///
/// 1. the per-instance `theme` passed to a `Hint` or `HintTarget`,
/// 2. the [HintThemeData] found on [ThemeData.extensions],
/// 3. the [preset] named by whichever of those set one,
/// 4. defaults derived from the ambient [ColorScheme] and [TextTheme], which
///    are designed to look correct in both light and dark mode without any
///    configuration at all.
///
/// Because resolution is per-field, a per-instance override of a single colour
/// keeps every other value from the app-wide theme — and a single override on
/// top of a [preset] keeps the rest of that design.
///
/// {@category Theming}
@immutable
class HintThemeData extends ThemeExtension<HintThemeData> with Diagnosticable {
  /// Creates a hint theme. Every argument is optional; see the class docs for
  /// how unset values are resolved.
  const HintThemeData({
    this.preset,
    this.followHighContrast,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.elevation,
    this.shadowColor,
    this.padding,
    this.arrowSize,
    this.arrowShape,
    this.arrowBuilder,
    this.arrowInset,
    this.gap,
    this.screenMargin,
    this.maxWidth,
    this.titleStyle,
    this.messageStyle,
    this.transitionDuration,
    this.reverseTransitionDuration,
    this.transitionCurve,
    this.transition,
    this.transitionBuilder,
    this.scrimColor,
    this.scrimOpacity,
    this.scrimBlur,
    this.backgroundBlur,
    this.spotlightBorderRadius,
    this.spotlightPadding,
    this.spotlightMoveDuration,
  });

  /// Switches to [HintPreset.contrast] when the platform asks for high
  /// contrast.
  ///
  /// Reads [MediaQueryData.highContrast] — "Increase Contrast" on iOS and
  /// macOS, the high-contrast themes on Windows — and swaps the design for the
  /// legible one, keeping every field you set explicitly. Off by default,
  /// because it overrides a [preset] you may have chosen deliberately.
  ///
  /// ```dart
  /// HintThemeData(preset: HintPreset.soft, followHighContrast: true)
  /// ```
  final bool? followHighContrast;

  /// A ready-made design to use for every field this theme leaves unset.
  ///
  /// The preset sits between the explicit fields and the
  /// [ColorScheme]-derived defaults, so setting one is never destructive:
  /// anything you also set here wins, and anything the preset leaves open
  /// still falls through to the ambient theme.
  ///
  /// When both an app-wide [HintThemeData] and a per-instance one name a
  /// preset, the per-instance one wins outright — presets do not blend.
  final HintPreset? preset;

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

  /// The caret's silhouette. Defaults to [HintArrowShape.triangle].
  ///
  /// The built-in shapes fill the same [arrowSize] box, so switching between
  /// them changes only the outline — never the bubble's position.
  final HintArrowShape? arrowShape;

  /// Draws a caret of your own, for [HintArrowShape.custom].
  ///
  /// Ignored by every other shape. The path is unioned into the bubble body,
  /// so a custom caret keeps the continuous border and single shadow that the
  /// built-in ones have:
  ///
  /// ```dart
  /// HintThemeData(
  ///   arrowShape: HintArrowShape.custom,
  ///   arrowBuilder: (HintArrowGeometry g) => Path()
  ///     ..moveTo(g.baseStart.dx, g.baseStart.dy)
  ///     ..quadraticBezierTo(
  ///       g.baseCentre.dx, g.baseCentre.dy, g.tip.dx, g.tip.dy)
  ///     ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
  ///     ..close(),
  /// )
  /// ```
  final HintArrowBuilder? arrowBuilder;

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
  ///
  /// Applied to the animation every transition is driven by, so an
  /// overshooting curve such as [Curves.easeOutBack] gives any of them a
  /// bounce. Opacity is clamped, so the overshoot shows up as movement rather
  /// than as an assertion.
  final Curve? transitionCurve;

  /// Which ready-made show/hide animation to use.
  ///
  /// Defaults to [HintTransition.scale]. Ignored when [transitionBuilder] is
  /// set, which is the escape hatch for an animation of your own.
  final HintTransition? transition;

  /// Animates the bubble yourself, instead of using [transition].
  ///
  /// Wins over [transition] when both are set. See [HintTransitionBuilder] for
  /// what the builder is handed and what it is expected to return.
  final HintTransitionBuilder? transitionBuilder;

  /// Colour of the full-screen scrim painted behind a tour step.
  ///
  /// Its alpha is the dim, so a colour alone is enough to set both:
  ///
  /// ```dart
  /// HintThemeData(scrimColor: Color(0xE6101828))   // a dark navy at 90%
  /// ```
  ///
  /// Use [scrimOpacity] when you want to change *only* how dark the step gets
  /// and leave the hue — the preset's, the default's — alone.
  final Color? scrimColor;

  /// How opaque the scrim is, from `0` (invisible) to `1` (solid).
  ///
  /// Replaces the alpha of whatever colour is in play — [scrimColor], a
  /// [preset]'s, or the default — so the two are independent settings:
  ///
  /// ```dart
  /// // Darker, but still the default neutral black.
  /// TourScope(
  ///   theme: const HintThemeData(scrimOpacity: 0.95),
  ///   child: const MyApp(),
  /// )
  ///
  /// // A brand-tinted scrim at whatever opacity you like.
  /// HintThemeData(scrimColor: const Color(0xFF1B2A4A), scrimOpacity: 0.8)
  /// ```
  ///
  /// Values outside 0..1 are clamped. Null leaves the colour's own alpha
  /// untouched.
  final double? scrimOpacity;

  /// Gaussian blur sigma applied to the scrim.
  ///
  /// `0` (the default) paints a flat dim, which is markedly cheaper than a
  /// [BackdropFilter].
  final double? scrimBlur;

  /// Gaussian blur sigma applied to whatever is *behind* the bubble.
  ///
  /// `0` (the default) leaves the background alone. Anything above that
  /// frosts the page under the bubble, clipped to the same fused silhouette as
  /// the fill — so the caret is frosted too, and the drop shadow still falls
  /// outside it.
  ///
  /// Only worth having with a translucent [backgroundColor]; over an opaque
  /// fill there is nothing to see through. It costs a `saveLayer` per bubble,
  /// which is why it is off by default. See [HintPreset.glass] for a design
  /// built around it.
  final double? backgroundBlur;

  /// Corner radius for `SpotlightShape.roundedRect` holes.
  final BorderRadius? spotlightBorderRadius;

  /// Padding added around the target rect when cutting the spotlight hole.
  final EdgeInsets? spotlightPadding;

  /// How long the spotlight takes to travel from the previous step's target to
  /// this one's.
  ///
  /// The hole morphs between the two rects rather than cutting, which is what
  /// makes a tour read as one continuous thing. [Duration.zero] restores the
  /// cut. Ignored for the first step of a tour — there is nothing to travel
  /// from — and under [MediaQuery.disableAnimationsOf].
  final Duration? spotlightMoveDuration;

  /// Resolves every field against [context], producing a theme whose getters
  /// are all non-null.
  ///
  /// [overrides] takes precedence over the ambient [ThemeData.extensions],
  /// which in turn takes precedence over the [preset] named by the merged
  /// result, which in turn takes precedence over the [ColorScheme]-derived
  /// defaults.
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
    // High contrast is a property of the platform, not of the theme, so it is
    // read here — the one place resolution has a BuildContext — rather than
    // inside the preset.
    final bool highContrast = merged.followHighContrast ?? false
        ? MediaQuery.maybeHighContrastOf(context) ?? false
        : false;
    return ResolvedHintTheme._(
      merged,
      theme,
      presetOverride: highContrast ? HintPreset.contrast : null,
    );
  }

  /// Returns a copy of this theme with every non-null field of [other]
  /// applied on top.
  HintThemeData merge(HintThemeData? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      preset: other.preset,
      followHighContrast: other.followHighContrast,
      backgroundColor: other.backgroundColor,
      foregroundColor: other.foregroundColor,
      borderColor: other.borderColor,
      borderWidth: other.borderWidth,
      borderRadius: other.borderRadius,
      elevation: other.elevation,
      shadowColor: other.shadowColor,
      padding: other.padding,
      arrowSize: other.arrowSize,
      arrowShape: other.arrowShape,
      arrowBuilder: other.arrowBuilder,
      arrowInset: other.arrowInset,
      gap: other.gap,
      screenMargin: other.screenMargin,
      maxWidth: other.maxWidth,
      titleStyle: other.titleStyle,
      messageStyle: other.messageStyle,
      transitionDuration: other.transitionDuration,
      reverseTransitionDuration: other.reverseTransitionDuration,
      transitionCurve: other.transitionCurve,
      transition: other.transition,
      transitionBuilder: other.transitionBuilder,
      scrimColor: other.scrimColor,
      scrimOpacity: other.scrimOpacity,
      scrimBlur: other.scrimBlur,
      backgroundBlur: other.backgroundBlur,
      spotlightBorderRadius: other.spotlightBorderRadius,
      spotlightPadding: other.spotlightPadding,
      spotlightMoveDuration: other.spotlightMoveDuration,
    );
  }

  @override
  HintThemeData copyWith({
    HintPreset? preset,
    bool? followHighContrast,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    double? borderWidth,
    BorderRadius? borderRadius,
    double? elevation,
    Color? shadowColor,
    EdgeInsets? padding,
    Size? arrowSize,
    HintArrowShape? arrowShape,
    HintArrowBuilder? arrowBuilder,
    double? arrowInset,
    double? gap,
    EdgeInsets? screenMargin,
    double? maxWidth,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    Curve? transitionCurve,
    HintTransition? transition,
    HintTransitionBuilder? transitionBuilder,
    Color? scrimColor,
    double? scrimOpacity,
    double? scrimBlur,
    double? backgroundBlur,
    BorderRadius? spotlightBorderRadius,
    EdgeInsets? spotlightPadding,
    Duration? spotlightMoveDuration,
  }) {
    return HintThemeData(
      preset: preset ?? this.preset,
      followHighContrast: followHighContrast ?? this.followHighContrast,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      padding: padding ?? this.padding,
      arrowSize: arrowSize ?? this.arrowSize,
      arrowShape: arrowShape ?? this.arrowShape,
      arrowBuilder: arrowBuilder ?? this.arrowBuilder,
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
      transition: transition ?? this.transition,
      transitionBuilder: transitionBuilder ?? this.transitionBuilder,
      scrimColor: scrimColor ?? this.scrimColor,
      scrimOpacity: scrimOpacity ?? this.scrimOpacity,
      scrimBlur: scrimBlur ?? this.scrimBlur,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      spotlightBorderRadius:
          spotlightBorderRadius ?? this.spotlightBorderRadius,
      spotlightPadding: spotlightPadding ?? this.spotlightPadding,
      spotlightMoveDuration:
          spotlightMoveDuration ?? this.spotlightMoveDuration,
    );
  }

  @override
  HintThemeData lerp(covariant HintThemeData? other, double t) {
    if (other == null) {
      return this;
    }
    return HintThemeData(
      // A preset is a name, not a value: like curves and durations below, it
      // snaps at the halfway point rather than interpolating.
      preset: t < 0.5 ? preset : other.preset,
      followHighContrast:
          t < 0.5 ? followHighContrast : other.followHighContrast,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth: _lerpDouble(borderWidth, other.borderWidth, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      elevation: _lerpDouble(elevation, other.elevation, t),
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t),
      padding: EdgeInsets.lerp(padding, other.padding, t),
      arrowSize: Size.lerp(arrowSize, other.arrowSize, t),
      arrowShape: t < 0.5 ? arrowShape : other.arrowShape,
      arrowBuilder: t < 0.5 ? arrowBuilder : other.arrowBuilder,
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
      transition: t < 0.5 ? transition : other.transition,
      transitionBuilder: t < 0.5 ? transitionBuilder : other.transitionBuilder,
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t),
      scrimOpacity: _lerpDouble(scrimOpacity, other.scrimOpacity, t),
      scrimBlur: _lerpDouble(scrimBlur, other.scrimBlur, t),
      backgroundBlur: _lerpDouble(backgroundBlur, other.backgroundBlur, t),
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
      spotlightMoveDuration:
          t < 0.5 ? spotlightMoveDuration : other.spotlightMoveDuration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HintThemeData &&
        other.preset == preset &&
        other.followHighContrast == followHighContrast &&
        other.backgroundColor == backgroundColor &&
        other.foregroundColor == foregroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.elevation == elevation &&
        other.shadowColor == shadowColor &&
        other.padding == padding &&
        other.arrowSize == arrowSize &&
        other.arrowShape == arrowShape &&
        other.arrowBuilder == arrowBuilder &&
        other.arrowInset == arrowInset &&
        other.gap == gap &&
        other.screenMargin == screenMargin &&
        other.maxWidth == maxWidth &&
        other.titleStyle == titleStyle &&
        other.messageStyle == messageStyle &&
        other.transitionDuration == transitionDuration &&
        other.reverseTransitionDuration == reverseTransitionDuration &&
        other.transitionCurve == transitionCurve &&
        other.transition == transition &&
        other.transitionBuilder == transitionBuilder &&
        other.scrimColor == scrimColor &&
        other.scrimOpacity == scrimOpacity &&
        other.scrimBlur == scrimBlur &&
        other.backgroundBlur == backgroundBlur &&
        other.spotlightBorderRadius == spotlightBorderRadius &&
        other.spotlightPadding == spotlightPadding &&
        other.spotlightMoveDuration == spotlightMoveDuration;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        preset,
        followHighContrast,
        backgroundColor,
        foregroundColor,
        borderColor,
        borderWidth,
        borderRadius,
        elevation,
        shadowColor,
        padding,
        arrowSize,
        arrowShape,
        arrowBuilder,
        arrowInset,
        gap,
        screenMargin,
        maxWidth,
        titleStyle,
        messageStyle,
        transitionDuration,
        reverseTransitionDuration,
        transitionCurve,
        transition,
        transitionBuilder,
        scrimColor,
        scrimOpacity,
        scrimBlur,
        backgroundBlur,
        spotlightBorderRadius,
        spotlightPadding,
        spotlightMoveDuration,
      ]);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const Object? none = null;
    properties
      ..add(EnumProperty<HintPreset>('preset', preset, defaultValue: none))
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
      ..add(
        EnumProperty<HintArrowShape>(
          'arrowShape',
          arrowShape,
          defaultValue: none,
        ),
      )
      ..add(
        EnumProperty<HintTransition>(
          'transition',
          transition,
          defaultValue: none,
        ),
      )
      ..add(
        FlagProperty(
          'transitionBuilder',
          value: transitionBuilder != null,
          ifTrue: 'custom transition',
        ),
      )
      ..add(
        FlagProperty(
          'arrowBuilder',
          value: arrowBuilder != null,
          ifTrue: 'custom arrow',
        ),
      )
      ..add(DoubleProperty('gap', gap))
      ..add(DoubleProperty('maxWidth', maxWidth))
      ..add(ColorProperty('scrimColor', scrimColor))
      ..add(DoubleProperty('scrimOpacity', scrimOpacity))
      ..add(DoubleProperty('scrimBlur', scrimBlur))
      ..add(DoubleProperty('backgroundBlur', backgroundBlur));
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
///
/// {@category Theming}
@immutable
class ResolvedHintTheme {
  ResolvedHintTheme._(
    HintThemeData data,
    this._theme, {
    HintPreset? presetOverride,
  })  : _presetOverride = presetOverride,
        _data = _applyPreset(data, _theme, presetOverride),
        _colors = _theme.colorScheme,
        _text = _theme.textTheme;

  /// A preset that wins over [HintThemeData.preset] for this resolution only.
  ///
  /// Set when [HintThemeData.followHighContrast] fires. Carried through
  /// [withoutArrow] so a derived theme cannot quietly drop it.
  final HintPreset? _presetOverride;

  /// Fills [data]'s unset fields from its [HintThemeData.preset], if it names
  /// one.
  ///
  /// Explicit fields win, so this only ever adds values. It is applied here
  /// rather than in [HintThemeData.resolve] so that every [ResolvedHintTheme]
  /// — including the one [withoutArrow] derives — carries the preset's values
  /// already baked in. Running it twice is a no-op for that reason.
  static HintThemeData _applyPreset(
    HintThemeData data,
    ThemeData theme,
    HintPreset? override,
  ) {
    final HintPreset? preset = override ?? data.preset;
    if (preset == null) {
      return data;
    }
    return hintPresetData(preset, theme).merge(data);
  }

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

  /// See [HintThemeData.arrowShape].
  HintArrowShape get arrowShape => _data.arrowShape ?? HintArrowShape.triangle;

  /// See [HintThemeData.arrowBuilder].
  HintArrowBuilder? get arrowBuilder => _data.arrowBuilder;

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

  /// See [HintThemeData.transition].
  HintTransition get transition => _data.transition ?? HintTransition.scale;

  /// See [HintThemeData.transitionBuilder].
  HintTransitionBuilder? get transitionBuilder => _data.transitionBuilder;

  /// Applies [transitionBuilder], or [transition] when there is none.
  ///
  /// Every bubble animates through here, so a custom builder and a preset
  /// transition cannot diverge in how they are driven.
  Widget buildTransition(
    BuildContext context,
    HintTransitionInfo info,
    Widget child,
  ) {
    final HintTransitionBuilder? builder = transitionBuilder;
    if (builder != null) {
      return builder(context, info, child);
    }
    return transition.build(context, info, child);
  }

  /// See [HintThemeData.scrimColor], with [HintThemeData.scrimOpacity]
  /// applied.
  ///
  /// The default dim is deliberately heavy: a tour step is modal, and a scrim
  /// light enough to read the page through it invites the user to keep
  /// reading the page instead of the step.
  Color get scrimColor {
    final Color base = _data.scrimColor ??
        (isDark ? const Color(0xF2000000) : const Color(0xE6000000));
    final double? opacity = _data.scrimOpacity;
    if (opacity == null) {
      return base;
    }
    return base.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
  }

  /// The scrim's opacity as a fraction, whether it came from
  /// [HintThemeData.scrimOpacity] or from the alpha of a colour.
  ///
  /// Reading it back is what a "how dark is the tour?" control binds to.
  ///
  /// `Color.a` supersedes `.alpha`, but only from Flutter 3.27; the package
  /// supports 3.24, so the deprecated accessor stays until the floor moves.
  // ignore: deprecated_member_use
  double get scrimOpacity => scrimColor.alpha / 255;

  /// See [HintThemeData.scrimBlur].
  double get scrimBlur => _data.scrimBlur ?? 0;

  /// See [HintThemeData.backgroundBlur].
  double get backgroundBlur => _data.backgroundBlur ?? 0;

  /// See [HintThemeData.spotlightBorderRadius].
  BorderRadius get spotlightBorderRadius =>
      _data.spotlightBorderRadius ?? const BorderRadius.all(Radius.circular(8));

  /// See [HintThemeData.spotlightPadding].
  EdgeInsets get spotlightPadding =>
      _data.spotlightPadding ?? const EdgeInsets.all(8);

  /// See [HintThemeData.spotlightMoveDuration].
  Duration get spotlightMoveDuration =>
      _data.spotlightMoveDuration ?? const Duration(milliseconds: 320);

  /// A copy of this theme with no arrow.
  ///
  /// Used for bubbles that are not visually anchored to an edge, such as a
  /// tour step card. It keeps every other value, so a card and a tooltip in
  /// the same app cannot drift apart.
  ResolvedHintTheme withoutArrow() => ResolvedHintTheme._(
        _data.copyWith(arrowSize: Size.zero),
        _theme,
        presetOverride: _presetOverride,
      );

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
