import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Pumps a probe under a [MaterialApp] and hands back the resolved theme.
Future<ResolvedHintTheme> resolveIn(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Color seed = const Color(0xFF3F51B5),
  HintThemeData? extension,
  HintThemeData? overrides,
}) async {
  late ResolvedHintTheme resolved;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorSchemeSeed: seed,
        extensions: <ThemeExtension<dynamic>>[
          if (extension != null) extension,
        ],
      ),
      home: Builder(
        builder: (BuildContext context) {
          resolved = HintThemeData.resolve(context, overrides);
          return const SizedBox();
        },
      ),
    ),
  );
  // MaterialApp animates between themes, so a test that resolves twice would
  // otherwise read a half-lerped theme on the second pass.
  await tester.pumpAndSettle();
  return resolved;
}

/// The theme a bubble would use with no configuration at all.
Future<ResolvedHintTheme> unstyled(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) =>
    resolveIn(tester, brightness: brightness);

void main() {
  group('every preset', () {
    for (final HintPreset preset in HintPreset.values) {
      testWidgets('${preset.name} resolves in light and dark',
          (WidgetTester t) async {
        for (final Brightness brightness in Brightness.values) {
          final ResolvedHintTheme r = await resolveIn(
            t,
            brightness: brightness,
            overrides: HintThemeData(preset: preset),
          );
          // Nothing a painter would choke on, and nothing invisible.
          expect(r.maxWidth, greaterThan(0));
          expect(r.elevation, greaterThanOrEqualTo(0));
          expect(r.arrowSize.width, greaterThan(0));
          expect(r.arrowSize.height, greaterThan(0));
          expect(r.gap, greaterThanOrEqualTo(r.arrowSize.height));
          expect(r.padding.horizontal, greaterThan(0));
          expect(r.transitionDuration, greaterThan(Duration.zero));
          expect(r.backgroundColor, isNot(r.foregroundColor));
        }
      });

      testWidgets('${preset.name} keeps the caret off the corners',
          (WidgetTester t) async {
        final ResolvedHintTheme r = await resolveIn(
          t,
          overrides: HintThemeData(preset: preset),
        );
        final BorderRadius radius = r.borderRadius;
        final double maxRadius = <double>[
          radius.topLeft.x,
          radius.topRight.x,
          radius.bottomLeft.x,
          radius.bottomRight.x,
        ].reduce((double a, double b) => a > b ? a : b);
        expect(r.arrowInset, greaterThanOrEqualTo(maxRadius));
      });

      testWidgets('${preset.name} differs from the bare defaults',
          (WidgetTester t) async {
        final ResolvedHintTheme bare = await unstyled(t);
        final ResolvedHintTheme styled = await resolveIn(
          t,
          overrides: HintThemeData(preset: preset),
        );
        // `material` is the defaults made explicit, and `adaptive` resolves
        // to it on the platform tests run as, so those two are the presets
        // allowed to match the defaults.
        if (preset == HintPreset.material || preset == HintPreset.adaptive) {
          expect(styled.backgroundColor, bare.backgroundColor);
          expect(styled.borderRadius, bare.borderRadius);
          expect(styled.arrowSize, bare.arrowSize);
          expect(styled.elevation, bare.elevation);
          expect(styled.padding, bare.padding);
          expect(styled.maxWidth, bare.maxWidth);
        } else {
          final bool sameShape = styled.borderRadius == bare.borderRadius &&
              styled.arrowSize == bare.arrowSize &&
              styled.padding == bare.padding &&
              styled.elevation == bare.elevation;
          final bool sameColours =
              styled.backgroundColor == bare.backgroundColor &&
                  styled.foregroundColor == bare.foregroundColor;
          expect(
            sameShape && sameColours,
            isFalse,
            reason: '${preset.name} is indistinguishable from no preset',
          );
        }
      });
    }
  });

  group('shape-only presets stay adaptive', () {
    testWidgets('soft inherits the ColorScheme in both modes',
        (WidgetTester t) async {
      final ResolvedHintTheme light = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.soft),
      );
      final ResolvedHintTheme bareLight = await unstyled(t);
      expect(light.backgroundColor, bareLight.backgroundColor);

      final ResolvedHintTheme dark = await resolveIn(
        t,
        brightness: Brightness.dark,
        overrides: const HintThemeData(preset: HintPreset.soft),
      );
      expect(dark.backgroundColor, isNot(light.backgroundColor));
    });

    testWidgets('branded follows the seed colour', (WidgetTester t) async {
      final ResolvedHintTheme indigo = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.branded),
      );
      final ResolvedHintTheme green = await resolveIn(
        t,
        seed: const Color(0xFF2E7D32),
        overrides: const HintThemeData(preset: HintPreset.branded),
      );
      expect(indigo.backgroundColor, isNot(green.backgroundColor));
      expect(indigo.scrimColor, isNot(green.scrimColor));
    });

    testWidgets('contrast inverts with the brightness', (WidgetTester t) async {
      final ResolvedHintTheme light = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.contrast),
      );
      final ResolvedHintTheme dark = await resolveIn(
        t,
        brightness: Brightness.dark,
        overrides: const HintThemeData(preset: HintPreset.contrast),
      );
      expect(light.backgroundColor, const Color(0xFF000000));
      expect(light.foregroundColor, const Color(0xFFFFFFFF));
      expect(dark.backgroundColor, const Color(0xFFFFFFFF));
      expect(dark.foregroundColor, const Color(0xFF000000));
    });
  });

  group('adaptive', () {
    /// Resolves [preset] under a theme pinned to [platform].
    Future<ResolvedHintTheme> onPlatform(
      WidgetTester tester,
      TargetPlatform platform,
      HintPreset preset,
    ) async {
      late ResolvedHintTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            colorSchemeSeed: const Color(0xFF3F51B5),
          ),
          home: Builder(
            builder: (BuildContext context) {
              resolved = HintThemeData.resolve(
                context,
                HintThemeData(preset: preset),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return resolved;
    }

    testWidgets('is cupertino on Apple platforms', (WidgetTester t) async {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        final ResolvedHintTheme adaptive =
            await onPlatform(t, platform, HintPreset.adaptive);
        final ResolvedHintTheme cupertino =
            await onPlatform(t, platform, HintPreset.cupertino);
        expect(adaptive.backgroundColor, cupertino.backgroundColor);
        expect(adaptive.borderRadius, cupertino.borderRadius);
        expect(adaptive.elevation, cupertino.elevation);
      }
    });

    testWidgets('is material everywhere else', (WidgetTester t) async {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        final ResolvedHintTheme adaptive =
            await onPlatform(t, platform, HintPreset.adaptive);
        final ResolvedHintTheme material =
            await onPlatform(t, platform, HintPreset.material);
        expect(adaptive.backgroundColor, material.backgroundColor);
        expect(adaptive.borderRadius, material.borderRadius);
        expect(adaptive.arrowSize, material.arrowSize);
      }
    });

    testWidgets('the two platforms really do differ', (WidgetTester t) async {
      final ResolvedHintTheme ios =
          await onPlatform(t, TargetPlatform.iOS, HintPreset.adaptive);
      final ResolvedHintTheme android =
          await onPlatform(t, TargetPlatform.android, HintPreset.adaptive);
      expect(ios.backgroundColor, isNot(android.backgroundColor));
      expect(ios.borderRadius, isNot(android.borderRadius));
    });
  });

  group('a preset is a starting point', () {
    testWidgets('an explicit field beats the preset', (WidgetTester t) async {
      final ResolvedHintTheme r = await resolveIn(
        t,
        overrides: const HintThemeData(
          preset: HintPreset.soft,
          maxWidth: 360,
        ),
      );
      expect(r.maxWidth, 360);
      // Everything else is still the preset's.
      expect(r.arrowShape, HintArrowShape.curved);
      expect(r.borderRadius, const BorderRadius.all(Radius.circular(18)));
    });

    testWidgets('a preset beats the ColorScheme defaults',
        (WidgetTester t) async {
      final ResolvedHintTheme r = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.sharp),
      );
      expect(r.borderRadius, BorderRadius.zero);
      expect(r.borderWidth, 1);
    });

    testWidgets('an app-wide preset styles hints that set nothing',
        (WidgetTester t) async {
      final ResolvedHintTheme r = await resolveIn(
        t,
        extension: const HintThemeData(preset: HintPreset.card),
      );
      expect(r.elevation, 12);
      expect(r.scrimBlur, 2);
    });

    testWidgets('a per-instance preset replaces the app-wide one',
        (WidgetTester t) async {
      final ResolvedHintTheme r = await resolveIn(
        t,
        extension: const HintThemeData(preset: HintPreset.card),
        overrides: const HintThemeData(preset: HintPreset.sharp),
      );
      expect(r.borderRadius, BorderRadius.zero);
      expect(r.elevation, 2);
    });

    testWidgets('an app-wide field beats the per-instance preset',
        (WidgetTester t) async {
      // The extension's explicit value and the override's preset are both
      // "set", and the merge puts explicit fields above presets either way.
      final ResolvedHintTheme r = await resolveIn(
        t,
        extension: const HintThemeData(maxWidth: 999),
        overrides: const HintThemeData(preset: HintPreset.sharp),
      );
      expect(r.maxWidth, 999);
      expect(r.borderRadius, BorderRadius.zero);
    });

    testWidgets('withoutArrow keeps the preset', (WidgetTester t) async {
      final ResolvedHintTheme r = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.soft),
      );
      final ResolvedHintTheme card = r.withoutArrow();
      expect(card.arrowSize, Size.zero);
      expect(card.borderRadius, const BorderRadius.all(Radius.circular(18)));
      expect(
        card.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
    });
  });

  group('themeData', () {
    testWidgets('hands back editable values', (WidgetTester t) async {
      late HintThemeData data;
      await pumpProbe(t, (BuildContext context) {
        data = HintPreset.card.themeData(context);
      });
      expect(data.elevation, 12);
      expect(data.preset, isNull, reason: 'a finished design, not a reference');

      final HintThemeData mine =
          data.copyWith(backgroundColor: const Color(0xFF10131A));
      expect(mine.backgroundColor, const Color(0xFF10131A));
      expect(mine.elevation, 12);
    });

    testWidgets('matches what setting the preset resolves to',
        (WidgetTester t) async {
      late HintThemeData data;
      await pumpProbe(t, (BuildContext context) {
        data = HintPreset.branded.themeData(context);
      });
      final ResolvedHintTheme viaPreset = await resolveIn(
        t,
        overrides: const HintThemeData(preset: HintPreset.branded),
      );
      final ResolvedHintTheme viaData =
          await resolveIn(t, overrides: data.copyWith());
      expect(viaData.backgroundColor, viaPreset.backgroundColor);
      expect(viaData.borderRadius, viaPreset.borderRadius);
      expect(viaData.scrimColor, viaPreset.scrimColor);
    });
  });

  group('theme data plumbing', () {
    test('merge lets the argument replace the preset', () {
      const HintThemeData a = HintThemeData(preset: HintPreset.card);
      const HintThemeData b = HintThemeData(preset: HintPreset.sharp);
      expect(a.merge(b).preset, HintPreset.sharp);
      expect(a.merge(const HintThemeData()).preset, HintPreset.card);
    });

    test('the preset takes part in equality', () {
      expect(
        const HintThemeData(preset: HintPreset.soft),
        isNot(const HintThemeData(preset: HintPreset.sharp)),
      );
      expect(
        const HintThemeData(preset: HintPreset.soft),
        const HintThemeData(preset: HintPreset.soft),
      );
      expect(
        const HintThemeData(preset: HintPreset.soft).hashCode,
        const HintThemeData(preset: HintPreset.soft).hashCode,
      );
    });

    test('the preset snaps at the halfway point of a lerp', () {
      const HintThemeData a = HintThemeData(preset: HintPreset.soft);
      const HintThemeData b = HintThemeData(preset: HintPreset.sharp);
      expect(a.lerp(b, 0.25).preset, HintPreset.soft);
      expect(a.lerp(b, 0.75).preset, HintPreset.sharp);
    });
  });
}

/// Pumps a bare [MaterialApp] and runs [probe] with a context under it.
Future<void> pumpProbe(
  WidgetTester tester,
  void Function(BuildContext context) probe,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
      home: Builder(
        builder: (BuildContext context) {
          probe(context);
          return const SizedBox();
        },
      ),
    ),
  );
}
