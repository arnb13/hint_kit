import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// Pumps a probe widget under a [MaterialApp] with the given theme and hands
/// the resolved hint theme to [onResolved].
Future<void> pumpResolved(
  WidgetTester tester, {
  required void Function(ResolvedHintTheme theme) onResolved,
  Brightness brightness = Brightness.light,
  HintThemeData? extension,
  HintThemeData? overrides,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: <ThemeExtension<dynamic>>[
          if (extension != null) extension,
        ],
      ),
      home: Builder(
        builder: (BuildContext context) {
          onResolved(HintThemeData.resolve(context, overrides));
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  group('copyWith', () {
    test('replaces only the named fields', () {
      const HintThemeData base = HintThemeData(
        backgroundColor: Color(0xFF111111),
        gap: 10,
        maxWidth: 200,
      );
      final HintThemeData copy = base.copyWith(gap: 20);
      expect(copy.gap, 20);
      expect(copy.backgroundColor, const Color(0xFF111111));
      expect(copy.maxWidth, 200);
    });

    test('an empty copyWith is a no-op', () {
      const HintThemeData base = HintThemeData(
        backgroundColor: Color(0xFF111111),
        borderWidth: 2,
        padding: EdgeInsets.all(4),
        arrowSize: Size(10, 5),
        transitionCurve: Curves.linear,
        scrimBlur: 3,
      );
      expect(base.copyWith(), base);
    });

    test('covers every field', () {
      const HintThemeData empty = HintThemeData();
      final HintThemeData full = empty.copyWith(
        backgroundColor: const Color(0xFF000001),
        foregroundColor: const Color(0xFF000002),
        borderColor: const Color(0xFF000003),
        borderWidth: 1,
        borderRadius: BorderRadius.circular(2),
        elevation: 3,
        shadowColor: const Color(0xFF000004),
        padding: const EdgeInsets.all(4),
        arrowSize: const Size(5, 6),
        arrowInset: 7,
        gap: 8,
        screenMargin: const EdgeInsets.all(9),
        maxWidth: 10,
        titleStyle: const TextStyle(fontSize: 11),
        messageStyle: const TextStyle(fontSize: 12),
        transitionDuration: const Duration(milliseconds: 13),
        reverseTransitionDuration: const Duration(milliseconds: 14),
        transitionCurve: Curves.bounceIn,
        scrimColor: const Color(0xFF000005),
        scrimBlur: 15,
        spotlightBorderRadius: BorderRadius.circular(16),
        spotlightPadding: const EdgeInsets.all(17),
      );
      // If a field were dropped from copyWith it would still be null here.
      expect(full.backgroundColor, const Color(0xFF000001));
      expect(full.foregroundColor, const Color(0xFF000002));
      expect(full.borderColor, const Color(0xFF000003));
      expect(full.borderWidth, 1);
      expect(full.borderRadius, BorderRadius.circular(2));
      expect(full.elevation, 3);
      expect(full.shadowColor, const Color(0xFF000004));
      expect(full.padding, const EdgeInsets.all(4));
      expect(full.arrowSize, const Size(5, 6));
      expect(full.arrowInset, 7);
      expect(full.gap, 8);
      expect(full.screenMargin, const EdgeInsets.all(9));
      expect(full.maxWidth, 10);
      expect(full.titleStyle?.fontSize, 11);
      expect(full.messageStyle?.fontSize, 12);
      expect(full.transitionDuration, const Duration(milliseconds: 13));
      expect(full.reverseTransitionDuration, const Duration(milliseconds: 14));
      expect(full.transitionCurve, Curves.bounceIn);
      expect(full.scrimColor, const Color(0xFF000005));
      expect(full.scrimBlur, 15);
      expect(full.spotlightBorderRadius, BorderRadius.circular(16));
      expect(full.spotlightPadding, const EdgeInsets.all(17));
    });
  });

  group('lerp', () {
    const HintThemeData a = HintThemeData(
      backgroundColor: Color(0xFF000000),
      gap: 0,
      padding: EdgeInsets.zero,
      arrowSize: Size.zero,
      transitionDuration: Duration(milliseconds: 100),
      transitionCurve: Curves.linear,
      borderRadius: BorderRadius.zero,
      scrimBlur: 0,
    );
    const HintThemeData b = HintThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      gap: 20,
      padding: EdgeInsets.all(10),
      arrowSize: Size(20, 10),
      transitionDuration: Duration(milliseconds: 300),
      transitionCurve: Curves.bounceIn,
      borderRadius: BorderRadius.all(Radius.circular(10)),
      scrimBlur: 8,
    );

    test('t=0 returns the start value', () {
      final HintThemeData l = a.lerp(b, 0);
      expect(l.gap, 0);
      expect(l.padding, EdgeInsets.zero);
      expect(l.backgroundColor, const Color(0xFF000000));
    });

    test('t=1 returns the end value', () {
      final HintThemeData l = a.lerp(b, 1);
      expect(l.gap, 20);
      expect(l.padding, const EdgeInsets.all(10));
      expect(l.backgroundColor, const Color(0xFFFFFFFF));
    });

    test('t=0.5 interpolates continuous fields', () {
      final HintThemeData l = a.lerp(b, 0.5);
      expect(l.gap, 10);
      expect(l.padding, const EdgeInsets.all(5));
      expect(l.arrowSize, const Size(10, 5));
      expect(l.scrimBlur, 4);
      expect(l.borderRadius, BorderRadius.circular(5));
    });

    test('discrete fields snap at the halfway point', () {
      expect(a.lerp(b, 0.49).transitionCurve, Curves.linear);
      expect(a.lerp(b, 0.51).transitionCurve, Curves.bounceIn);
      expect(
        a.lerp(b, 0.49).transitionDuration,
        const Duration(milliseconds: 100),
      );
      expect(
        a.lerp(b, 0.51).transitionDuration,
        const Duration(milliseconds: 300),
      );
    });

    test('lerping against null returns this', () {
      expect(a.lerp(null, 0.5), a);
    });

    test('a null field on one side does not become NaN', () {
      const HintThemeData sparse = HintThemeData(gap: 4);
      final HintThemeData l = sparse.lerp(const HintThemeData(), 0.5);
      expect(l.gap, 4);
      expect(l.maxWidth, isNull);
    });

    test('is usable by ThemeData.lerp', () {
      final ThemeData lerped = ThemeData.lerp(
        ThemeData(extensions: const <ThemeExtension<dynamic>>[a]),
        ThemeData(extensions: const <ThemeExtension<dynamic>>[b]),
        0.5,
      );
      expect(lerped.extension<HintThemeData>()?.gap, 10);
    });
  });

  group('equality', () {
    test('identical field sets compare equal', () {
      const HintThemeData x = HintThemeData(gap: 4, maxWidth: 100);
      const HintThemeData y = HintThemeData(gap: 4, maxWidth: 100);
      expect(x, y);
      expect(x.hashCode, y.hashCode);
    });

    test('a single differing field breaks equality', () {
      const HintThemeData x = HintThemeData(gap: 4);
      const HintThemeData y = HintThemeData(gap: 5);
      expect(x, isNot(y));
    });

    test('toString names its set fields', () {
      const HintThemeData x = HintThemeData(gap: 4);
      expect(x.toString(), contains('gap'));
    });
  });

  group('merge', () {
    test('non-null fields of the argument win', () {
      const HintThemeData base = HintThemeData(gap: 4, maxWidth: 100);
      const HintThemeData over = HintThemeData(gap: 9);
      final HintThemeData merged = base.merge(over);
      expect(merged.gap, 9);
      expect(merged.maxWidth, 100);
    });

    test('merging null is a no-op', () {
      const HintThemeData base = HintThemeData(gap: 4);
      expect(base.merge(null), base);
    });
  });

  group('resolution order', () {
    testWidgets('falls back to ColorScheme defaults', (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      late ColorScheme scheme;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              scheme = Theme.of(context).colorScheme;
              resolved = HintThemeData.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved.backgroundColor, scheme.inverseSurface);
      expect(resolved.foregroundColor, scheme.onInverseSurface);
      expect(resolved.maxWidth, 280);
      expect(resolved.gap, resolved.arrowSize.height + 4);
    });

    testWidgets('the theme extension beats the defaults',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        extension: const HintThemeData(backgroundColor: Color(0xFF123456)),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.backgroundColor, const Color(0xFF123456));
      // Unset fields still come from the defaults.
      expect(resolved.maxWidth, 280);
    });

    testWidgets('the per-instance override beats the extension',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        extension: const HintThemeData(
          backgroundColor: Color(0xFF123456),
          maxWidth: 111,
        ),
        overrides: const HintThemeData(backgroundColor: Color(0xFFABCDEF)),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.backgroundColor, const Color(0xFFABCDEF));
      // Merging is per-field: the extension still supplies maxWidth.
      expect(resolved.maxWidth, 111);
    });

    testWidgets('an override alone still resolves', (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        overrides: const HintThemeData(gap: 42),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.gap, 42);
    });
  });

  group('derived defaults', () {
    testWidgets('read as a raised surface in light mode',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.isDark, isFalse);
      expect(
        resolved.backgroundColor.computeLuminance(),
        lessThan(resolved.foregroundColor.computeLuminance()),
        reason: 'light mode should give a dark bubble with light text',
      );
    });

    testWidgets('invert in dark mode', (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        brightness: Brightness.dark,
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.isDark, isTrue);
      expect(
        resolved.backgroundColor.computeLuminance(),
        greaterThan(resolved.foregroundColor.computeLuminance()),
        reason: 'dark mode should give a light bubble with dark text',
      );
    });

    testWidgets('text styles inherit the foreground colour',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.titleStyle.color, resolved.foregroundColor);
      expect(resolved.messageStyle.color, resolved.foregroundColor);
    });

    testWidgets('an explicit text colour is not overwritten',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        overrides: const HintThemeData(
          messageStyle: TextStyle(color: Color(0xFF00FF00)),
        ),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.messageStyle.color, const Color(0xFF00FF00));
    });

    testWidgets('arrowInset clears the corner radius', (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        overrides: const HintThemeData(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          arrowSize: Size(16, 8),
        ),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.arrowInset, 20 + 8);
    });

    testWidgets('an explicit arrowInset wins', (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        overrides: const HintThemeData(arrowInset: 3),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(resolved.arrowInset, 3);
    });

    testWidgets('reverse duration falls back to the forward one',
        (WidgetTester t) async {
      late ResolvedHintTheme resolved;
      await pumpResolved(
        t,
        overrides: const HintThemeData(
          transitionDuration: Duration(milliseconds: 400),
        ),
        onResolved: (ResolvedHintTheme r) => resolved = r,
      );
      expect(
        resolved.reverseTransitionDuration,
        const Duration(milliseconds: 400),
      );
    });
  });
}
