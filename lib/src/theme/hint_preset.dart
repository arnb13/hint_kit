/// @docImport '../tooltip/hint.dart';
/// @docImport '../tour/hint_target.dart';
library;

import 'package:flutter/material.dart';

import '../core/hint_arrow.dart';
import '../core/hint_transition.dart';
import 'hint_theme.dart';

/// A ready-made look for hint bubbles, tour cards and spotlights.
///
/// A preset is a *starting point*, not a straitjacket. Set it on
/// [HintThemeData.preset] and every field you also set explicitly still wins:
///
/// ```dart
/// // The whole app, one line.
/// extensions: const <ThemeExtension<dynamic>>[
///   HintThemeData(preset: HintPreset.soft),
/// ],
///
/// // A preset with one thing changed — everything else stays the preset's.
/// Hint(
///   theme: const HintThemeData(
///     preset: HintPreset.soft,
///     maxWidth: 360,
///   ),
///   message: 'Wider than the preset, otherwise identical',
///   child: child,
/// )
/// ```
///
/// Presets do not hard-code a palette they do not have to: where a design is
/// defined by its shape rather than its colour, the colours are left to the
/// ambient [ColorScheme], so the same preset reads correctly in light and dark
/// mode. Where the design *is* a colour choice — [contrast], [branded] — it is
/// derived from the ambient theme too.
///
/// A preset is resolved after the [HintThemeData] layers are merged, so the
/// full fallback chain a widget sees is:
///
/// 1. the per-instance `theme:` on a [Hint] or [HintTarget],
/// 2. the [HintThemeData] on [ThemeData.extensions],
/// 3. the [HintPreset] named by whichever of those set one,
/// 4. defaults derived from the ambient [ColorScheme] and [TextTheme].
///
/// To build a custom design *from* a preset rather than on top of one, take
/// its values with [themeData] and edit them like any other [HintThemeData].
///
/// {@category Theming}
enum HintPreset {
  /// The package's own default look: a dark chip in a light app and a light
  /// chip in a dark one, small radius, soft shadow, straight caret.
  ///
  /// Colours come from [ColorScheme.inverseSurface], which is what makes a
  /// tooltip read as a raised object rather than as part of the page.
  material,

  /// A flat, outlined popover that sits *on* the page instead of above it.
  ///
  /// Surface fill, hairline outline, no shadow, tight padding and a small
  /// caret. Suits dense, information-heavy UIs where a floating dark chip
  /// would be too loud.
  minimal,

  /// Friendly and rounded: a generous corner radius, roomy padding, a large
  /// curved caret and a slightly overshooting entrance.
  ///
  /// The caret shape is the one that most rewards size, so this is the preset
  /// where [HintArrowShape.curved] actually reads as a speech-balloon tail.
  soft,

  /// Maximum legibility: pure black on white, or white on black in a dark
  /// theme, with heavier type and no shadow to soften the edge.
  ///
  /// Also darkens the tour scrim, so the spotlit target is unmistakable. A
  /// reasonable design to switch to under [MediaQueryData.highContrast].
  contrast,

  /// Tinted with your brand: [ColorScheme.primaryContainer] fill, a
  /// [ColorScheme.primary] outline and a scrim tinted the same way.
  ///
  /// The one preset that makes a hint look like part of the product rather
  /// than part of the platform.
  branded,

  /// Square corners, a hairline outline, minimal padding and a fast, flat
  /// transition. Utilitarian — desktop tools, editors, dense tables.
  sharp,

  /// A raised card rather than a chip: surface fill, high elevation, large
  /// radius, wide measure and a heavy blurred scrim.
  ///
  /// Built for tours — the extra width and padding are what a step card with a
  /// title, a body and three buttons actually needs — but a [Hint] using it
  /// looks like a small dialog, which is often what a rich, interactive bubble
  /// wants to be.
  card,

  /// Frosted glass: a translucent fill over a blurred background, with a
  /// hairline highlight along the edge.
  ///
  /// The one preset that costs something to draw — a `saveLayer` per bubble
  /// for [HintThemeData.backgroundBlur] — and the one that most depends on
  /// what is behind it. Over a plain background it is just a pale bubble; over
  /// a photo, a map or a dense list it is the point.
  glass,

  /// An iOS-flavoured popover: light fill even in a light app, a 13pt radius,
  /// a soft wide shadow and a gentle dim.
  ///
  /// Deliberately *not* the inverse-surface chip Material uses — on iOS a
  /// popover reads as a small floating panel in the page's own colours.
  cupertino,

