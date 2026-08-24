One `ThemeExtension` that restyles every bubble, card, caret and spotlight.

`HintThemeData` goes in your `ThemeData.extensions` and everything the package
draws follows it — tooltips, persistent hints, beacons and tour cards alike.
Set `preset` for a ready-made design, override individual fields beside it to
adjust one, or pass a `theme:` to a single `Hint` for a one-off.

`HintTransition` covers how a bubble arrives and `HintArrowShape` how its caret
is drawn; both take a builder when the built-in options run out.
