@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

import 'support/bubble_harness.dart';

/// Pixel comparisons for the fused bubble-and-arrow path.
///
/// Goldens only match on the platform and Flutter version that produced them,
/// so this file is tagged and CI runs `flutter test --exclude-tags golden`.
/// Locally they are the only regression net the arrow geometry has: run
/// `flutter test` before a PR, and `flutter test --update-goldens` when the
/// path changes on purpose.
void main() {
  group('goldens', () {
    for (final HintSide side in HintSide.values) {
      testWidgets('bubble on ${side.name}', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              // Room for the arrow to overhang in any direction.
              padding: const EdgeInsets.all(16),
              child: bubble(side: side, title: 'Check in'),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/bubble_${side.name}.png'),
        );
      });
    }

    testWidgets('bubble with an off-centre arrow', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(side: HintSide.top, arrowFraction: 0.12),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_arrow_offset.png'),
      );
    });

    testWidgets('bubble with a border and a large radius',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(
              side: HintSide.bottom,
              theme: const HintThemeData(
                backgroundColor: Color(0xFFFFFFFF),
                foregroundColor: Color(0xFF1A1A1A),
                borderColor: Color(0xFF6750A4),
                borderWidth: 2,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                arrowSize: Size(18, 9),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_bordered.png'),
      );
    });

    for (final HintSide side in HintSide.values) {
      testWidgets('curved arrow on ${side.name}', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              padding: const EdgeInsets.all(20),
              child: bubble(
                side: side,
                title: 'Check in',
                theme: const HintThemeData(
                  arrowShape: HintArrowShape.curved,
                  arrowSize: Size(24, 14),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/bubble_curved_${side.name}.png'),
        );
      });
    }

    testWidgets('curved arrow with a border', (WidgetTester tester) async {
      // The border is where the join shows: a crease between caret and body
      // would be plainly visible along the stroke.
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(20),
            child: bubble(
              side: HintSide.top,
              theme: const HintThemeData(
                arrowShape: HintArrowShape.curved,
                arrowSize: Size(26, 15),
                backgroundColor: Color(0xFFFFFFFF),
                foregroundColor: Color(0xFF1A1A1A),
                borderColor: Color(0xFF6750A4),
                borderWidth: 2,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_curved_bordered.png'),
      );
    });

    testWidgets('bubble in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(side: HintSide.bottom, title: 'Check in'),
          ),
          brightness: Brightness.dark,
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_dark.png'),
      );
    });
  });

  group('a custom arrow', () {
    testWidgets('a themed builder reaches the painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(16),
            child: bubble(
              side: HintSide.top,
              theme: const HintThemeData(
                arrowShape: HintArrowShape.custom,
                arrowSize: Size(24, 12),
                arrowBuilder: bluntArrow,
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/bubble_custom_arrow.png'),
      );
    });
  });

  group('preset goldens', () {
    // Seven designs and no regression net would mean a wrong radius or arrow
    // inset in one of them could ship unnoticed.
    for (final HintPreset preset in HintPreset.values) {
      testWidgets('${preset.name} looks right', (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Padding(
              padding: const EdgeInsets.all(20),
              child: bubble(
                side: HintSide.top,
                title: 'Check in',
                theme: HintThemeData(preset: preset),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(HintBubbleDecoration),
          matchesGoldenFile('goldens/preset_${preset.name}.png'),
        );
      });
    }

    testWidgets('card in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Padding(
            padding: const EdgeInsets.all(20),
            child: bubble(
              side: HintSide.top,
              title: 'Check in',
              theme: const HintThemeData(preset: HintPreset.card),
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await expectLater(
        find.byType(HintBubbleDecoration),
        matchesGoldenFile('goldens/preset_card_dark.png'),
      );
    });
  });
}
