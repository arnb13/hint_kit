import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// The mouse-only features: right-click, a help cursor, a following bubble.
class DesktopAndWebSection extends StatelessWidget {
  const DesktopAndWebSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'Desktop and web',
          body: 'Right-click to explain, a help cursor on the target, and '
              'a bubble that follows the pointer instead of the widget. '
              'Try these with a mouse.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            const Hint(
              triggers: <HintTrigger>{HintTrigger.secondaryTap},
              mouseCursor: SystemMouseCursors.help,
              title: 'Right-click',
              message: 'Opened by the secondary button, so the primary '
                  'click still belongs to the widget.',
              child: Chip(
                avatar: Icon(Icons.mouse_outlined, size: 18),
                label: Text('Right-click me'),
              ),
            ),
            // The case followPointer exists for: what is being explained
            // is the position, not the box.
            Hint(
              followPointer: true,
              interactive: false,
              triggers: const <HintTrigger>{HintTrigger.hover},
              mouseCursor: SystemMouseCursors.precise,
              message: 'The bubble tracks the cursor across this area.',
              child: Container(
                width: 220,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                child: const Text('Hover across me'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
