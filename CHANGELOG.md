# Changelog

## 0.1.0

First release.

Tooltips, persistent hints and guided tours from one overlay engine, one
placement resolver and one theme. No runtime dependencies.

### Tooltips and hints

- `Hint` — a bubble anchored to any widget, shown by tap, long press, hover,
  focus, on appear, or on command.
- Works on **disabled widgets**: triggers are read from a raw `Listener`, so a
  child that ignores pointers still yields a hint, and a child that handles
  them keeps its own gesture.
- `absorbChildInput` escape hatch for children that do not hit-test at all.
- `HintController` for programmatic `show` / `hide` / `toggle` / `refresh`,
  which also reports dismissals the hint initiated itself.
- `OverlayPortal` rather than manual `OverlayEntry`, so a popped route cannot
  leak an entry, and `LayerLink` tracking, so the bubble follows its target
  through scroll and animation with no per-frame Dart work.
- Interactive bubbles: arbitrary widget content, and moving the pointer from
  the target into the bubble does not dismiss it.
- App-wide exclusivity, opt-out per hint.
- `onShow` / `onDismiss` hooks.

### Tours

- `TourScope`, `TourController`, `HintTarget` — the tooltip engine plus a
  scrim and a sequencer, not a second implementation.
- Steps may live on **different routes**: a step whose target is not mounted
  waits for it rather than skipping or crashing.
- `Spotlight` with `rect`, `roundedRect`, `circle`, `oval` and `custom`
  shapes, optional pulse ring and optional backdrop blur; the scrim is a
  single `Path.combine` difference.
- Real hit-test passthrough via a `RenderProxyBox` that reports `hitTestSelf`
  false inside the hole.
- `Scrollable.ensureVisible` before a step, with per-frame target tracking so
  the spotlight stays glued through the scroll.
- Default step card with title, body, "2 of 5" progress and Back / Next /
  Skip, replaceable per step with `contentBuilder`.
- `TourStorage` interface with an `InMemoryTourStorage` default.
- Keyboard: arrows move, Enter advances, Esc skips.

### Extras

- `Beacon` — a pulsing attention dot that opens a hint when tapped.
- `HintThemeData`, a `ThemeExtension` that themes all three features together,
  with per-field resolution and `ColorScheme`-derived defaults that look right
  in light and dark without configuration.
- Two caret silhouettes via `HintArrowShape`: the default `triangle`, and
  `curved`, a speech-balloon tail whose flanks leave the bubble edge parallel
  to it so there is no corner where the caret meets the body. Both fill the
  same `arrowSize` box, so switching never moves the bubble.
- `resolvePlacement`, a pure placement function, exported for anyone building
  their own overlay.
