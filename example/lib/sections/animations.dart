import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

import '../section_header.dart';

/// The built-in transitions, plus a hand-written one and a hand-drawn caret.
class AnimationsSection extends StatelessWidget {
  const AnimationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(
          title: 'Animations',
          body: 'Five ready-made transitions, and a builder for anything '
              'else. Presets carry their own motion, so picking a design '
              'picks how it arrives too.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final HintTransition transition in HintTransition.values)
              Hint(
                theme: HintThemeData(
                  transition: transition,
                  // Long enough that the difference is actually visible.
                  transitionDuration: const Duration(milliseconds: 320),
                ),
                message: _transitionBlurb[transition],
                triggers: const <HintTrigger>{HintTrigger.tap},
                showDuration: const Duration(seconds: 2),
                child: Chip(label: Text(transition.name)),
              ),
            // An animation of your own: the builder is handed the curved
            // animation, a clamped one for opacity, and where the caret is.
            Hint(
              theme: HintThemeData(
                transitionDuration: const Duration(milliseconds: 450),
                transitionCurve: Curves.easeOutBack,
                transitionBuilder: (
                  BuildContext context,
                  HintTransitionInfo info,
                  Widget child,
                ) =>
                    FadeTransition(
                  opacity: info.opacity,
                  child: RotationTransition(
                    turns: Tween<double>(begin: -0.03, end: 0)
                        .animate(info.animation),
                    alignment: info.origin,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.6, end: 1)
                          .animate(info.animation),
                      alignment: info.origin,
                      child: child,
                    ),
                  ),
                ),
              ),
              message: 'A transitionBuilder: rotate and scale out of the '
                  'caret, with an overshooting curve.',
              triggers: const <HintTrigger>{HintTrigger.tap},
              showDuration: const Duration(seconds: 3),
              child: const Chip(
                avatar: Icon(Icons.animation, size: 18),
                label: Text('custom'),
              ),
            ),
            // A caret of your own, drawn into the same fused path.
            Hint(
              theme: HintThemeData(
                arrowShape: HintArrowShape.custom,
                arrowSize: const Size(26, 14),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                arrowBuilder: _hookedArrow,
              ),
              message: 'A custom arrowBuilder — the path is unioned into '
                  'the bubble, so the border and shadow stay continuous.',
              triggers: const <HintTrigger>{HintTrigger.tap},
              child: const Chip(
                avatar: Icon(Icons.polyline, size: 18),
                label: Text('custom caret'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What each transition looks like, shown in a bubble using it.
const Map<HintTransition, String> _transitionBlurb = <HintTransition, String>{
  HintTransition.scale: 'The default: fade plus a small scale out of the '
      'caret.',
  HintTransition.fade: 'Opacity only — the quietest option.',
  HintTransition.pop: 'Overshoots slightly before settling.',
  HintTransition.slide: 'Arrives from the direction of its target.',
  HintTransition.none: 'No animation at all: there, then gone.',
};

/// A caret with a hooked tip, drawn by hand.
///
/// Shows what [HintThemeData.arrowBuilder] is for: the geometry arrives
/// resolved for whichever edge the bubble landed on, so one path works on all
/// four sides.
Path _hookedArrow(HintArrowGeometry g) {
  final Offset depth = g.tip - g.baseCentre;
  final Offset shoulder = g.baseCentre + depth * 0.55;
  return Path()
    ..moveTo(g.baseStart.dx, g.baseStart.dy)
    ..quadraticBezierTo(
      (shoulder - g.along * (g.halfWidth * 0.4)).dx,
      (shoulder - g.along * (g.halfWidth * 0.4)).dy,
      g.tip.dx,
      g.tip.dy,
    )
    ..lineTo((g.baseEnd + depth * 0.15).dx, (g.baseEnd + depth * 0.15).dy)
    ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
    ..close();
}
