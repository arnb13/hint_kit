import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

void main() => runApp(const ExampleApp());

/// Demonstrates every part of hint_kit in one screen plus a second route.
///
/// The tour deliberately spans both: step 4 lives on the details page, which
/// is the case `tutorial_coach_mark` and friends cannot handle.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
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

  @override
  void dispose() {
    _tour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScope(
      controller: _tour,
      // Declared so the card says "1 of 4" from the start, even though the
      // fourth target lives on a route that has not been pushed yet.
      tourLengths: const <String, int>{'onboarding': 4},
      child: MaterialApp(
        title: 'hint_kit',
        debugShowCheckedModeBanner: false,
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: HomePage(
          onToggleTheme: () => setState(() => _dark = !_dark),
          onToggleShift: () => setState(() => _onShift = !_onShift),
          onToggleArrow: () => setState(() => _curvedArrows = !_curvedArrows),
          onShift: _onShift,
          isDark: _dark,
          curvedArrows: _curvedArrows,
        ),
      ),
    );
  }

  /// The whole package is themed from one [ThemeExtension].
  ///
  /// Flipping [_curvedArrows] here restyles the caret on every tooltip, hint
  /// and beacon in the app at once — that is the point of theming all three
  /// features from one place.
  ThemeData _theme(Brightness brightness) => ThemeData(
        brightness: brightness,
        colorSchemeSeed: const Color(0xFF3F51B5),
        extensions: <ThemeExtension<dynamic>>[
          HintThemeData(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            maxWidth: 300,
            arrowShape:
                _curvedArrows ? HintArrowShape.curved : HintArrowShape.triangle,
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
    required this.onShift,
    required this.isDark,
    required this.curvedArrows,
    super.key,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onToggleShift;
  final VoidCallback onToggleArrow;
  final bool onShift;
  final bool isDark;
  final bool curvedArrows;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HintController _savedHint = HintController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _savedHint.dispose();
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
              title: 'Beacon',
              body: 'A pulsing dot for a feature people keep missing. Tap it.',
            ),
            Row(
              children: <Widget>[
                Beacon(
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
            const HintTarget(
              tour: 'onboarding',
              order: 3,
              title: 'Out of sight',
              description:
                  'The tour scrolled here for you, and the spotlight stayed '
                  'glued to the target the whole way down.',
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.vertical_align_bottom),
                  title: Text('A card below the fold'),
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
        builder: (BuildContext context) => FloatingActionButton.extended(
          onPressed: () => Tour.read(context).start('onboarding', force: true),
          icon: const Icon(Icons.tour),
          label: const Text('Start tour'),
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
