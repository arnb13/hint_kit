import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

/// The second route, holding the last step of the tour.
class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'If the tour reached step 4 while you were on the home page, it '
              'paused and waited for this route. Pushing this page resumes it.',
            ),
            const SizedBox(height: 24),
            HintTarget(
              tour: 'onboarding',
              order: 4,
              title: 'A step on another route',
              description:
                  'The tour waited here rather than skipping the step or '
                  'crashing. That is the whole trick: each step draws into '
                  'whatever overlay its own target lives in.',
              spotlight: SpotlightShape.roundedRect,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('The last step'),
                  subtitle: const Text('Press Done to finish the tour'),
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
