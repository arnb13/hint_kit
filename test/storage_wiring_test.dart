import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';
import 'package:hint_kit/testing.dart';

/// Collects what the package says on [debugPrint] while [body] runs.
Future<List<String>> captureDebugPrint(Future<void> Function() body) async {
  final List<String> lines = <String>[];
  final DebugPrintCallback original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      lines.add(message);
    }
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return lines;
}

/// Whether the package complained about half-wired persistence.
bool complained(List<String> lines) =>
    lines.any((String line) => line.contains('one of its two places'));

void main() {
  setUp(resetHintKit);

  group('the two-places check', () {
    testWidgets('a tour on default storage, with the registry set, is told',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);

      final List<String> said = await captureDebugPrint(() async {
        HintRegistry.instance.storage = InMemoryTourStorage();
        await controller.start('onboarding');
      });

      expect(complained(said), isTrue);
      expect(
        said.join('\n'),
        contains('TourScope(storage:'),
        reason: 'the message should name the line that fixes it',
      );
    });

    testWidgets(
        'showOnce on default registry, with a tour storage set, is told',
        (WidgetTester tester) async {
      final List<String> said = await captureDebugPrint(() async {
        // Constructing the controller is what records the explicit choice.
        final TourController controller =
            TourController(storage: InMemoryTourStorage());
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          const MaterialApp(
            home: Hint(
              showOnce: 'whats-new',
              message: 'Only once',
              child: Text('target'),
            ),
          ),
        );
        await tester.pump();
      });

      expect(complained(said), isTrue);
      expect(said.join('\n'), contains('HintRegistry.instance.storage ='));
    });

    testWidgets('wiring both says nothing', (WidgetTester tester) async {
      final TourStorage shared = InMemoryTourStorage();
      final TourController controller = TourController(storage: shared);
      addTearDown(controller.dispose);

      final List<String> said = await captureDebugPrint(() async {
        HintRegistry.instance.storage = shared;
        await controller.start('onboarding');
      });

      expect(complained(said), isFalse);
    });

    testWidgets('wiring neither says nothing', (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);

      final List<String> said = await captureDebugPrint(() async {
        await controller.start('onboarding');
      });

      expect(complained(said), isFalse);
    });

    testWidgets('an explicit in-memory storage is a decision, not an oversight',
        (WidgetTester tester) async {
      // The deliberate case: showOnce persists, tours are meant to replay.
      final TourController controller =
          TourController(storage: InMemoryTourStorage());
      addTearDown(controller.dispose);

      final List<String> said = await captureDebugPrint(() async {
        HintRegistry.instance.storage = InMemoryTourStorage();
        await controller.start('onboarding');
      });

      expect(complained(said), isFalse);
    });

    testWidgets('it is said once, not on every tour',
        (WidgetTester tester) async {
      final TourController controller = TourController();
      addTearDown(controller.dispose);

      final List<String> said = await captureDebugPrint(() async {
        HintRegistry.instance.storage = InMemoryTourStorage();
        await controller.start('one');
        controller.cancel();
        await controller.start('two');
        controller.cancel();
        await controller.start('three');
      });

      expect(
        said.where((String line) => line.contains('one of its two places')),
        hasLength(1),
      );
    });
  });
}