  /// Whichever of [cupertino] and [material] matches the platform.
  ///
  /// Resolved from [ThemeData.platform], so it follows a platform override in
  /// the ambient theme — and `debugDefaultTargetPlatformOverride` — rather
  /// than the raw host OS. That is what makes it testable, and what makes an
  /// app that deliberately renders iOS-style on Android behave.
  adaptive;

  /// This preset's values as a plain [HintThemeData], resolved against the
  /// ambient theme of [context].
  ///
  /// Use it to start a custom design *from* a preset instead of layering on
  /// top of one:
  ///
  /// ```dart
  /// final HintThemeData mine = HintPreset.card.themeData(context).copyWith(
  ///   backgroundColor: const Color(0xFF10131A),
  ///   arrowShape: HintArrowShape.curved,
  /// );
  /// ```
  ///
  /// The result has no [HintThemeData.preset] of its own, so it is a finished
  /// design rather than another reference.
  HintThemeData themeData(BuildContext context) =>
      hintPresetData(this, Theme.of(context));
}

/// Builds [preset]'s values against [theme].
///
/// Package-internal: the public entry points are [HintThemeData.preset], which
/// resolves through here, and [HintPreset.themeData]. It is a top-level
/// function kept off the barrel's `show` clause rather than a private one so
/// that [HintThemeData] in the neighbouring library can reach it.
HintThemeData hintPresetData(HintPreset preset, ThemeData theme) {
  final ColorScheme colors = theme.colorScheme;
  final bool isDark = theme.brightness == Brightness.dark;
  switch (preset) {
    case HintPreset.material:
      // Colours are deliberately unset: the ColorScheme-derived defaults *are*
      // this design, and leaving them null keeps it correct in both modes.
      return const HintThemeData(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        elevation: 4,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        arrowSize: Size(14, 7),
        arrowShape: HintArrowShape.triangle,
        maxWidth: 280,
        transitionDuration: Duration(milliseconds: 150),
        transitionCurve: Curves.easeOutCubic,
        transition: HintTransition.scale,
      );

    case HintPreset.minimal:
      return HintThemeData(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        borderColor: colors.outlineVariant,
        borderWidth: 1,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        arrowSize: const Size(12, 6),
        arrowShape: HintArrowShape.triangle,
        maxWidth: 260,
        transitionDuration: const Duration(milliseconds: 120),
        transitionCurve: Curves.easeOut,
        transition: HintTransition.fade,
        // A flat, page-coloured bubble needs a lighter scrim behind it, or the
        // dim swallows the one edge the design has.
        scrimColor: isDark ? const Color(0xB3000000) : const Color(0x8A000000),
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(6)),
        spotlightPadding: const EdgeInsets.all(6),
      );

    case HintPreset.soft:
      return const HintThemeData(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        elevation: 6,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        arrowSize: Size(22, 12),
        arrowShape: HintArrowShape.curved,
        maxWidth: 300,
        transitionDuration: Duration(milliseconds: 220),
        // The overshoot lives in the transition, so the curve must not add a
        // second one; and the exit is quicker than the entrance, because a
        // bubble that bounces while it leaves reads as a glitch.
        transition: HintTransition.pop,
        transitionCurve: Curves.easeOutCubic,
        reverseTransitionDuration: Duration(milliseconds: 140),
        spotlightBorderRadius: BorderRadius.all(Radius.circular(20)),
        spotlightPadding: EdgeInsets.all(12),
      );

    case HintPreset.contrast:
      final Color fill =
          isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      final Color ink =
          isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      return HintThemeData(
        backgroundColor: fill,
        foregroundColor: ink,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        // No shadow: a soft edge is the first thing to go when legibility is
        // the whole point.
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        arrowSize: const Size(16, 8),
        arrowShape: HintArrowShape.triangle,
        maxWidth: 300,
        titleStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        messageStyle: const TextStyle(fontSize: 15, height: 1.3),
        transitionDuration: const Duration(milliseconds: 120),
        transitionCurve: Curves.easeOut,
        transition: HintTransition.fade,
        scrimColor: const Color(0xF2000000),
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(4)),
        spotlightPadding: const EdgeInsets.all(6),
      );

    case HintPreset.branded:
      return HintThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        borderColor: colors.primary,
        borderWidth: 1.5,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        elevation: 3,
        shadowColor: colors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        arrowSize: const Size(20, 10),
        arrowShape: HintArrowShape.curved,
        maxWidth: 300,
        transitionDuration: const Duration(milliseconds: 180),
        transitionCurve: Curves.easeOutCubic,
        transition: HintTransition.scale,
        // The dim is tinted towards the brand rather than neutral black.
        scrimColor: Color.alphaBlend(
          colors.primary.withAlpha(0x59),
          const Color(0xCC000000),
        ),
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(14)),
        spotlightPadding: const EdgeInsets.all(10),
      );

    case HintPreset.sharp:
      return HintThemeData(
        // A hairline in the *text* colour, not in an outline colour: the fill
        // is the inverse surface, so a neutral grey outline disappears into
        // it. This reads as a crisp lit edge on the chip in both modes.
        borderColor: colors.onInverseSurface.withAlpha(0x4D),
        borderWidth: 1,
        borderRadius: BorderRadius.zero,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        arrowSize: const Size(12, 6),
        arrowShape: HintArrowShape.triangle,
        // With square corners there is no corner for the caret to ride onto,
        // so it may sit much closer to the end of the edge than usual.
        arrowInset: 8,
        maxWidth: 260,
        transitionDuration: const Duration(milliseconds: 90),
        transitionCurve: Curves.linearToEaseOut,
        // Fast and flat: no scaling, because a chip with square corners that
        // grows reads as a rendering artefact rather than as motion.
        transition: HintTransition.fade,
        spotlightBorderRadius: BorderRadius.zero,
        spotlightPadding: const EdgeInsets.all(4),
      );

    case HintPreset.card:
      return HintThemeData(
        // surfaceContainerHigh rather than surface: in a dark theme a plain
        // surface fill is the same value as the page behind it, and elevation
        // alone is not enough separation for a card this large.
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        elevation: 12,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        arrowSize: const Size(18, 9),
        arrowShape: HintArrowShape.triangle,
        maxWidth: 340,
        transitionDuration: const Duration(milliseconds: 250),
        transitionCurve: Curves.easeOutCubic,
        // Arrives from the direction of its target, which is what ties a tour
        // card to the thing it is talking about.
        transition: HintTransition.slide,
        scrimColor: const Color(0xD9000000),
        // Affordable here because a tour shows one card at a time; see
        // HintThemeData.scrimBlur for why the package default is 0.
        scrimBlur: 2,
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(16)),
        spotlightPadding: const EdgeInsets.all(12),
      );

    case HintPreset.glass:
      return HintThemeData(
        // Translucent on purpose: an opaque fill would hide the blur that is
        // the whole design.
        backgroundColor:
            isDark ? const Color(0xB218181C) : const Color(0xC0FFFFFF),
        foregroundColor:
            isDark ? const Color(0xFFF2F3F7) : const Color(0xFF14161A),
        // A light hairline reads as the lit edge of a pane of glass.
        borderColor: isDark ? const Color(0x40FFFFFF) : const Color(0x59FFFFFF),
        borderWidth: 1,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        elevation: 8,
        backgroundBlur: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        arrowSize: const Size(20, 10),
        arrowShape: HintArrowShape.curved,
        maxWidth: 300,
        transitionDuration: const Duration(milliseconds: 220),
        transitionCurve: Curves.easeOutCubic,
        transition: HintTransition.scale,
        scrimColor: const Color(0x8A000000),
        scrimBlur: 3,
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(16)),
        spotlightPadding: const EdgeInsets.all(10),
      );

    case HintPreset.cupertino:
      return HintThemeData(
        // systemBackground / systemGray6, near enough: a popover on iOS is a
        // panel in the page's own colours, not an inverted chip.
        backgroundColor:
            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF),
        foregroundColor:
            isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        borderColor: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
        borderWidth: 0.5,
        borderRadius: const BorderRadius.all(Radius.circular(13)),
        elevation: 8,
        shadowColor: const Color(0xFF000000),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        arrowSize: const Size(18, 9),
        arrowShape: HintArrowShape.triangle,
        maxWidth: 300,
        transitionDuration: const Duration(milliseconds: 200),
        transitionCurve: Curves.easeOutCubic,
        transition: HintTransition.scale,
        // Lighter than Material's: iOS dims a little and relies on the panel.
        scrimColor: const Color(0x66000000),
        spotlightBorderRadius: const BorderRadius.all(Radius.circular(13)),
        spotlightPadding: const EdgeInsets.all(8),
      );

    case HintPreset.adaptive:
      // Resolved from the theme's platform rather than the host OS, so a
      // platform override in ThemeData — or in a test — is honoured.
      final HintPreset resolved = switch (theme.platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => HintPreset.cupertino,
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.windows =>
          HintPreset.material,
      };
      return hintPresetData(resolved, theme);
  }
}
