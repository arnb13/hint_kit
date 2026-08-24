import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// The ready-made designs, one chip each.
class PresetsSection extends StatelessWidget {
  const PresetsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
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
      ],
    );
  }
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
