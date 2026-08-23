# Changelog

## 1.1.0

A tour could sit there forever, silently, and there was no way to say "this
step does not apply to this user".

- `HintTarget(enabled: false)` takes a step out of the tour: not counted, not
  ordered, never shown, while its child renders exactly as before. Use it for
  a step behind a feature flag, a permission or a role. A step that opts out is
  subtracted from `TourScope.tourLengths`, so the card cannot promise "of 5"
  and then deliver four.
- `TourScope.stepTimeout` and `onStepUnavailable` give the tour a deadline for
  a step whose target never arrives. Null by default, deliberately: waiting is
  what lets a tour cross routes, and the package cannot tell a screen the user
  has not opened from one they never will.

Without either, a tour whose declared length exceeded the targets that ever
registered stopped drawing anything at all — no scrim, no card, no error — and
kept its saved position, so resuming returned to the same dead step.

- Removed `lib/generated/assets.dart`, an IDE artefact that shipped in 1.0.0.
- The README gained a troubleshooting table and a section on steps that may not
  apply.

## 1.0.0

No API changes since 0.1.0. The version is the promise: the surface that
0.1.0 shipped is the one 1.x will keep, and anything that breaks it now needs
a 2.0.

- The README leads with what the package looks like: two captioned GIFs
  recorded on a device, six screenshots, a feature list, and install and
  requirements sections.
- Images use absolute URLs, which is what pub.dev needs to render them.

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
- `HintPreset` — nine ready-made designs (`material`, `minimal`, `soft`,
  `contrast`, `branded`, `sharp`, `card`, `cupertino`, `adaptive`) set with
  `HintThemeData(preset: ...)`, app-wide or per hint. A preset is a layer, not
  a mode: it sits between your explicit fields and the `ColorScheme` defaults,
  so any field you also set still wins and anything the preset leaves open
  still adapts to the ambient theme. `HintPreset.themeData(context)` hands the
  design back as plain data for a custom design built from one. `adaptive`
  resolves through `ThemeData.platform`, so it is testable and honours a
  platform override.
- `HintTransition` — five show/hide animations (`scale`, `fade`, `pop`,
  `slide`, `none`), carried by the presets and settable on their own, plus
  `HintThemeData.transitionBuilder` for an animation of your own.
  `HintTransitionInfo` supplies the curved animation, a clamped one for
  opacity, the resolved side, an origin on the caret and a unit vector towards
  the target, so a custom transition works on all four sides without asking
  about placement.
- `HintArrowShape.custom` with `HintThemeData.arrowBuilder` — draw the caret
  yourself. `HintArrowGeometry` arrives resolved for the edge the bubble landed
  on, and the path is unioned into the body, so a custom caret keeps the
  continuous border and single shadow.
- `TourLabels` on `TourScope` — every word on the default step card, and the
  step counter as a callback rather than a format string, because word order is
  not universal. Custom cards get the same labels through `TourStepInfo.labels`.
- `Hint.showOnce` — show a hint the first time and never again, backed by
  `HintRegistry.instance.storage` and reset with
  `HintRegistry.resetShowOnce`. Blocks a `HintController` too, and an
  `onAppear` hint waits for the flag rather than racing the first frame.
- `HintObserver` and `HintEvent`, registered on `HintRegistry` — one app-wide
  hook for every hint show and dismiss and the whole tour lifecycle, for
  onboarding funnels. `Hint.analyticsId` gives an event a key that outlives its
  text.
- `CallbackTourStorage` — real persistence in two closures, with no subclass
  and no dependency. The same instance can serve tours and show-once hints.
- The spotlight now travels from the previous step's target to the next one
  instead of cutting, over `HintThemeData.spotlightMoveDuration`. It animates a
  fraction rather than a rect, so the destination stays live and a target that
  scrolls mid-travel is still followed.

- **Resumable tours.** `TourController.start(tour, resume: true)` picks up at the
  step the user was left on, and `hasProgress` answers "start or continue?"
  without starting anything. `TourStorage` gained `lastIndex`/`saveIndex` with
  no-op defaults, so a storage written against the old interface still works —
  it simply never resumes. Positions are cleared when a tour finishes or is
  skipped, and kept when it is cancelled.
- `HintQueue` — a sequence of hints without a tour: no scrim, no spotlight, no
  step card. Each hint waits for the previous one to close, however it closes.
- `HintTarget.beforeShow` — an awaited hook that lets a step open the drawer,
  push the route or fetch the row it is about to point at. Nothing is drawn
  until it completes, and it is abandoned if the tour moves on first.
- `HintThemeData.backgroundBlur` and the `glass` preset — a translucent bubble
  over a blurred background, clipped to the same fused silhouette as the fill,
  with the shadow still falling outside it.
- Desktop and web: `HintTrigger.secondaryTap` (right-click, read from the
  pointer's buttons so it never competes with the child's own handler),
  `Hint.mouseCursor`, and `Hint.followPointer` for a bubble that tracks the
  cursor instead of the widget — still placed by the full resolver, so it flips
  at a screen edge rather than sliding off it.
- `Beacon.pulseCount` — pulse a few times and settle. Also removes the
  "a running Beacon never lets `pumpAndSettle` settle" limitation.
- `HintThemeData.followHighContrast` — adopt the `contrast` design whenever the
  platform asks for high contrast, keeping every field you set explicitly.
- `package:hint_kit/testing.dart` — `resetHintKit()` for the process-global
  registry, plus `FakeTourStorage` and `RecordingHintObserver`. No dependency
  on `flutter_test`.
- CI on GitHub Actions (format, analyze, test, example test, publish dry-run)
  and a GitHub Pages deploy of the example app, linked from the README.

- `HintThemeData.scrimOpacity` — how dark a tour step gets, independent of the
  scrim's colour. It replaces the alpha of whatever colour is in play (an
  explicit `scrimColor`, a preset's, or the default), so a slider can be bound
  to it without touching the hue; `0` removes the dim and keeps the spotlight.
  The default dim is now heavier — 90% in light mode, 95% in dark, up from 70%
  and 80% — because a scrim you can read the page through competes with the
  step. Presets keep their own dims.

### Fixed

- `HintThemeData.transitionCurve` was themed, merged and lerped but never
  applied to anything: every bubble animated linearly. It now drives the
  transition, with opacity clamped so an overshooting curve bounces instead of
  asserting.
- Two caret silhouettes via `HintArrowShape`: the default `triangle`, and
  `curved`, a speech-balloon tail whose flanks leave the bubble edge parallel
  to it so there is no corner where the caret meets the body. Both fill the
  same `arrowSize` box, so switching never moves the bubble.
- `resolvePlacement`, a pure placement function, exported for anyone building
  their own overlay.
