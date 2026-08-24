import 'package:flutter/material.dart';

import '../section_header.dart';

/// The dim behind a tour step: how dark, and what colour, independently.
class ScrimSection extends StatelessWidget {
  const ScrimSection({
    required this.scrimOpacity,
    required this.scrimTint,
    required this.onScrimOpacityChanged,
    required this.onScrimTintChanged,
    super.key,
  });

  /// How dark the tour scrim is, 0 to 1.
  final double scrimOpacity;

  /// The tour scrim's tint, or null for the default neutral black.
  final Color? scrimTint;

  final ValueChanged<double> onScrimOpacityChanged;
  final ValueChanged<Color?> onScrimTintChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
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
                value: scrimOpacity,
                label: '${(scrimOpacity * 100).round()}%',
                divisions: 20,
                onChanged: onScrimOpacityChanged,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${(scrimOpacity * 100).round()}%',
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
                selected: scrimTint == tint.value,
                avatar: tint.value == null
                    ? null
                    : CircleAvatar(backgroundColor: tint.value),
                onSelected: (_) => onScrimTintChanged(tint.value),
              ),
          ],
        ),
      ],
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
