import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// The reason the package exists: a hint on a control that cannot be tapped.
class DisabledWidgetsSection extends StatelessWidget {
  const DisabledWidgetsSection({
    required this.onShift,
    required this.onToggleShift,
    super.key,
  });

  /// Whether the check-in button is enabled.
  final bool onShift;
  final VoidCallback onToggleShift;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'Hints on disabled widgets',
          body: 'The reason this package exists. Long-press the disabled '
              'button: it still explains itself, because triggers are read '
              'from raw pointer events rather than the gesture arena.',
        ),
        Row(
          children: <Widget>[
            // The headline case: a hint on a disabled control.
            Hint(
              message: onShift
                  ? 'Tap to check in for your shift'
                  : 'You need an active shift to check in',
              direction: HintDirection.bottom,
              child: ElevatedButton.icon(
                onPressed: onShift ? () {} : null,
                icon: const Icon(Icons.login),
                label: const Text('Check in'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onToggleShift,
              child: Text(onShift ? 'End shift' : 'Start shift'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          onShift
              ? 'The button is enabled — its own tap still works, and the '
                  'hint still opens on a long press.'
              : 'The button is disabled — the hint still opens.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
