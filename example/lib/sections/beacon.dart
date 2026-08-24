import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// A pulsing dot for a feature people keep missing.
class BeaconSection extends StatelessWidget {
  const BeaconSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
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
      ],
    );
  }
}
