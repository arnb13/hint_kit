# hint_kit

Tooltips, persistent hints and spotlight guided tours — from **one overlay engine, one placement resolver, one theme and one controller pattern**.

**Zero runtime dependencies.** Pure Flutter, WASM-safe, no `dart:io`, no `dart:html`.

<!-- GIF PLACEHOLDER — record the example app and drop it in, then uncomment.
     pub.dev needs an absolute URL, so host it in the repo:
![hint_kit in action](https://raw.githubusercontent.com/your-org/hint_kit/main/doc/hint_kit.gif)
-->

> **Screenshot placeholder.** Run `cd example && flutter run` to see all of it:
> a hint on a disabled button, a rich interactive tooltip, a `Beacon`, and a
> four-step tour that crosses a route.

## Why

Most apps end up with two packages: one for tooltips, one for onboarding. They theme differently, they each own their own overlay, and they fight when both are open. hint_kit is one package because it is one engine — a tour step is literally the tooltip bubble, placed by the same resolver, with a scrim behind it and a sequencer in front.

```dart
// A tooltip.
Hint(message: 'Delete this shift', child: deleteButton)

// A hint on a *disabled* widget — the reason most people arrive here.
Hint(
  message: 'You need an active shift to check in',
  child: ElevatedButton(onPressed: null, child: Text('Check in')),
)

// A tour step, same bubble, same theme.
HintTarget(tour: 'onboarding', order: 1, title: 'Check in here', child: button)
```

## Quick start

```dart
import 'package:hint_kit/hint_kit.dart';

// 1. Wrap your app once, only if you want tours.
TourScope(child: MaterialApp(home: HomePage()));

// 2. Wrap anything you want to explain.
Hint(message: 'You need an active shift to check in', child: checkInButton);

// 3. Mark tour steps and start the tour.
HintTarget(tour: 'onboarding', order: 1, title: 'Start here', child: button);
Tour.read(context).start('onboarding');
```

That is the whole setup. No initialisation, no global keys, no `GlobalKey<State>` per target.

## Contents

- [Tooltips and hints](#tooltips-and-hints)
- [Hints on disabled widgets](#hints-on-disabled-widgets)
- [Rich and interactive bubbles](#rich-and-interactive-bubbles)
- [Guided tours](#guided-tours)
- [Spotlights and passthrough](#spotlights-and-passthrough)
- [Persistence](#persistence)
- [Beacon](#beacon)
- [Theming](#theming)
- [Accessibility](#accessibility)
- [Placement](#placement)
- [Comparison](#comparison)
- [Known limitations](#known-limitations)

## Tooltips and hints

```dart
Hint(
  message: 'Check in for your shift',
  title: 'Check in',
  triggers: const {HintTrigger.longPress, HintTrigger.hover},
  direction: HintDirection.auto,
  waitDuration: const Duration(milliseconds: 300),
  showDuration: const Duration(seconds: 4),
  child: checkInButton,
)
```

| Trigger | Behaviour |
| --- | --- |
| `tap` | Show on tap, hide on the next tap |
| `longPress` | The platform convention on touch |
| `hover` | Desktop and web, with `waitDuration` |
| `focus` | Shows while the target holds keyboard focus |
| `manual` | Only a `HintController` opens it |
| `onAppear` | Shows as soon as the target is laid out |

Triggers are a `Set`, so one declaration covers touch and desktop.

Drive a hint from code with a `HintController`:

```dart
final HintController hint = HintController();

Hint(controller: hint, triggers: const {HintTrigger.manual}, message: 'Saved', child: saveButton);

hint.show();
hint.hide();
hint.toggle();
hint.refresh();          // force a re-measure after an external layout change
hint.isShown;            // stays honest when the hint dismisses itself
```

The bubble lives in an `OverlayPortal`, so its lifetime is tied to the widget. Popping a route mid-tooltip takes the bubble with it — there is no `OverlayEntry` to leak.

Only one hint is open at a time app-wide (`exclusive: true`, the default). Set `exclusive: false` for a hint that should survive an unrelated tooltip opening — a validation message pinned to a field, say.

## Hints on disabled widgets

This works, and it is worth understanding why:

```dart
Hint(
  message: 'You need an active shift to check in',
  child: ElevatedButton(onPressed: null, child: Text('Check in')),
)
```

Triggers are recognised from a **`Listener`**, which reads raw pointer events and never enters the gesture arena. Two things follow:

- A child that ignores pointers still lets the hint see the touch.
- A child that *does* handle pointers keeps its gesture — the hint never competes for it. Wrapping an enabled button changes nothing about how that button behaves.

Long press and tap are recognised by hand from pointer down/up timestamps and a slop radius, rather than by nesting a `GestureDetector` that would join the arena and could beat the child's own recogniser.

For a child that does not hit-test **at all** — a platform view that swallows events, a custom `RenderBox` with `hitTestSelf` false over a transparent area — there is an opt-in escape hatch:

```dart
Hint(message: '...', absorbChildInput: true, child: somethingInert)
```

It puts a transparent hit layer above the child, so it also stops the child receiving pointers. Do not use it on an interactive child.

## Rich and interactive bubbles

```dart
Hint(
  interactive: true,                     // pointer may move into the bubble
  triggers: const {HintTrigger.hover, HintTrigger.tap},
  contentBuilder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Payslip #4821'),
      TextButton(onPressed: _download, child: const Text('Download')),
    ],
  ),
  child: chip,
)
```

Without `interactive: true` the bubble is decorative: it ignores pointers entirely, so a tap goes to whatever is underneath. With it, moving the pointer from the target into the bubble does not dismiss it, and buttons and links inside actually work.

## Guided tours

```dart
TourScope(
  storage: MyTourStorage(),                       // optional, see Persistence
  tourLengths: const {'onboarding': 4},           // optional, see below
  child: MaterialApp(...),
)

HintTarget(
  tour: 'onboarding',
  order: 1,
  title: 'Check in here',
  description: 'Tap this once you arrive at the centre.',
  spotlight: SpotlightShape.circle,
  spotlightPadding: const EdgeInsets.all(8),
  passthrough: true,
  child: checkInButton,
)

Tour.read(context).start('onboarding');   // no-ops if storage says it is done
```

Steps are ordered by `order`, not by tree position, so gaps are fine — numbering 10, 20, 30 leaves room to insert one later.

The controller is a plain `ChangeNotifier`:

```dart
final TourController tour = TourController(
  onStepChanged: (tour, index) => analytics.log('tour_step', index),
  onEnd: (tour, reason) => analytics.log('tour_${reason.name}'),
);

tour.activeTour;  tour.index;  tour.length;  tour.step;  tour.isLast;
tour.start('onboarding', force: true);   // replay
tour.next();  tour.previous();  tour.skip();  tour.finish();  tour.cancel();
```

`skip()` and `finish()` both record the tour as completed — someone who dismissed the onboarding does not want it again tomorrow. `cancel()` ends it without recording.

Keyboard is wired by default: arrows move, Enter advances, Esc skips.

### Tours across routes

A step whose target is not mounted **waits for it**. It is not skipped and nothing crashes: each step draws into whatever overlay its own target lives in, so pushing the right route resumes the tour exactly where it left off. This is the differentiator against `tutorial_coach_mark`, which needs every target present at once.

Because a tour's length can only count targets that have registered, a route-spanning tour would otherwise open reporting "1 of 2" and grow to "3 of 5" as the user navigates. Declare the real length to make the progress honest from the first step:

```dart
TourScope(tourLengths: const {'onboarding': 5}, child: MaterialApp(...))
```

### Custom step cards

```dart
HintTarget(
  tour: 'onboarding',
  order: 2,
  contentBuilder: (context, info) => MyCard(
    step: info.step,
    of: info.length,
    onNext: info.controller.next,
  ),
  child: target,
)
```

## Spotlights and passthrough

The scrim is one path — `Path.combine(difference, screen, hole)` — so the hole is genuinely transparent, not four rectangles arranged around a gap.

```dart
HintTarget(
  spotlight: SpotlightShape.circle,   // rect, roundedRect, circle, oval, custom
  pulse: true,                        // expanding ring
  passthrough: true,
  child: target,
)

// Anything else:
SpotlightShape.custom((Rect r) => Path()..addOval(r.deflate(4)))
```

`passthrough` is a real hit-test change, not an approximation: a `RenderProxyBox` returns `false` from `hitTestSelf` for positions inside the hole, so the pointer reaches the actual target with its actual gesture recognisers. Everywhere else it returns `true` and blocks.

Use it for "do the thing" steps, and advance the tour from your own callback:

```dart
HintTarget(
  passthrough: true,
  child: ElevatedButton(
    onPressed: () {
      checkIn();
      Tour.read(context).next();
    },
    child: const Text('Check in'),
  ),
)
```

Set `scrimBlur` on the theme for a `BackdropFilter` instead of a flat dim. It costs a full-screen `saveLayer` every frame, which is why it is off by default.

## Persistence

The package has no dependencies, so it ships an interface and an in-memory default rather than choosing a storage library for you:

```dart
class PrefsTourStorage implements TourStorage {
  PrefsTourStorage(this.prefs);
  final SharedPreferences prefs;

  @override
  Future<bool> isCompleted(String tour) async => prefs.getBool('tour.$tour') ?? false;

  @override
  Future<void> markCompleted(String tour) async => prefs.setBool('tour.$tour', true);

  @override
  Future<void> reset(String tour) async => prefs.remove('tour.$tour');
}
```

The default `InMemoryTourStorage` forgets on restart, so **every tour runs again on the next launch until you wire up persistence**. That is deliberate: it is obvious, it never silently loses data, and it makes the missing step impossible to overlook.

## Beacon

```dart
Beacon(
  title: 'Duplicate a shift',
  message: 'Long-press any shift in the calendar to copy it to another day.',
  child: const Icon(Icons.calendar_month),
)
```

A pulsing dot that opens a hint when tapped — the quiet alternative to a tour. The tap target is twice the dot's diameter so it clears platform minimums, and the pulse stops under `MediaQuery.disableAnimations`.

## Theming

One `ThemeExtension` themes tooltips, hints and tour cards together:

```dart
MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: Colors.indigo,
    extensions: const <ThemeExtension<dynamic>>[
      HintThemeData(
        backgroundColor: Color(0xFF1E1E24),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        arrowSize: Size(16, 8),
        maxWidth: 300,
        scrimColor: Color(0xCC000000),
      ),
    ],
  ),
)
```

Resolution is **per field**, in this order:

1. the per-instance `theme:` on a `Hint` / `HintTarget`,
2. the `HintThemeData` on `ThemeData.extensions`,
3. defaults derived from the ambient `ColorScheme`.

So overriding one colour on one hint keeps every other value from the app theme. With no configuration at all, bubbles read correctly in both light and dark mode — the defaults come from `colorScheme.inverseSurface`.

Covered: colours, border, radius, elevation and shadow, padding, arrow size and inset, gap, screen margin, max width, text styles, transition duration and curve, scrim colour and blur, spotlight radius and padding.

## Accessibility

- `Semantics(tooltip: message)` on the target, and rich content is announced when shown (`semanticsLabel`).
- `showDuration` auto-hide is **suppressed** under `MediaQuery.accessibleNavigation` — a screen-reader user cannot read a bubble that vanishes in two seconds.
- Animations collapse to instant under `MediaQuery.disableAnimations`.
- The bubble grows with `MediaQuery.textScaler` instead of clipping; the step card's controls wrap rather than overflow.
- A tour step traps focus in its card and hands it back afterwards.
- Esc dismisses a hint and skips a tour, without stealing focus from whatever has it.

## Placement

`resolvePlacement` is a pure function — no `BuildContext`, no widgets — which is why it is the most heavily tested part of the package:

1. **Side.** The preferred side if it fits, else its opposite, else the remaining sides by free space. If nothing fits, the side with the most slack.
2. **Main axis** follows from the side and the gap.
3. **Cross axis** centres on the target, then clamps into the screen margin.
4. **Arrow** points at the target's centre, clamped so the caret never rides onto a rounded corner.

It handles RTL (`HintDirection.left` means the visual right), degenerate targets, and bubbles larger than the viewport — clamped, never NaN, never off-screen. Call it directly if you are building your own overlay:

```dart
final HintPlacement placement = resolvePlacement(
  target: targetRect,
  overlay: overlaySize,
  bubble: bubbleSize,
  preferred: HintDirection.auto,
  gap: 12,
  margin: const EdgeInsets.all(8),
  arrowInset: 16,
  textDirection: TextDirection.ltr,
);
```

The bubble body and arrow are drawn as a **single combined path**, so the border stroke and drop shadow are continuous — no seam where the caret meets the body, and no shadow cast twice.

## Comparison

| | hint_kit | showcaseview | tutorial_coach_mark | just_the_tooltip | super_tooltip | feature_discovery |
| --- | --- | --- | --- | --- | --- | --- |
| Tooltips | ✅ | — | — | ✅ | ✅ | — |
| Persistent / programmatic hints | ✅ | — | — | ✅ | ✅ | — |
| Guided tours | ✅ | ✅ | ✅ | — | — | ✅ |
| Shared theme across all three | ✅ | n/a | n/a | n/a | n/a | n/a |
| Works on a **disabled** widget | ✅ | — | — | — | — | — |
| `OverlayPortal` (no leaked entries) | ✅ | — | — | — | — | — |
| `LayerLink` target tracking | ✅ | — | — | ✅ | — | — |
| Tour steps across routes | ✅ | — | — | n/a | n/a | — |
| Real hit-test passthrough | ✅ | partial | partial | n/a | n/a | — |
| Pure, unit-tested placement resolver | ✅ | — | — | — | — | — |
| Fused bubble + arrow path | ✅ | n/a | n/a | — | — | n/a |

Compiled from each package's public API and documentation at the time of writing; "partial" means the behaviour exists but is implemented by positioning transparent regions rather than by changing hit-testing. Dependency counts change often enough that they are not listed here — check pub.dev; hint_kit's is zero and is a design constraint, not a coincidence. Correct me with an issue if any row is out of date.

## Known limitations

**An ancestor `IgnorePointer` or `AbsorbPointer` blocks everything beneath it.** The hint never sees the pointer, and no amount of cleverness inside the package can change that — the event is stopped before it arrives.

```dart
// Does not work.
IgnorePointer(child: Hint(message: '...', child: button))

// Works — put the Hint outside.
Hint(message: '...', child: IgnorePointer(child: button))
```

**A tour target that has never been built cannot be scrolled to.** In a lazy `ListView`/`GridView`, an off-screen item does not exist, so it never registers and `Scrollable.ensureVisible` has nothing to call. Either use a non-lazy scroll view for pages with tour steps below the fold (the example does), or scroll to the region yourself before starting the tour. A target that *has* been built and then scrolled away is fine — it re-registers and the tour resumes.

**A running `Beacon` never lets `pumpAndSettle` settle.** Its pulse always has a frame scheduled. In widget tests, pass `autoStart: false` or pump a fixed duration.

**`Hint` needs an `Overlay` ancestor.** Anything under a `MaterialApp`/`CupertinoApp`/`Navigator` has one. A bare `runApp(Hint(...))` does not, and will tell you so.

**One `HintController` drives one `Hint`.** Attaching the same controller to two mounted hints asserts in debug, because `isShown` could not describe either honestly.

**Slivers are not targets.** A hint anchors to a `RenderBox`; wrap the target in a box widget inside the sliver.

## Contributing

Issues and PRs welcome. Before submitting:

```bash
dart format .
flutter analyze          # must be clean
flutter test             # includes golden tests for the bubble geometry
```

Goldens are the only regression net for the arrow geometry. If you change the bubble path deliberately, regenerate with `flutter test --update-goldens` and include the images in the PR.

## License

MIT — see [LICENSE](LICENSE).
