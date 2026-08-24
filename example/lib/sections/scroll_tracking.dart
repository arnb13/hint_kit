import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// A bubble that stays glued to its target while the page scrolls.
class ScrollTrackingSection extends StatelessWidget {
  const ScrollTrackingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHeader(
          title: 'Inside a scroll view',
          body: 'The bubble tracks its target through the scroll at the '
              'layer level. Open it, then scroll.',
        ),
        Hint(
          message: 'I follow my target while you scroll.',
          triggers: <HintTrigger>{HintTrigger.tap},
          dismissOnTapOutside: false,
          direction: HintDirection.right,
          child: ListTile(
            leading: Icon(Icons.anchor),
            title: Text('Tap me, then scroll'),
          ),
        ),
      ],
    );
  }
}
