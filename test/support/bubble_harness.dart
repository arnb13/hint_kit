import 'package:flutter/material.dart';
import 'package:hint_kit/hint_kit.dart';

/// Wraps [child] in the minimum needed to paint a bubble deterministically.
///
/// Shared by the bubble's unit tests and its goldens, so a change to the
/// harness cannot make the two disagree about what they are measuring.
Widget harness(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF101010),
      body: Center(child: child),
    ),
  );
}

/// Builds a bubble with resolved theming, ready to pump.
Widget bubble({
  required HintSide side,
  double arrowFraction = 0.5,
  HintThemeData? theme,
  String message = 'Check in here',
  String? title,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ResolvedHintTheme resolved = HintThemeData.resolve(context, theme);
      return SizedBox(
        width: 200,
        child: HintBubbleDecoration(
          side: side,
          arrowFraction: arrowFraction,
          theme: resolved,
          child: HintBubbleContent(
            theme: resolved,
            title: title,
            message: message,
          ),
        ),
      );
    },
  );
}

/// A flat-topped caret: two shoulders and a blunt end, which no built-in shape
/// can produce.
///
/// The stand-in for "a caret of your own" in both the path tests and the
/// golden.
Path bluntArrow(HintArrowGeometry g) {
  final Offset shoulderA = g.baseStart + (g.tip - g.baseCentre) * 0.6;
  final Offset shoulderB = g.baseEnd + (g.tip - g.baseCentre) * 0.6;
  return Path()
    ..moveTo(g.baseStart.dx, g.baseStart.dy)
    ..lineTo(shoulderA.dx, shoulderA.dy)
    ..lineTo(shoulderB.dx, shoulderB.dy)
    ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
    ..close();
}
