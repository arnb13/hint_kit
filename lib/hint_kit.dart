/// Tooltips, hints and guided tours built on a single overlay engine.
///
/// Everything the package exposes is re-exported from here. Nothing under
/// `src/` is public except the names this barrel lists, and the `show` clauses
/// are deliberate: they keep package-internal plumbing — controller
/// attachment, the dismissible-hint interface — out of the public API.
///
/// The three features are one engine:
///
/// * [Hint] anchors a bubble to any widget, on a trigger or on command.
/// * The same bubble, with `HintTrigger.manual` or `onAppear`, is a persistent
///   hint — including on a disabled widget.
/// * [HintTarget] inside a [TourScope] is that bubble plus a spotlight and a
///   sequencer.
///
/// @docImport 'src/tooltip/hint.dart';
/// @docImport 'src/tour/hint_target.dart';
/// @docImport 'src/tour/tour_scope.dart';
library;

export 'src/core/hint_arrow.dart' show HintArrowShape;
export 'src/core/hint_side.dart' show HintDirection, HintSide;
export 'src/core/hint_trigger.dart' show HintTrigger;
export 'src/core/measure_size.dart' show MeasureSize, SizeChangedCallback;
export 'src/core/placement.dart' show HintPlacement, resolvePlacement;
export 'src/core/rect_tracker.dart' show HintRectTracker, RectTrackingMode;
export 'src/theme/hint_theme.dart' show HintThemeData, ResolvedHintTheme;
export 'src/tooltip/anchored_bubble.dart' show AnchoredHintBubble;
export 'src/tooltip/hint.dart' show Hint, HintContentBuilder;
export 'src/tooltip/hint_bubble.dart'
    show HintBubbleContent, HintBubbleDecoration, buildBubblePath;
export 'src/tooltip/hint_controller.dart' show HintController;
export 'src/tooltip/hint_registry.dart' show HintRegistry;
export 'src/tour/hint_target.dart'
    show HintTarget, TourStepBuilder, TourStepCard, TourStepInfo;
export 'src/tour/spotlight.dart'
    show RenderSpotlightBlocker, Spotlight, SpotlightShape;
export 'src/tour/tour_controller.dart'
    show TourController, TourEndCallback, TourEndReason, TourStepCallback;
export 'src/tour/tour_scope.dart' show Tour, TourScope, TourScopeState;
export 'src/tour/tour_storage.dart' show InMemoryTourStorage, TourStorage;
export 'src/widgets/beacon.dart' show Beacon;
