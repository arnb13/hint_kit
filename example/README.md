# hint_kit example

A runnable demonstration of everything in [hint_kit](../).

```bash
flutter run
```

One file per feature, under `lib/sections/`:

| File | Shows |
| --- | --- |
| `disabled_widgets.dart` | a hint on a **disabled** `ElevatedButton` — long-press it |
| `programmatic_hints.dart` | `HintController`, and tour step 2 (**passthrough**) |
| `rich_bubbles.dart` | an interactive tooltip whose buttons actually work |
| `presets.dart` | the ready-made designs, and one built from a preset |
| `animations.dart` | the transitions, a custom one, and a hand-drawn caret |
| `show_once.dart` | `showOnce`, and resetting it |
| `tip_queue.dart` | `HintQueue`: three tips, one after another |
| `desktop_and_web.dart` | right-click, cursors, a bubble that follows the pointer |
| `scrim.dart` | how dark the tour is — colour and opacity, separately |
| `beacon.dart` | `Beacon` |
| `scroll_tracking.dart` | a hint that tracks its target through a scroll |
| `below_the_fold.dart` | tour step 3: off screen, and `beforeShow` |

The rest: `main.dart` wires the `TourScope`, theme, observer and storage;
`home_page.dart` holds the app-bar toggles and tour step 1; `details_page.dart`
is the second route, where tour step 4 waits.

Android and web platform files are checked in. For another platform:

```bash
flutter create --platforms=ios,macos,windows,linux .
```
