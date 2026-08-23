# hint_kit

Tooltips, persistent hints and spotlight guided tours — from **one overlay engine, one placement resolver, one theme and one controller pattern**.

**Zero runtime dependencies.** Pure Flutter, WASM-safe, no `dart:io`, no `dart:html`.

<!-- pub.dev needs an absolute URL for images, so these are served from the
     repository rather than by a relative path. -->
<img src="https://raw.githubusercontent.com/arnb13/hint_kit/master/doc/hint_kit.gif" alt="hint_kit: a hint on a disabled button, four designs, a queue of tips, a beacon, the scrim being retinted, and a four-step tour that crosses a route" width="300">

Recorded from `example/`: a hint on a **disabled** button, four of the ten ready-made designs, a transition and a hand-drawn caret, a show-once callout, a queue of tips, a `Beacon`, the scrim's colour and opacity being changed live — then the four-step tour, with the spotlight travelling between targets, a step that expands a panel before it appears, and a last step that waits on another route.

<img src="https://raw.githubusercontent.com/arnb13/hint_kit/master/doc/screenshots.png" alt="Four screenshots: a hint on a disabled button, the branded preset, a tour step with its spotlight, and the same screen in dark mode">

*A hint on a disabled button · the `branded` preset · a passthrough tour step, spotlight and all · the same screen in dark mode, where the defaults invert on their own.*

Run it yourself: `cd example && flutter run`.

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

