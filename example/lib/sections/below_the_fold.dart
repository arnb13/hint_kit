import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// Tour step 3: off screen when the tour starts, and closed until it opens.
class BelowTheFoldSection extends StatefulWidget {
  const BelowTheFoldSection({super.key});

  @override
  State<BelowTheFoldSection> createState() => _BelowTheFoldSectionState();
}

class _BelowTheFoldSectionState extends State<BelowTheFoldSection> {
  /// Whether the panel that tour step 3 points at is expanded.
  bool _panelOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Enough empty space that step 3 really is off screen to begin with.
        const SizedBox(height: 320),
        const SectionHeader(
          title: 'Below the fold',
          body: 'Step 3 of the tour is down here. Starting the tour scrolls '
              'to it before showing the step.',
        ),
        HintTarget(
          tour: 'onboarding',
          order: 3,
          title: 'Out of sight',
          description: 'The tour scrolled here for you, the spotlight '
              'travelled from the last target, and beforeShow expanded this '
              'panel before the step appeared.',
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
                    onPressed: () => setState(() => _panelOpen = !_panelOpen),
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
      ],
    );
  }
}
