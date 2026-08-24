# Changelog

## 1.1.1

- Updated README documentation.

## 1.1.0

- Added `HintTarget(enabled: false)` for conditional tour steps.
- Added `TourScope.stepTimeout` and `onStepUnavailable` for unavailable steps.
- Removed generated `lib/generated/assets.dart`.
- Updated README with troubleshooting and conditional-step documentation.

## 1.0.0

- Stable 1.x API; no API changes from 0.1.0.
- Added updated README with screenshots, features, installation, and requirements.
- Fixed image URLs for pub.dev.

## 0.1.0

### Hints

- Added `Hint` with tap, long-press, hover, focus, appear, and manual triggers.
- Supports **disabled widgets**.
- Added `HintController` for programmatic control.
- Added interactive custom content.
- Added app-wide exclusivity and show/dismiss callbacks.
- Uses `OverlayPortal` and target tracking.

### Tours

- Added `TourScope`, `TourController`, and `HintTarget`.
- Supports tours across routes.
- Added spotlight shapes, pulse, blur, and hit-test passthrough.
- Added customizable step cards and keyboard controls.
- Added `TourStorage` and resumable tours.
- Added `beforeShow`, `enabled`, and step timeout support.

### Theming & UI

- Added `HintThemeData` and 10 presets.
- Added custom transitions and arrows.
- Added localization with `TourLabels`.
- Added `Hint.showOnce`.
- Added `HintQueue`.
- Added `Beacon`.
- Added desktop/web support including right-click and pointer-following hints.

### Developer tools

- Added `HintObserver` and analytics events.
- Added `CallbackTourStorage`.
- Added `resolvePlacement`.
- Added `package:hint_kit/testing.dart` with test helpers.
- Added GitHub Actions CI and example deployment.

### Fixes

- Applied `transitionCurve` correctly.
- Added `triangle` and `curved` arrow shapes.
- Improved spotlight movement and placement handling.
