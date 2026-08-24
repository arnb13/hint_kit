# hint_kit

[![pub package](https://img.shields.io/pub/v/hint_kit.svg)](https://pub.dev/packages/hint_kit)
[![pub points](https://img.shields.io/pub/points/hint_kit)](https://pub.dev/packages/hint_kit)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/arnb13/hint_kit/blob/master/LICENSE)

Flutter toolkit for **tooltips, persistent hints, and guided tours** using one overlay engine, placement resolver, theme, and controller pattern.

It supports disabled widgets, route-spanning tours, real spotlight passthrough, reusable themes, animations, persistence, localization, analytics, and accessibility — with **zero runtime dependencies**.

## Screenshots

| Hints, designs and animations | A four-step guided tour |
| --- | --- |
| ![A hint on a disabled button, three of the ready-made designs, the transitions, a hand-drawn caret and a show-once callout](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/hints.gif) | ![A tour: the spotlight travels between targets, step 3 expands a panel first, and step 4 waits for another route](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/tour.gif) |

Both recorded on a device from `example/`, captioned as they go. The tour is the one worth watching: the spotlight **travels** between targets rather than cutting, step 3 expands a panel before it appears, and step 4 waits until you push the route it lives on.

| A hint on a **disabled** button | The `branded` preset | The `glass` preset |
| --- | --- | --- |
| [![A dark tooltip pointing at a disabled Check in button](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/1-hint-on-disabled.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/1-hint-on-disabled.png) | [![A tinted bubble using the branded preset](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/2-preset-branded.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/2-preset-branded.png) | [![A translucent bubble over a blurred background](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/3-preset-glass.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/3-preset-glass.png) |

| A tour step, spotlight and all | A retinted, lighter scrim | Dark mode, unconfigured |
| --- | --- | --- |
| [![A passthrough tour step with a hole cut in the scrim](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/4-tour-step.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/4-tour-step.png) | [![The same tour over a navy scrim at 55%, with the controls that set it](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/5-scrim-tinted.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/5-scrim-tinted.png) | [![The same screen in dark mode with an inverted bubble](https://raw.githubusercontent.com/arnb13/hint_kit/master/screenshots/6-dark-mode.png)](https://github.com/arnb13/hint_kit/blob/master/screenshots/6-dark-mode.png) |

Every one of these is the example app on a device — nothing is mocked up. Run it yourself: `cd example && flutter run`.

## Features

- 🚫 **Disabled widgets** — show hints even when the child is disabled.
- 🗺️ **Guided tours** — ordered steps that can continue across routes.
- 🔦 **Spotlight** — real scrim hole with optional hit-test passthrough.
- 🎨 **10 presets** — `material`, `minimal`, `soft`, `contrast`, `branded`, `sharp`, `card`, `glass`, `cupertino`, `adaptive`.
- ✨ **Animations** — `scale`, `fade`, `pop`, `slide`, `none`, or custom.
- 💾 **Persistence** — show-once hints and interrupted-tour resume.
- 🌍 **Localization** — custom labels and progress formatting.
- 📊 **Analytics** — app-wide hint and tour observer.
- ♿ **Accessibility** — semantics, focus handling, text scaling, high contrast, reduced motion, and Esc support.
- 📦 **Zero dependencies** — pure Flutter.

## Install

```yaml
dependencies:
  hint_kit: ^1.1.0
```

or:

```bash
flutter pub add hint_kit
```

```dart
import 'package:hint_kit/hint_kit.dart';
```

## Quick start

### Hint

```dart
Hint(
  message: 'You need an active shift to check in',
  child: ElevatedButton(
    onPressed: null,
    child: const Text('Check in'),
  ),
);
```

`Hint` supports `tap`, `longPress`, `hover`, `focus`, `manual`, `onAppear`, and `secondaryTap` triggers.

### Controller

```dart
final controller = HintController();

Hint(
  controller: controller,
  triggers: const {HintTrigger.manual},
  message: 'Saved successfully',
  child: saveButton,
);

controller.show();
controller.hide();
controller.toggle();
```

## Guided tours

Wrap the application with `TourScope` and mark the steps with `HintTarget`:

```dart
TourScope(
  child: MaterialApp(
    home: HintTarget(
      tour: 'onboarding',
      order: 1,
      title: 'Start here',
      description: 'Tap this button to continue.',
      child: const Text('Check in'),
    ),
  ),
);
```

Start the tour with:

```dart
Tour.read(context).start('onboarding');
```

Control a tour with:

```dart
tour.next();
tour.previous();
tour.skip();
tour.finish();
tour.cancel();
```

Tours can wait for targets that are not currently mounted, making route-spanning onboarding possible.

## Spotlight & passthrough

```dart
HintTarget(
  tour: 'onboarding',
  order: 1,
  spotlight: SpotlightShape.circle,
  passthrough: true,
  child: checkInButton,
)
```

With `passthrough: true`, interaction inside the spotlight can reach the actual target.

## Show once

Display a hint only once:

```dart
Hint(
  showOnce: 'payslip-tip',
  triggers: const {HintTrigger.onAppear},
  message: 'Payslips live here now',
  child: payslipTab,
);
```

For persistent storage, assign your own `TourStorage` implementation:

```dart
TourScope(
  storage: myStorage,
  child: const MyApp(),
);

HintRegistry.instance.storage = myStorage;
```

## Theming

Configure a shared theme with `HintThemeData`:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: const [
      HintThemeData(
        preset: HintPreset.branded,
        maxWidth: 320,
      ),
    ],
  ),
);
```

Or configure an individual hint:

```dart
Hint(
  theme: const HintThemeData(
    preset: HintPreset.glass,
  ),
  message: 'This is a glass-style hint',
  child: button,
);
```

Themes control colors, borders, radius, elevation, padding, arrow, placement spacing, typography, transitions, blur, scrim, and spotlight settings.

## Rich bubbles

Use `contentBuilder` for custom interactive content:

```dart
Hint(
  interactive: true,
  triggers: const {HintTrigger.hover, HintTrigger.tap},
  contentBuilder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Payslip #4821'),
      TextButton(
        onPressed: _download,
        child: const Text('Download'),
      ),
    ],
  ),
  child: chip,
);
```

## Beacon

For a lightweight alternative to a full tour:

```dart
Beacon(
  title: 'Duplicate a shift',
  message: 'Long-press a shift to copy it.',
  pulseCount: 3,
  child: const Icon(Icons.calendar_month),
);
```

## API surface

| Type | Purpose |
| --- | --- |
| `Hint` | Tooltip / hint widget |
| `HintController` | Programmatic hint control |
| `HintTarget` | Guided-tour step |
| `TourScope` | Tour configuration and storage |
| `TourController` | Start and control tours |
| `HintThemeData` | Shared and per-widget styling |
| `HintPreset` | Ready-made designs |
| `HintQueue` | Sequential hints without a tour |
| `Beacon` | Pulsing hint indicator |
| `HintObserver` | Analytics / lifecycle events |
| `TourStorage` | Persistence for tours and show-once hints |
| `resolvePlacement` | Pure placement resolver |

## Requirements

- Flutter **3.24+**
- Dart **3.5+**
- Android, iOS, web, macOS, Windows, Linux

## Notes

- `Hint` requires an `Overlay` ancestor, normally provided by `MaterialApp`, `CupertinoApp`, or `Navigator`.
- An ancestor `IgnorePointer` or `AbsorbPointer` can prevent the hint from receiving pointer events.
- Lazy off-screen list items cannot be targeted until they are built.
- The default `InMemoryTourStorage` does not persist between app launches.
- A `Beacon` with unlimited pulsing can keep widget tests from settling; use `pulseCount` or disable auto-start.

## Links

- [Pub.dev](https://pub.dev/packages/hint_kit)
- [Repository](https://github.com/arnb13/hint_kit)
- [Issues](https://github.com/arnb13/hint_kit/issues)

## License

MIT
