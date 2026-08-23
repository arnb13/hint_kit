import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

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
/// The tour deliberately spans both: step 4 lives on the details page, which
/// is the case `tutorial_coach_mark` and friends cannot handle.
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

class HomePage extends StatefulWidget {
  const HomePage({
    required this.onToggleTheme,
    required this.onToggleShift,
    required this.onToggleArrow,
    required this.onPresetChanged,
    required this.onToggleLanguage,
    required this.onToggleContrast,
    required this.onScrimOpacityChanged,
    required this.onScrimTintChanged,
    required this.scrimOpacity,
    required this.scrimTint,
    required this.french,
    required this.highContrast,
    required this.onShift,
    required this.isDark,
    required this.curvedArrows,
    required this.preset,
    super.key,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onToggleShift;
  final VoidCallback onToggleArrow;
  final ValueChanged<HintPreset?> onPresetChanged;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleContrast;
  final ValueChanged<double> onScrimOpacityChanged;
  final ValueChanged<Color?> onScrimTintChanged;

  /// How dark the tour scrim is, 0 to 1.
  final double scrimOpacity;

  /// The tour scrim's tint, or null for the default neutral black.
  final Color? scrimTint;

  /// Whether the app is pretending the platform asked for high contrast.
  final bool highContrast;

  /// Whether the tour card speaks French.
  final bool french;
  final bool onShift;
  final bool isDark;
  final bool curvedArrows;

  /// The app-wide design, or `null` for the package defaults.
  final HintPreset? preset;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HintController _savedHint = HintController();
  final HintController _onceHint = HintController();

  /// Three tips shown one after another by [_tipQueue].
  final List<HintController> _tips =
      List<HintController>.generate(3, (_) => HintController());
  late final HintQueue _tipQueue = HintQueue(_tips);
  final ScrollController _scroll = ScrollController();

  /// Whether the panel that tour step 3 points at is expanded.
  bool _panelOpen = false;

  @override
  void dispose() {
    _savedHint.dispose();
    _onceHint.dispose();
    _tipQueue.dispose();
    for (final HintController tip in _tips) {
      tip.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('hint_kit'),
        actions: <Widget>[
          Hint(
            message: widget.isDark ? 'Switch to light' : 'Switch to dark',
            triggers: const <HintTrigger>{
              HintTrigger.hover,
              HintTrigger.longPress,
            },
            waitDuration: const Duration(milliseconds: 300),
            child: IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            ),
          ),
          // Restyles the caret on every bubble in the app at once.
          Hint(
            message: widget.curvedArrows
                ? 'Switch to a straight caret'
                : 'Switch to a curved caret — look at this bubble',
            triggers: const <HintTrigger>{
              HintTrigger.hover,
              HintTrigger.longPress,
            },
            waitDuration: const Duration(milliseconds: 300),
            child: IconButton(
              onPressed: widget.onToggleArrow,
              icon: Icon(
                widget.curvedArrows ? Icons.bubble_chart : Icons.change_history,
              ),
            ),
          ),
          // Pretends the platform asked for high contrast, which the theme's
          // followHighContrast flag turns into the contrast design.
          Hint(
            message: widget.highContrast
                ? 'Back to the normal design'
                : 'Pretend the platform wants high contrast',
            triggers: const <HintTrigger>{
              HintTrigger.hover,
              HintTrigger.longPress,
            },
            waitDuration: const Duration(milliseconds: 300),
            child: IconButton(
              onPressed: widget.onToggleContrast,
              icon: Icon(
                widget.highContrast ? Icons.contrast : Icons.contrast_outlined,
              ),
            ),
          ),
          // The tour's own words, swapped wholesale. Start the tour after
          // pressing this and the card reads Passer / Retour / Suivant.
          Hint(
            message: widget.french
                ? 'Le tour parle français — revenir à l’anglais'
                : 'Make the tour speak French (TourLabels)',
            triggers: const <HintTrigger>{
              HintTrigger.hover,
              HintTrigger.longPress,
            },
            waitDuration: const Duration(milliseconds: 300),
            child: IconButton(
              onPressed: widget.onToggleLanguage,
              icon: Icon(
                widget.french ? Icons.translate : Icons.language_outlined,
              ),
            ),
          ),
          // One design for every bubble, card and spotlight in the app.
          PopupMenuButton<HintPreset?>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'App-wide design',
            initialValue: widget.preset,
            onSelected: widget.onPresetChanged,
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<HintPreset?>>[
              const PopupMenuItem<HintPreset?>(
                child: Text('none (package defaults)'),
              ),
              for (final HintPreset preset in HintPreset.values)
                PopupMenuItem<HintPreset?>(
                  value: preset,
                  child: Text(preset.name),
                ),
            ],
          ),
          // Step 1 of the tour.
          HintTarget(
            tour: 'onboarding',
            order: 1,
            title: 'Start here',
            description:
                'This button replays the tour whenever you want to see it '
                'again.',
            spotlight: SpotlightShape.circle,
            child: IconButton(
              onPressed: () =>
                  Tour.read(context).start('onboarding', force: true),
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Replay tour',
            ),
          ),
        ],
      ),
      // A SingleChildScrollView, not a ListView: every tour target below the
      // fold is built even while off screen, which is what lets the tour
      // scroll to step 3. A lazily-built target that has never existed cannot
      // be scrolled to - see "Known limitations" in the README.
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _SectionHeader(
              title: 'Hints on disabled widgets',
              body: 'The reason this package exists. Long-press the disabled '
                  'button: it still explains itself, because triggers are read '
                  'from raw pointer events rather than the gesture arena.',
            ),
            Row(
              children: <Widget>[
                // The headline case: a hint on a disabled control.
                Hint(
                  message: widget.onShift
                      ? 'Tap to check in for your shift'
                      : 'You need an active shift to check in',
                  direction: HintDirection.bottom,
                  child: ElevatedButton.icon(
                    onPressed: widget.onShift ? () {} : null,
                    icon: const Icon(Icons.login),
                    label: const Text('Check in'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: widget.onToggleShift,
                  child: Text(
                    widget.onShift ? 'End shift' : 'Start shift',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.onShift
                  ? 'The button is enabled — its own tap still works, and the '
                      'hint still opens on a long press.'
                  : 'The button is disabled — the hint still opens.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const _SectionHeader(
              title: 'Programmatic hints',
              body: 'A HintController opens a bubble from code: a save '
                  'confirmation, a validation failure, a nudge.',
            ),
            Row(
              children: <Widget>[
                Hint(
                  controller: _savedHint,
                  triggers: const <HintTrigger>{HintTrigger.manual},
                  message: 'Saved to your device',
                  showDuration: const Duration(seconds: 2),
                  dismissOnTapOutside: false,
                  direction: HintDirection.top,
                  child: FilledButton(
                    onPressed: _savedHint.show,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                // Step 2 of the tour, with a real tap required to advance.
                HintTarget(
                  tour: 'onboarding',
                  order: 2,
                  title: 'Try it yourself',
                  description:
                      'This step is passthrough: the scrim lets a real tap '
                      'reach the button. Press it to continue.',
                  passthrough: true,
                  pulse: true,
                  child: Builder(
                    builder: (BuildContext context) => FilledButton.tonal(
                      onPressed: () {
                        _savedHint.show();
                        Tour.read(context).next();
                      },
                      child: const Text('Press me'),
                    ),
                  ),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'Rich, interactive tooltips',
              body: 'Arbitrary widgets inside the bubble. Hovering from the '
                  'target into the bubble does not dismiss it, so the link is '
                  'actually clickable.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Hint(
                interactive: true,
                triggers: const <HintTrigger>{
                  HintTrigger.hover,
                  HintTrigger.tap,
                },
                direction: HintDirection.right,
                contentBuilder: (BuildContext context) => _PayslipCard(),
                child: const Chip(
                  avatar: Icon(Icons.receipt_long, size: 18),
                  label: Text('Payslip #4821'),
                ),
              ),
            ),
            const _SectionHeader(
              title: 'Ready-made designs',
              body: 'Tap a chip to see that preset. The menu in the app bar '
                  'applies one to the whole app instead — bubbles, tour cards '
                  'and spotlights together.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final HintPreset preset in HintPreset.values)
                  Hint(
                    // A design for this hint only. Everything the preset does
                    // not set still comes from the app theme.
                    theme: HintThemeData(preset: preset),
                    title: preset.name,
                    message: _presetBlurb[preset],
                    triggers: const <HintTrigger>{HintTrigger.tap},
                    child: Chip(label: Text(preset.name)),
                  ),
                // Not a preset at all: a design of your own, started from one.
                Builder(
                  builder: (BuildContext context) => Hint(
                    theme: HintPreset.card.themeData(context).copyWith(
                          backgroundColor: const Color(0xFF10131A),
                          foregroundColor: const Color(0xFFE7ECF5),
                          borderColor: const Color(0xFF3D7BFF),
                          borderWidth: 1.5,
                          arrowShape: HintArrowShape.curved,
                          arrowSize: const Size(22, 12),
                        ),
                    title: 'custom',
                    message: 'HintPreset.card.themeData(context) gives you the '
                        'preset as plain data — edit it like any other '
                        'HintThemeData, or build one from scratch.',
                    triggers: const <HintTrigger>{HintTrigger.tap},
                    child: const Chip(
                      avatar: Icon(Icons.brush, size: 18),
                      label: Text('custom'),
                    ),
                  ),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'Animations',
              body: 'Five ready-made transitions, and a builder for anything '
                  'else. Presets carry their own motion, so picking a design '
                  'picks how it arrives too.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final HintTransition transition in HintTransition.values)
                  Hint(
                    theme: HintThemeData(
                      transition: transition,
                      // Long enough that the difference is actually visible.
                      transitionDuration: const Duration(milliseconds: 320),
                    ),
                    message: _transitionBlurb[transition],
                    triggers: const <HintTrigger>{HintTrigger.tap},
                    showDuration: const Duration(seconds: 2),
                    child: Chip(label: Text(transition.name)),
                  ),
                // An animation of your own: the builder is handed the curved
                // animation, a clamped one for opacity, and where the caret is.
                Hint(
                  theme: HintThemeData(
                    transitionDuration: const Duration(milliseconds: 450),
                    transitionCurve: Curves.easeOutBack,
                    transitionBuilder: (
                      BuildContext context,
                      HintTransitionInfo info,
                      Widget child,
                    ) =>
                        FadeTransition(
                      opacity: info.opacity,
                      child: RotationTransition(
                        turns: Tween<double>(begin: -0.03, end: 0)
                            .animate(info.animation),
                        alignment: info.origin,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.6, end: 1)
                              .animate(info.animation),
                          alignment: info.origin,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  message: 'A transitionBuilder: rotate and scale out of the '
                      'caret, with an overshooting curve.',
                  triggers: const <HintTrigger>{HintTrigger.tap},
                  showDuration: const Duration(seconds: 3),
                  child: const Chip(
                    avatar: Icon(Icons.animation, size: 18),
                    label: Text('custom'),
                  ),
                ),
                // A caret of your own, drawn into the same fused path.
                Hint(
                  theme: HintThemeData(
                    arrowShape: HintArrowShape.custom,
                    arrowSize: const Size(26, 14),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    arrowBuilder: _hookedArrow,
                  ),
                  message: 'A custom arrowBuilder — the path is unioned into '
                      'the bubble, so the border and shadow stay continuous.',
                  triggers: const <HintTrigger>{HintTrigger.tap},
                  child: const Chip(
                    avatar: Icon(Icons.polyline, size: 18),
                    label: Text('custom caret'),
                  ),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'Show a hint once, ever',
              body: 'showOnce records a key the first time the bubble opens, '
                  'and every later attempt does nothing — including from a '
                  'controller. Wire HintRegistry.instance.storage to '
                  'shared_preferences and it survives restarts.',
            ),
            Row(
              children: <Widget>[
                Hint(
                  controller: _onceHint,
                  showOnce: 'example-whats-new',
                  triggers: const <HintTrigger>{HintTrigger.manual},
                  title: "What's new",
                  message: 'Payslips live here now. You will not see this '
                      'again — unless you reset it.',
                  showDuration: const Duration(seconds: 3),
                  child: FilledButton.tonal(
                    onPressed: _onceHint.show,
                    child: const Text('Show once'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await HintRegistry.instance
                        .resetShowOnce('example-whats-new');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reset — it will show once more.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'A sequence of tips, without a tour',
              body: 'HintQueue shows hints one after another: each waits for '
                  'the last to be dismissed. No scrim, no spotlight, no step '
                  'card — just three tips in order.',
            ),
            Row(
              children: <Widget>[
                for (int i = 0; i < _tips.length; i++) ...<Widget>[
                  Hint(
                    controller: _tips[i],
                    triggers: const <HintTrigger>{HintTrigger.manual},
                    message: _tipText[i],
                    dismissOnTapOutside: true,
                    child: Chip(label: Text('Tip ${i + 1}')),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonal(
                  onPressed: _tipQueue.start,
                  child: const Text('Run the tips'),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'Desktop and web',
              body: 'Right-click to explain, a help cursor on the target, and '
                  'a bubble that follows the pointer instead of the widget. '
                  'Try these with a mouse.',
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                const Hint(
                  triggers: <HintTrigger>{HintTrigger.secondaryTap},
                  mouseCursor: SystemMouseCursors.help,
                  title: 'Right-click',
                  message: 'Opened by the secondary button, so the primary '
                      'click still belongs to the widget.',
                  child: Chip(
                    avatar: Icon(Icons.mouse_outlined, size: 18),
                    label: Text('Right-click me'),
                  ),
                ),
                // The case followPointer exists for: what is being explained
                // is the position, not the box.
                Hint(
                  followPointer: true,
                  interactive: false,
                  triggers: const <HintTrigger>{HintTrigger.hover},
                  mouseCursor: SystemMouseCursors.precise,
                  message: 'The bubble tracks the cursor across this area.',
                  child: Container(
                    width: 220,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: const Text('Hover across me'),
                  ),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'How dark the tour is',
              body: 'The scrim behind a tour step. Opacity and colour are '
                  'separate settings, so the slider works whether or not a '
                  'tint is chosen. Change them, then start the tour.',
            ),
            Row(
              children: <Widget>[
                const Text('Dim'),
                Expanded(
                  child: Slider(
                    value: widget.scrimOpacity,
                    label: '${(widget.scrimOpacity * 100).round()}%',
                    divisions: 20,
                    onChanged: widget.onScrimOpacityChanged,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(widget.scrimOpacity * 100).round()}%',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MapEntry<String, Color?> tint in _scrimTints.entries)
                  ChoiceChip(
                    label: Text(tint.key),
                    selected: widget.scrimTint == tint.value,
                    avatar: tint.value == null
                        ? null
                        : CircleAvatar(backgroundColor: tint.value),
                    onSelected: (_) => widget.onScrimTintChanged(tint.value),
                  ),
              ],
            ),
            const _SectionHeader(
              title: 'Beacon',
              body: 'A pulsing dot for a feature people keep missing. Tap it. '
                  'This one pulses three times and then settles, so it stops '
                  'competing with the rest of the screen.',
            ),
            Row(
              children: <Widget>[
                Beacon(
                  pulseCount: 3,
                  title: 'Duplicate a shift',
                  message: 'Long-press any shift in the calendar to copy it to '
                      'another day.',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: const Icon(Icons.calendar_month),
                  ),
                ),
              ],
            ),
            const _SectionHeader(
              title: 'Inside a scroll view',
              body: 'The bubble tracks its target through the scroll at the '
                  'layer level. Open it, then scroll.',
            ),
            const Hint(
              message: 'I follow my target while you scroll.',
              triggers: <HintTrigger>{HintTrigger.tap},
              dismissOnTapOutside: false,
              direction: HintDirection.right,
              child: ListTile(
                leading: Icon(Icons.anchor),
                title: Text('Tap me, then scroll'),
              ),
            ),
            const SizedBox(height: 320),
            const _SectionHeader(
              title: 'Below the fold',
              body:
                  'Step 3 of the tour is down here. Starting the tour scrolls '
                  'to it before showing the step.',
            ),
            HintTarget(
              tour: 'onboarding',
              order: 3,
              title: 'Out of sight',
              description:
                  'The tour scrolled here for you, the spotlight travelled '
                  'from the last target, and beforeShow expanded this panel '
                  'before the step appeared.',
              // Awaited: the step waits until the panel it points at is open.
              beforeShow: () async {
                setState(() => _panelOpen = true);
                await Future<void>.delayed(const Duration(milliseconds: 350));
              },
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.vertical_align_bottom),
                      title: const Text('A card below the fold'),
                      trailing: IconButton(
                        icon: Icon(
                          _panelOpen ? Icons.expand_less : Icons.expand_more,
                        ),
                        onPressed: () =>
                            setState(() => _panelOpen = !_panelOpen),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _panelOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          'This panel was closed until the step opened it.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (BuildContext context) => FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const DetailsPage(),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Details page (tour step 4 lives there)'),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (BuildContext context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Resumes at the step the tour was left on. To see it: start the
            // tour, walk a step or two, send the app to the background — which
            // cancels the tour, see _ExampleAppState — then come back and
            // press this. `cancel` keeps the position; `skip` and `finish`
            // clear it on purpose.
            FloatingActionButton.small(
              heroTag: 'resume',
              tooltip: 'Continue where you left off',
              onPressed: () => Tour.read(context)
                  .start('onboarding', force: true, resume: true),
              child: const Icon(Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'start',
              onPressed: () =>
                  Tour.read(context).start('onboarding', force: true),
              icon: const Icon(Icons.tour),
              label: const Text('Start tour'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The second route, holding the last step of the tour.
class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'If the tour reached step 4 while you were on the home page, it '
              'paused and waited for this route. Pushing this page resumes it.',
            ),
            const SizedBox(height: 24),
            HintTarget(
              tour: 'onboarding',
              order: 4,
              title: 'A step on another route',
              description:
                  'The tour waited here rather than skipping the step or '
                  'crashing. That is the whole trick: each step draws into '
                  'whatever overlay its own target lives in.',
              spotlight: SpotlightShape.roundedRect,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('The last step'),
                  subtitle: const Text('Press Done to finish the tour'),
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich content for the interactive tooltip.
class _PayslipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ResolvedHintTheme theme = HintThemeData.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Payslip #4821', style: theme.titleStyle),
        const SizedBox(height: 4),
        Text('Period: 1–15 August', style: theme.messageStyle),
        Text('Net: £1,204.50', style: theme.messageStyle),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _InlineAction(
              icon: Icons.download,
              label: 'Download',
              theme: theme,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading payslip…')),
              ),
            ),
            const SizedBox(width: 8),
            _InlineAction(
              icon: Icons.open_in_new,
              label: 'Open',
              theme: theme,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening payslip…')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ResolvedHintTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: theme.foregroundColor),
            const SizedBox(width: 4),
            Text(label, style: theme.messageStyle),
          ],
        ),
      ),
    );
  }
}

/// Tints offered for the tour scrim.
///
/// The alpha of these is irrelevant — `scrimOpacity` replaces it — so they are
/// written opaque, which is also how you would pick them from a palette.
const Map<String, Color?> _scrimTints = <String, Color?>{
  'neutral': null,
  'navy': Color(0xFF0B1B3A),
  'plum': Color(0xFF2A0B33),
  'forest': Color(0xFF07261A),
};

/// The three tips [HintQueue] walks through, in order.
const List<String> _tipText = <String>[
  'One: dismiss this and the next tip opens by itself.',
  'Two: the queue waits for each hint to close, however it closes.',
  'Three: that is the whole sequence — no scrim, no step card.',
];

/// What each transition looks like, shown in a bubble using it.
const Map<HintTransition, String> _transitionBlurb = <HintTransition, String>{
  HintTransition.scale: 'The default: fade plus a small scale out of the '
      'caret.',
  HintTransition.fade: 'Opacity only — the quietest option.',
  HintTransition.pop: 'Overshoots slightly before settling.',
  HintTransition.slide: 'Arrives from the direction of its target.',
  HintTransition.none: 'No animation at all: there, then gone.',
};

/// A caret with a hooked tip, drawn by hand.
///
/// Shows what [HintThemeData.arrowBuilder] is for: the geometry arrives
/// resolved for whichever edge the bubble landed on, so one path works on all
/// four sides.
Path _hookedArrow(HintArrowGeometry g) {
  final Offset depth = g.tip - g.baseCentre;
  final Offset shoulder = g.baseCentre + depth * 0.55;
  return Path()
    ..moveTo(g.baseStart.dx, g.baseStart.dy)
    ..quadraticBezierTo(
      (shoulder - g.along * (g.halfWidth * 0.4)).dx,
      (shoulder - g.along * (g.halfWidth * 0.4)).dy,
      g.tip.dx,
      g.tip.dy,
    )
    ..lineTo((g.baseEnd + depth * 0.15).dx, (g.baseEnd + depth * 0.15).dy)
    ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
    ..close();
}

/// What each preset is for, shown inside a bubble wearing it.
const Map<HintPreset, String> _presetBlurb = <HintPreset, String>{
  HintPreset.material: 'The package default: a raised chip that inverts with '
      'the theme.',
  HintPreset.minimal: 'Flat and outlined — sits on the page instead of above '
      'it. For dense UIs.',
  HintPreset.soft: 'Rounded, roomy, with a curved speech-balloon tail and a '
      'little overshoot on the way in.',
  HintPreset.contrast: 'Pure black on white, heavier type, no shadow. Built '
      'for legibility.',
  HintPreset.branded: 'Tinted with your ColorScheme — fill, outline and scrim '
      'all follow the seed colour.',
  HintPreset.sharp: 'Square corners, hairline outline, fast flat transition. '
      'For desktop tools.',
  HintPreset.card: 'A small dialog rather than a chip: wide, padded, raised, '
      'with a blurred scrim behind tour steps.',
};

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
