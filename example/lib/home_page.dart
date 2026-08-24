import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import 'details_page.dart';
import 'sections/animations.dart';
import 'sections/beacon.dart';
import 'sections/below_the_fold.dart';
import 'sections/desktop_and_web.dart';
import 'sections/disabled_widgets.dart';
import 'sections/presets.dart';
import 'sections/programmatic_hints.dart';
import 'sections/rich_bubbles.dart';
import 'sections/scrim.dart';
import 'sections/scroll_tracking.dart';
import 'sections/show_once.dart';
import 'sections/tip_queue.dart';

/// The demo screen: an app bar of live settings, and one section per feature.
///
/// Each section lives in its own file under `lib/sections/` and owns whatever
/// controllers it needs, so a section can be read — or copied into your own
/// app — on its own.
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
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('hint_kit'),
        actions: _appBarActions(context),
      ),
      // A SingleChildScrollView, not a ListView: every tour target below the
      // fold is built even while off screen, which is what lets the tour
      // scroll to step 3. A lazily-built target that has never been created
      // has not registered with the scope, so there is nothing to scroll to —
      // see HintTarget's documentation.
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DisabledWidgetsSection(
              onShift: widget.onShift,
              onToggleShift: widget.onToggleShift,
            ),
            const ProgrammaticHintsSection(),
            const RichBubblesSection(),
            const PresetsSection(),
            const AnimationsSection(),
            const ShowOnceSection(),
            const TipQueueSection(),
            const DesktopAndWebSection(),
            ScrimSection(
              scrimOpacity: widget.scrimOpacity,
              scrimTint: widget.scrimTint,
              onScrimOpacityChanged: widget.onScrimOpacityChanged,
              onScrimTintChanged: widget.onScrimTintChanged,
            ),
            const BeaconSection(),
            const ScrollTrackingSection(),
            const BelowTheFoldSection(),
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

  /// The app-bar controls, every one of them a hint in its own right.
  List<Widget> _appBarActions(BuildContext context) => <Widget>[
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
          itemBuilder: (BuildContext context) => <PopupMenuEntry<HintPreset?>>[
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
      ];
}
