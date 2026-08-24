import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// Arbitrary widgets inside the bubble, with working buttons.
class RichBubblesSection extends StatelessWidget {
  const RichBubblesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'Rich, interactive tooltips',
          body: 'Arbitrary widgets inside the bubble. Hovering from the '
              'target into the bubble does not dismiss it, so the link is '
              'actually clickable.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Hint(
            interactive: true,
            triggers: const <HintTrigger>{
              HintTrigger.hover,
              HintTrigger.tap,
            },
            direction: HintDirection.right,
            contentBuilder: (BuildContext context) => const _PayslipCard(),
            child: const Chip(
              avatar: Icon(Icons.receipt_long, size: 18),
              label: Text('Payslip #4821'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rich content for the interactive tooltip.
class _PayslipCard extends StatelessWidget {
  const _PayslipCard();

  @override
  Widget build(BuildContext context) {
    final ResolvedHintTheme theme = HintThemeData.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Payslip #4821', style: theme.titleStyle),
        const SizedBox(height: 4),
        Text('Period: 1–15 August', style: theme.messageStyle),
        Text('Net: £1,204.50', style: theme.messageStyle),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _InlineAction(
              icon: Icons.download,
              label: 'Download',
              theme: theme,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading payslip…')),
              ),
            ),
            const SizedBox(width: 8),
            _InlineAction(
              icon: Icons.open_in_new,
              label: 'Open',
              theme: theme,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening payslip…')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ResolvedHintTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: theme.foregroundColor),
            const SizedBox(width: 4),
            Text(label, style: theme.messageStyle),
          ],
        ),
      ),
    );
  }
}
