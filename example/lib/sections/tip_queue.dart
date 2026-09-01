import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// Three hints shown one after another, with no scrim and no step card.
class TipQueueSection extends StatefulWidget {
  const TipQueueSection({super.key});

  @override
  State<TipQueueSection> createState() => _TipQueueSectionState();
}

class _TipQueueSectionState extends State<TipQueueSection> {
  /// Three tips shown one after another by [_tipQueue].
  final List<HintController> _tips =
      List<HintController>.generate(3, (_) => HintController());
  late final HintQueue _tipQueue = HintQueue(_tips);

  @override
  void dispose() {
    _tipQueue.dispose();
    for (final HintController tip in _tips) {
      tip.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'A sequence of tips, without a tour',
          body: 'HintQueue shows hints one after another: each waits for '
              'the last to be dismissed. No scrim, no spotlight, no step '
              'card — just three tips in order.',
        ),
        // A Wrap, not a Row: three chips and a button are 0.8 px too wide for
        // a 344 px phone, and a Row would rather report an overflow than let
        // the last one drop to a second line.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int i = 0; i < _tips.length; i++)
              Hint(
                controller: _tips[i],
                triggers: const <HintTrigger>{HintTrigger.manual},
                message: _tipText[i],
                dismissOnTapOutside: true,
                child: Chip(label: Text('Tip ${i + 1}')),
              ),
            FilledButton.tonal(
              onPressed: _tipQueue.start,
              child: const Text('Run the tips'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The three tips [HintQueue] walks through, in order.
const List<String> _tipText = <String>[
  'One: dismiss this and the next tip opens by itself.',
  'Two: the queue waits for each hint to close, however it closes.',
  'Three: that is the whole sequence — no scrim, no step card.',
];
