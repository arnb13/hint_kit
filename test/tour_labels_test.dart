import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hint_kit/hint_kit.dart';

/// A two-step tour, optionally with localised labels.
Widget twoStepApp({
  required TourController controller,
  TourLabels labels = const TourLabels(),
  TourStepBuilder? contentBuilder,
}) {
  return TourScope(
    controller: controller,
    labels: labels,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            HintTarget(
              tour: 'onboarding',
              order: 1,
              title: 'One',
              contentBuilder: contentBuilder,
              child: const SizedBox(key: Key('one'), width: 80, height: 40),
            ),
            HintTarget(
              tour: 'onboarding',
              order: 2,
              title: 'Two',
              contentBuilder: contentBuilder,
              child: const SizedBox(key: Key('two'), width: 80, height: 40),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('default labels', () {
    testWidgets('are English', (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(twoStepApp(controller: tour));
      await tour.start('onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Back'), findsNothing);

      tour.next();
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });
  });

  group('localised labels', () {
    testWidgets('replace every word on the card', (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        twoStepApp(
          controller: tour,
          labels: const TourLabels(
            skip: 'Passer',
            back: 'Retour',
            next: 'Suivant',
            done: 'Terminé',
          ),
        ),
      );
      await tour.start('onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Passer'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsNothing);

      tour.next();
      await tester.pumpAndSettle();
      expect(find.text('Retour'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('the counter is a callback, so word order is free',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        twoStepApp(
          controller: tour,
          labels: TourLabels(
            progress: (int step, int length) => 'Étape $step sur $length',
          ),
        ),
      );
      await tour.start('onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 2'), findsOneWidget);
      expect(find.text('1 of 2'), findsNothing);
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('reach a custom card through TourStepInfo',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        twoStepApp(
          controller: tour,
          labels: const TourLabels(next: 'Weiter'),
          contentBuilder: (BuildContext context, TourStepInfo info) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(info.title ?? ''),
              TextButton(
                onPressed: info.controller.next,
                child: Text(info.labels.advance(isLast: info.isLast)),
              ),
            ],
          ),
        ),
      );
      await tour.start('onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Weiter'), findsOneWidget);
      tour.skip();
      await tester.pumpAndSettle();
    });
  });

  group('TourLabels', () {
    test('advance picks done on the last step', () {
      const TourLabels labels = TourLabels(next: 'N', done: 'D');
      expect(labels.advance(isLast: false), 'N');
      expect(labels.advance(isLast: true), 'D');
    });

    test('the default counter reads "2 of 5"', () {
      expect(const TourLabels().progress(2, 5), '2 of 5');
    });

    test('copyWith replaces only what it is given', () {
      const TourLabels base = TourLabels(skip: 'S', next: 'N');
      final TourLabels copy = base.copyWith(next: 'X');
      expect(copy.skip, 'S');
      expect(copy.next, 'X');
    });

    test('identical label sets compare equal', () {
      expect(const TourLabels(), const TourLabels());
      expect(
        const TourLabels(skip: 'S'),
        isNot(const TourLabels(skip: 'T')),
      );
      expect(const TourLabels().hashCode, const TourLabels().hashCode);
    });
  });

  group('spotlight travel', () {
    testWidgets('moves from the previous step rather than cutting',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(twoStepApp(controller: tour));
      await tour.start('onboarding');
      await tester.pumpAndSettle();

      final Rect first = tester.getRect(find.byKey(const Key('one')));
      tour.next();
      // Part-way through the move the hole is between the two targets, so the
      // second step's spotlight cannot already be at its destination.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final Iterable<Spotlight> lights =
          tester.widgetList<Spotlight>(find.byType(Spotlight));
      final Rect second = tester.getRect(find.byKey(const Key('two')));
      // The active step's spotlight is the one that is travelling: its hole is
      // still nearer the first target than the second.
      final bool travelling = lights.any(
        (Spotlight s) =>
            s.holeRect.center.dy > first.center.dy &&
            s.holeRect.center.dy < second.center.dy,
      );
      expect(travelling, isTrue, reason: 'the spotlight should be in transit');

      await tester.pumpAndSettle();
      final Iterable<Spotlight> arrived =
          tester.widgetList<Spotlight>(find.byType(Spotlight));
      expect(
        arrived.any(
          (Spotlight s) => (s.holeRect.center.dy - second.center.dy).abs() < 1,
        ),
        isTrue,
      );
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('a zero duration cuts straight to the target',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(
        TourScope(
          controller: tour,
          theme: const HintThemeData(spotlightMoveDuration: Duration.zero),
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  HintTarget(
                    tour: 'onboarding',
                    order: 1,
                    title: 'One',
                    child: SizedBox(key: Key('one'), width: 80, height: 40),
                  ),
                  HintTarget(
                    tour: 'onboarding',
                    order: 2,
                    title: 'Two',
                    child: SizedBox(key: Key('two'), width: 80, height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tour.start('onboarding');
      await tester.pumpAndSettle();
      tour.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final Rect second = tester.getRect(find.byKey(const Key('two')));
      final Iterable<Spotlight> lights =
          tester.widgetList<Spotlight>(find.byType(Spotlight));
      expect(
        lights.any(
          (Spotlight s) => (s.holeRect.center.dy - second.center.dy).abs() < 1,
        ),
        isTrue,
      );
      tour.skip();
      await tester.pumpAndSettle();
    });

    testWidgets('the first step of a tour does not travel',
        (WidgetTester tester) async {
      final TourController tour = TourController();
      addTearDown(tour.dispose);
      await tester.pumpWidget(twoStepApp(controller: tour));
      await tour.start('onboarding');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final Rect first = tester.getRect(find.byKey(const Key('one')));
      final Iterable<Spotlight> lights =
          tester.widgetList<Spotlight>(find.byType(Spotlight));
      expect(
        lights.any(
          (Spotlight s) => (s.holeRect.center.dy - first.center.dy).abs() < 1,
        ),
        isTrue,
      );
      tour.skip();
      await tester.pumpAndSettle();
    });
  });
}
