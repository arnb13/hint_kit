import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import 'home_page.dart';

void main() {
  // One place to watch every hint and tour in the app. A real one would send
  // these to your analytics rather than to the console.
  HintRegistry.instance.addObserver(_LoggingObserver());

  // Where `showOnce` keys live. This map is a stand-in for shared_preferences,
  // Hive or your own API: CallbackTourStorage means no subclass and no
  // dependency to swap it for the real thing.
  final Map<String, bool> seen = <String, bool>{};
  HintRegistry.instance.storage = CallbackTourStorage(
    isCompleted: (String key) async => seen[key] ?? false,
    setCompleted: (String key, bool completed) async => seen[key] = completed,
  );

  runApp(const ExampleApp());
}

/// Logs the lifecycle of every hint and tour.
class _LoggingObserver extends HintObserver {
  @override
  void didShowHint(HintEvent event) =>
      debugPrint('hint shown: ${event.id ?? event.label} (${event.trigger})');

  @override
  void didDismissHint(HintEvent event) =>
      debugPrint('hint dismissed: ${event.id ?? event.label}');

  @override
  void didEndTour(String tour, TourEndReason reason) =>
      debugPrint('observer saw tour $tour end: ${reason.name}');
}

/// Demonstrates every part of hint_kit in one screen plus a second route.
///
/// This file holds the app-wide wiring only — the [TourScope], the theme and
/// the settings the app bar toggles. The screen itself is [HomePage], and each
/// feature it shows lives in its own file under `lib/sections/`.
///
/// The tour deliberately spans both routes: step 4 lives on the details page,
/// which is the case `tutorial_coach_mark` and friends cannot handle.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> with WidgetsBindingObserver {
  final TourController _tour = TourController(
    // Swap this for a storage backed by shared_preferences, Hive, your API —
    // anything implementing TourStorage. The default forgets on restart, which
    // is convenient while you are building the tour and wrong in production.
    storage: InMemoryTourStorage(),
    onStepChanged: (String tour, int index) =>
        debugPrint('tour $tour reached step ${index + 1}'),
    onEnd: (String tour, TourEndReason reason) =>
        debugPrint('tour $tour ended: ${reason.name}'),
  );

  bool _dark = false;
  bool _onShift = false;
  bool _curvedArrows = false;
  bool _french = false;
  bool _highContrast = false;

  /// How dark the tour scrim is, and what colour it is tinted.
  ///
  /// Two independent settings: [HintThemeData.scrimOpacity] replaces the alpha
  /// of whatever colour is in play, so the slider works whether the tint below
  /// is set or not.
  double _scrimOpacity = 0.9;
  Color? _scrimTint;

  /// The app-wide design. `null` means "no preset": the package's own
  /// ColorScheme-derived defaults, plus the two overrides in [_theme].
  HintPreset? _preset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tour.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The real case resuming exists for: an onboarding the user walked away
    // from. `cancel` stops the tour without marking it complete, so its
    // position survives and the play button picks it up again.
    if (state == AppLifecycleState.paused && _tour.isRunning) {
      _tour.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TourScope(
      controller: _tour,
      // Declared so the card says "1 of 4" from the start, even though the
      // fourth target lives on a route that has not been pushed yet.
      tourLengths: const <String, int>{'onboarding': 4},
      // Every word on the step card is a value, so the tour speaks whatever
      // language the app does. The counter is a callback because word order
      // is not universal.
      labels: _french
          ? TourLabels(
              skip: 'Passer',
              back: 'Retour',
              next: 'Suivant',
              done: 'Terminé',
              progress: (int step, int length) => 'Étape $step sur $length',
            )
          : const TourLabels(),
      child: MaterialApp(
        title: 'hint_kit',
        debugShowCheckedModeBanner: false,
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        // Real apps read this from the platform. Overriding it here is the
        // only way to demonstrate followHighContrast without changing an OS
        // setting mid-demo.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: _highContrast),
          child: child ?? const SizedBox(),
        ),
        home: HomePage(
          onToggleTheme: () => setState(() => _dark = !_dark),
          onToggleShift: () => setState(() => _onShift = !_onShift),
          onToggleArrow: () => setState(() => _curvedArrows = !_curvedArrows),
          onPresetChanged: (HintPreset? preset) =>
              setState(() => _preset = preset),
          onToggleLanguage: () => setState(() => _french = !_french),
          onToggleContrast: () =>
              setState(() => _highContrast = !_highContrast),
          onScrimOpacityChanged: (double value) =>
              setState(() => _scrimOpacity = value),
          onScrimTintChanged: (Color? value) =>
              setState(() => _scrimTint = value),
          scrimOpacity: _scrimOpacity,
          scrimTint: _scrimTint,
          french: _french,
          highContrast: _highContrast,
          onShift: _onShift,
          isDark: _dark,
          curvedArrows: _curvedArrows,
          preset: _preset,
        ),
      ),
    );
  }

  /// The whole package is themed from one [ThemeExtension].
  ///
  /// Flipping [_curvedArrows] or picking a [_preset] here restyles every
  /// tooltip, hint, beacon and tour card in the app at once — that is the
  /// point of theming all three features from one place.
  ///
  /// Note how the two layers compose: [_preset] supplies a whole design, and
  /// the fields set beside it win over that design. The caret is set only when
  /// the toggle is on, so an unset caret is left for the preset to decide.
  ThemeData _theme(Brightness brightness) => ThemeData(
        brightness: brightness,
        colorSchemeSeed: const Color(0xFF3F51B5),
        extensions: <ThemeExtension<dynamic>>[
          HintThemeData(
            preset: _preset,
            // Swaps in the contrast design when the platform asks for it. The
            // toggle below fakes the platform flag so it can be seen here.
            followHighContrast: true,
            // The tour dim: a colour and, independently, how opaque it is.
            scrimColor: _scrimTint,
            scrimOpacity: _scrimOpacity,
            arrowShape: _curvedArrows ? HintArrowShape.curved : null,
            // A curved caret needs some size before the curve reads at all.
            arrowSize: _curvedArrows ? const Size(24, 13) : null,
          ),
        ],
      );
}