**[Hints](#hints)** · [triggers and control](#triggers-and-control) · [on disabled widgets](#on-disabled-widgets) · [rich bubbles](#rich-and-interactive-bubbles) · [show once](#show-a-hint-once-ever) · [a sequence of tips](#a-sequence-of-tips-without-a-tour) · [desktop and web](#desktop-and-web) · [beacon](#beacon)

**[Tours](#tours)** · [steps and control](#steps-and-control) · [across routes](#across-routes) · [spotlight and passthrough](#spotlight-and-passthrough) · [how dark the scrim is](#how-dark-the-scrim-is) · [preparing the UI first](#preparing-the-ui-before-a-step) · [resuming](#resuming-a-tour) · [custom cards](#custom-step-cards) · [localisation](#localisation)

**[Theming](#theming)** · [ready-made designs](#ready-made-designs) · [your own design](#your-own-design) · [the arrow](#the-arrow) · [animations](#animations)

**Everything else** · [persistence](#persistence) · [analytics](#analytics) · [accessibility](#accessibility) · [testing](#testing) · [placement](#placement) · [comparison](#comparison) · [known limitations](#known-limitations)

---

## Hints

### Triggers and control

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
| `secondaryTap` | Right-click, so the primary click stays the widget's |

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

### On disabled widgets

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

### Rich and interactive bubbles

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

### Show a hint once, ever

The "new feature" callout that must not nag:

```dart
Hint(
  showOnce: 'payslip-tip',
  triggers: const {HintTrigger.onAppear},
  message: 'Payslips live here now',
  child: payslipTab,
)
```

The key is recorded as the bubble opens, and every later attempt to show it does nothing — trigger, `onAppear` *or* `HintController.show()`, so "once" holds however the hint is opened. Reading the flag is asynchronous and an `onAppear` hint waits for it, which is what stops the race on launch that the feature exists to prevent.

Keys live in `HintRegistry.instance.storage` — the same `TourStorage` interface tours use, so one implementation serves both (see [Persistence](#persistence)):

```dart
void main() {
  HintRegistry.instance.storage = myStorage;
  runApp(const MyApp());
}

// Let it show again:
await HintRegistry.instance.resetShowOnce('payslip-tip');
```

### A sequence of tips, without a tour

A tour dims the screen, traps focus and takes over. Sometimes you just want three tips in order:

```dart
final tips = HintQueue(<HintController>[_filterTip, _sortTip, _exportTip]);

tips.start();
```

Each entry drives a `Hint` with `HintTrigger.manual`. The queue opens the first, waits for it to close — however it closes: a tap outside, `showDuration`, Esc, another hint taking the floor — then opens the next after a short `gap`. `next()` skips ahead, `stop()` ends it, and `onFinished` tells you whether it ran out or was cut short. A queue that reaches a hint whose widget is no longer mounted stops rather than opening a bubble pointing at nothing.

### Desktop and web

```dart
Hint(
  triggers: const {HintTrigger.secondaryTap},   // right-click
  mouseCursor: SystemMouseCursors.help,         // over the target
  message: 'Right-click explains this',
  child: row,
)

Hint(
  followPointer: true,                          // the bubble tracks the cursor
  triggers: const {HintTrigger.hover},
  message: 'What is under the pointer, not what is under the widget',
  child: chart,
)
```

`secondaryTap` reads the pointer's buttons, so it never competes with a child's own secondary-tap handler and a primary click does not open it. `followPointer` re-anchors the bubble to the cursor on every move and still runs the full placement resolver, so it flips sides near a screen edge instead of sliding off it; with no pointer — a hint opened from a controller — it falls back to the widget.

### Beacon

```dart
Beacon(
  title: 'Duplicate a shift',
  message: 'Long-press any shift in the calendar to copy it to another day.',
  pulseCount: 3,                          // then it settles into a static dot
  child: const Icon(Icons.calendar_month),
)
```

A pulsing dot that opens a hint when tapped — the quiet alternative to a tour. The tap target is twice the dot's diameter so it clears platform minimums, and the pulse stops under `MediaQuery.disableAnimations`.

`pulseCount` is worth setting: a dot that pulses for ever keeps competing with the rest of the screen, and it also stops `pumpAndSettle` returning in a widget test. Omit it to pulse indefinitely.

---

## Tours

### Steps and control

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

`skip()` and `finish()` both record the tour as completed — someone who dismissed the onboarding does not want it again tomorrow. `cancel()` ends it without recording, which is what makes [resuming](#resuming-a-tour) work.

Keyboard is wired by default: arrows move, Enter advances, Esc skips.

### Across routes

A step whose target is not mounted **waits for it**. It is not skipped and nothing crashes: each step draws into whatever overlay its own target lives in, so pushing the right route resumes the tour exactly where it left off. This is the differentiator against `tutorial_coach_mark`, which needs every target present at once.

Because a tour's length can only count targets that have registered, a route-spanning tour would otherwise open reporting "1 of 2" and grow to "3 of 5" as the user navigates. Declare the real length to make the progress honest from the first step:

```dart
TourScope(tourLengths: const {'onboarding': 5}, child: MaterialApp(...))
```

### Spotlight and passthrough

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

Between steps the hole **travels** from the previous target to the next one rather than cutting, which is what makes a tour read as one continuous thing instead of a slideshow:

```dart
HintThemeData(spotlightMoveDuration: Duration.zero)   // opt back out
```

The animation is over a fraction, not over a rect, so the destination stays live: a target that scrolls or resizes mid-travel is still followed, and once the fraction reaches 1 the hole is exactly the tracked rect with no interpolation left to lag behind it. The first step of a tour has nothing to travel from, so it simply lights up; `MediaQuery.disableAnimations` cuts as well.

### How dark the scrim is

The dim defaults to **90% in light mode and 95% in dark** — a tour step is modal, and a scrim light enough to read the page through invites the user to keep reading the page instead of the step. Colour and opacity are separate settings:

```dart
TourScope(
  theme: const HintThemeData(scrimOpacity: 0.75),   // lighter, still neutral
  child: const MyApp(),
)

// A tint of your own. The colour's own alpha sets the dim…
HintThemeData(scrimColor: const Color(0xE60B1B3A))

// …unless scrimOpacity is also set, which replaces it.
HintThemeData(scrimColor: const Color(0xFF0B1B3A), scrimOpacity: 0.8)
```

`scrimOpacity` replaces the alpha of whatever colour is in play — an explicit `scrimColor`, a preset's, or the default — so a slider bound to it works without touching the hue. It is clamped to 0..1, and `0` removes the dim entirely while keeping the spotlight and the step card. It is an ordinary theme field, so `HintTarget(theme: ...)` overrides `TourScope(theme: ...)` overrides `ThemeData.extensions`.

Presets keep their own dims on purpose — `minimal` and `cupertino` are deliberately lighter, `contrast` is nearly solid — so setting `scrimOpacity` alongside a preset is how you overrule that.

Set `scrimBlur` for a `BackdropFilter` instead of a flat dim. It costs a full-screen `saveLayer` every frame, which is why it is off by default.

### Preparing the UI before a step

A step can open the thing it is about to point at, and the tour waits for it:

```dart
HintTarget(
  tour: 'onboarding',
  order: 3,
  beforeShow: () async => _controller.expandPanel(),
  title: 'Your saved filters live here',
  child: drawerItem,
)
```

Nothing is drawn until the future completes — no scrim, no card, no spotlight — and if the user leaves the step while it is still running, the result is discarded rather than opening a step the tour has moved past.

### Resuming a tour

A user who quits three steps into onboarding should not start again from step one:

```dart
// On launch, or behind a "Continue" button:
tour.start('onboarding', resume: true);

// Decide between "Start" and "Continue" without starting anything:
final bool canResume = await tour.hasProgress('onboarding');
```

The position is written on every step change and cleared when the tour **finishes or is skipped**, so only an interrupted tour resumes — a closed app, a killed process, a `cancel()`. A good place for that `cancel()` is the lifecycle handler:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused && tour.isRunning) {
    tour.cancel();      // keeps the position; skip() and finish() clear it
  }
}
```

It needs a storage that implements `lastIndex`/`saveIndex`; `InMemoryTourStorage` does (for the session), `CallbackTourStorage` takes them as two more optional closures, and the defaults on `TourStorage` do nothing — so a storage written before this existed keeps working and simply never resumes.

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

### Localisation

The package ships no translations — zero dependencies rules out `intl` and generated ARB lookups. Every word on the step card is a value instead, so it comes from whatever localisation the app already has:

```dart
TourScope(
  labels: TourLabels(
    skip: l10n.tourSkip,
    back: l10n.tourBack,
    next: l10n.tourNext,
    done: l10n.tourDone,
    progress: (step, length) => l10n.tourProgress(step, length),
  ),
  child: const MyApp(),
)
```

`progress` takes a callback rather than a format string on purpose: "2 of 5", "2 / 5" and "5 中 2" cannot all come from substituting into one template.

Custom step cards get the same labels through `TourStepInfo.labels`, so replacing the card does not un-localise the tour:

```dart
contentBuilder: (context, info) => Column(children: [
  Text(info.title ?? ''),
  TextButton(
    onPressed: info.controller.next,
    child: Text(info.labels.advance(isLast: info.isLast)),
  ),
]),
```

---

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
        scrimOpacity: 0.85,
      ),
    ],
  ),
)
```

Resolution is **per field**, in this order:

1. the per-instance `theme:` on a `Hint` / `HintTarget`,
2. the `HintThemeData` on `ThemeData.extensions`,
3. the `HintPreset` named by whichever of those set one,
4. defaults derived from the ambient `ColorScheme`.

So overriding one colour on one hint keeps every other value from the app theme. With no configuration at all, bubbles read correctly in both light and dark mode — the defaults come from `colorScheme.inverseSurface`.

Covered: colours, border, radius, elevation and shadow, padding, arrow size, shape, inset and custom path, gap, screen margin, max width, text styles, transitions and their duration and curve, background blur, scrim colour, opacity and blur, spotlight radius, padding and travel time.

### Ready-made designs

Ten presets, one line each. A preset is a starting point, not a mode: it fills in the fields you have not set, and anything you *do* set still wins. Each carries its own motion as well as its own paint.

```dart
// The whole app.
extensions: const <ThemeExtension<dynamic>>[
  HintThemeData(preset: HintPreset.soft),
],

// One hint.
Hint(theme: const HintThemeData(preset: HintPreset.branded), ...)

// A preset with one thing changed — everything else stays the preset's.
Hint(theme: const HintThemeData(preset: HintPreset.soft, maxWidth: 360), ...)
```

| Preset | Look | Use it for |
| --- | --- | --- |
| `material` | The package default: a raised chip that inverts with the theme | Anything |
| `minimal` | Flat, outlined, no shadow, tight | Dense, information-heavy UIs |
| `soft` | Big radius, roomy padding, curved balloon tail, slight overshoot | Consumer apps, onboarding |
| `contrast` | Pure black on white (inverted in dark), heavier type, no shadow | Legibility, `MediaQuery.highContrast` |
| `branded` | `primaryContainer` fill, `primary` outline, scrim tinted to match | Making hints look like your product |
| `sharp` | Square corners, hairline outline, fast flat transition | Desktop tools, editors, tables |
| `card` | Wide, padded, elevated, blurred scrim | Tour steps, rich interactive bubbles |
| `glass` | Translucent fill over a blurred background, hairline lit edge | Over photos, maps, dense lists |
| `cupertino` | iOS popover: light panel, 13pt radius, soft shadow, light dim | iOS-flavoured apps |
| `adaptive` | `cupertino` on iOS and macOS, `material` everywhere else | One app, both platforms |

Presets do not hard-code a palette they do not need: where a design is defined by its shape, colours are left to the ambient `ColorScheme`, so the same preset is correct in light and dark. Where the design *is* a colour choice — `contrast`, `branded`, `cupertino` — it is still derived from your theme rather than fixed. `adaptive` reads `ThemeData.platform`, not the host OS, so a platform override in your theme (and `debugDefaultTargetPlatformOverride` in a test) is honoured.

### Your own design

Two ways, depending on where you want to start.

Layer over a preset, or set the fields yourself and use no preset at all:

```dart
const HintThemeData(
  preset: HintPreset.card,          // omit this for a design from scratch
  backgroundColor: Color(0xFF10131A),
  foregroundColor: Color(0xFFE7ECF5),
  borderColor: Color(0xFF3D7BFF),
  borderWidth: 1.5,
  arrowShape: HintArrowShape.curved,
)
```

Or take a preset's values as plain data and edit them — useful when you want to compute something from what the preset chose, or keep one design object in your own theme file:

```dart
final HintThemeData mine = HintPreset.card.themeData(context).copyWith(
  backgroundColor: const Color(0xFF10131A),
  arrowShape: HintArrowShape.curved,
);
```

For content that is not a title and a message at all, `contentBuilder` hands you the bubble with arbitrary widgets inside, and `HintBubbleDecoration` gives you the bubble chrome — outline, fill, fused arrow, shadow — around anything you like, with no overlay involved.

### The arrow

```dart
HintThemeData(
  arrowShape: HintArrowShape.curved,   // or .triangle, the default
  arrowSize: const Size(24, 14),       // width along the edge, depth away from it
)
```

`triangle` is the conventional straight-sided caret. `curved` gives a speech-balloon tail: each flank leaves the bubble edge *parallel to it* and falls away to the tip, so there is no corner where the caret meets the body — which is most visible on a bubble with a border. The flanks are concave, so a curved caret reads slimmer than a triangle of the same size; it suits a larger `arrowSize` and a generous corner radius.

Both shapes fill exactly the same `arrowSize` box, so switching between them changes the outline and nothing else — the bubble does not move.

For anything else, draw it yourself. The path is unioned into the bubble body like the built-in ones, so a custom caret keeps the continuous border and the single shadow:

```dart
HintThemeData(
  arrowShape: HintArrowShape.custom,
  arrowSize: const Size(26, 14),
  arrowBuilder: (HintArrowGeometry g) => Path()
    ..moveTo(g.baseStart.dx, g.baseStart.dy)
    ..quadraticBezierTo(g.baseCentre.dx, g.baseCentre.dy, g.tip.dx, g.tip.dy)
    ..lineTo(g.baseEnd.dx, g.baseEnd.dy)
    ..close(),
)
```

The geometry arrives resolved for whichever edge placement chose — `baseCentre`, `along`, `tip`, `baseStart`, `baseEnd` — so one path works on all four sides without a `switch` over `side`.

### Animations

Five ready-made transitions, and a builder for everything else:

```dart
HintThemeData(
  transition: HintTransition.pop,                 // scale | fade | pop | slide | none
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 140),
  transitionCurve: Curves.easeOutCubic,
)
```

| Transition | What it does |
| --- | --- |
| `scale` | Fade plus a small scale out of the caret. The default |
| `fade` | Opacity only |
| `pop` | Fade plus a scale that overshoots before settling |
| `slide` | Fade plus a short slide away from the target |
| `none` | No animation, and no transition widget in the tree |

Your own animation is a builder:

```dart
HintThemeData(
  transitionCurve: Curves.easeOutBack,
  transitionBuilder: (context, info, child) => FadeTransition(
    opacity: info.opacity,
    child: RotationTransition(
      turns: Tween<double>(begin: -0.03, end: 0).animate(info.animation),
      alignment: info.origin,       // the caret, so it rotates around the anchor
      child: child,
    ),
  ),
)
```

`HintTransitionInfo` hands you the curved `animation`, an `opacity` clamped to 0..1, the `side` the bubble landed on, an `origin` alignment on the caret, and `towardsTarget` for slides. Use `info.animation` for transforms and `info.opacity` for opacity: an overshooting curve drives past 1, which is what makes a bounce read — and what would make `FadeTransition` assert.

To build on a preset instead of starting from nothing, call one: `HintTransition.fade.build(context, info, myWrapper(child))`.

Every transition runs on the same animation, so duration, reverse duration and curve all apply — and all of them collapse to an instant appearance under `MediaQuery.disableAnimations`.

## Persistence

One store serves both tours and show-once hints. The shortest path from the in-memory default to something real is two closures — no subclass, no dependency:

```dart
final storage = CallbackTourStorage(
  isCompleted: (key) async => prefs.getBool('seen.$key') ?? false,
  setCompleted: (key, done) async =>
      done ? prefs.setBool('seen.$key', true) : prefs.remove('seen.$key'),
);

TourScope(storage: storage, child: const MyApp());
HintRegistry.instance.storage = storage;   // the same store for showOnce hints
```

One setter covers both writes: `markCompleted` calls it with `true` and `reset` with `false`, so the two can never disagree about where the flag lives. Add the optional `lastIndex` and `saveIndex` closures to support [resuming](#resuming-a-tour).

Implementing the interface yourself works just as well:

```dart
class PrefsTourStorage extends TourStorage {
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

## Analytics

One observer sees every hint and every tour in the app — the registry is process-global, so it does not miss bubbles on other routes or in other overlays:

```dart
class HintAnalytics extends HintObserver {
  @override
  void didShowHint(HintEvent event) =>
      analytics.log('hint_shown', {'id': event.id, 'via': event.trigger?.name});

  @override
  void didEndTour(String tour, TourEndReason reason) =>
      analytics.log('tour_${reason.name}', {'tour': tour});
}

HintRegistry.instance.addObserver(HintAnalytics());
```

`HintObserver` also has `didDismissHint`, `didStartTour` and `didChangeTourStep`. Every method has an empty default body, so you override only what you need — and extending it means a method added later will not break your class.

Give hints an `analyticsId` for a key that survives a copywriter: `HintEvent.label` falls back to the hint's text, and text changes.

## Accessibility

- `Semantics(tooltip: message)` on the target, and rich content is announced when shown (`semanticsLabel`).
- `showDuration` auto-hide is **suppressed** under `MediaQuery.accessibleNavigation` — a screen-reader user cannot read a bubble that vanishes in two seconds.
- Animations collapse to instant under `MediaQuery.disableAnimations`.
- `followHighContrast: true` on the theme adopts `HintPreset.contrast` whenever the platform asks for high contrast (`MediaQueryData.highContrast`), keeping every field you set explicitly.
- The bubble grows with `MediaQuery.textScaler` instead of clipping; the step card's controls wrap rather than overflow.
- A tour step traps focus in its card and hands it back afterwards.
- Esc dismisses a hint and skips a tour, without stealing focus from whatever has it.

## Testing

```dart
import 'package:hint_kit/testing.dart';

setUp(resetHintKit);     // the registry is process-global: reset it between tests
```

`resetHintKit()` closes whatever hint holds the floor, drops every observer and replaces the show-once storage. Without it, one test inherits the previous test's open hint and `showOnce` keys — which shows up as a hint that mysteriously refuses to appear.

The same entry point ships `FakeTourStorage` (arrange completed tours and saved positions up front, and assert on the calls it received) and `RecordingHintObserver` (a list of everything the package announced). It deliberately does not depend on `flutter_test`, so it adds nothing to your app's dependency graph — finding a bubble needs no helper, because `find.text('…')` already works.

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
| Resume an interrupted tour | ✅ | — | — | n/a | n/a | — |
| Real hit-test passthrough | ✅ | partial | partial | n/a | n/a | — |
| Pure, unit-tested placement resolver | ✅ | — | — | — | — | — |
| Localisable step-card labels | ✅ | — | ✅ | n/a | n/a | — |
| App-wide analytics observer | ✅ | — | — | — | — | — |
| Show-once hints, no tour needed | ✅ | — | — | — | — | ✅ |
| Custom caret and custom transition | ✅ | — | — | partial | partial | — |
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

**A `Beacon` that pulses for ever never lets `pumpAndSettle` settle.** Its pulse always has a frame scheduled. Give it `pulseCount:` — usually the better UX anyway — or `autoStart: false`, or pump a fixed duration.

**`Hint` needs an `Overlay` ancestor.** Anything under a `MaterialApp`/`CupertinoApp`/`Navigator` has one. A bare `runApp(Hint(...))` does not, and will tell you so.

**`showOnce` keys live in one process-global store.** `HintRegistry.instance.storage` is not scoped to a subtree, for the same reason the registry itself is not: the overlay it protects is not scoped that way either. Set it once at startup, and reset it between widget tests that rely on it.

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
