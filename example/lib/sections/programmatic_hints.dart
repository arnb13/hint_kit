import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// Opening a bubble from code, and the tour step that asks for a real tap.
class ProgrammaticHintsSection extends StatefulWidget {
  const ProgrammaticHintsSection({super.key});

  @override
  State<ProgrammaticHintsSection> createState() =>
      _ProgrammaticHintsSectionState();
}

class _ProgrammaticHintsSectionState extends State<ProgrammaticHintsSection> {
  final HintController _savedHint = HintController();

  @override
  void dispose() {
    _savedHint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
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
              description: 'This step is passthrough: the scrim lets a real '
                  'tap reach the button. Press it to continue.',
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
      ],
    );
  }
}
