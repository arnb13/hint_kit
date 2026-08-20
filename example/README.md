# hint_kit example

A runnable demonstration of everything in [hint_kit](../):

- a hint on a **disabled** `ElevatedButton` (long-press it), and the same
  button enabled, keeping its own tap
- a programmatic hint driven by a `HintController`
- a rich, interactive tooltip whose buttons actually work
- a `Beacon`
- a hint inside a scroll view that tracks its target through scrolling
- a four-step tour: one **passthrough** step, one **below the fold**, and one
  on a **different route**
- a light/dark toggle, with every hint themed from one `ThemeExtension`

```bash
flutter run
```

Only Android platform files are checked in. For another platform:

```bash
flutter create --platforms=ios,web,macos,windows,linux .
```
