import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// A bubble that opens the first time and never again.
class ShowOnceSection extends StatefulWidget {
  const ShowOnceSection({super.key});

  @override
  State<ShowOnceSection> createState() => _ShowOnceSectionState();
}

class _ShowOnceSectionState extends State<ShowOnceSection> {
  final HintController _onceHint = HintController();

  @override
  void dispose() {
    _onceHint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'Show a hint once, ever',
          body: 'showOnce records a key the first time the bubble opens, '
              'and every later attempt does nothing — including from a '
              'controller. Wire HintRegistry.instance.storage to '
              'shared_preferences and it survives restarts.',
        ),
        Row(
          children: <Widget>[
            Hint(
              controller: _onceHint,
              showOnce: 'example-whats-new',
              triggers: const <HintTrigger>{HintTrigger.manual},
              title: "What's new",
              message: 'Payslips live here now. You will not see this '
                  'again — unless you reset it.',
              showDuration: const Duration(seconds: 3),
              child: FilledButton.tonal(
                onPressed: _onceHint.show,
                child: const Text('Show once'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                await HintRegistry.instance.resetShowOnce('example-whats-new');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reset — it will show once more.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}
