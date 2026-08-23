/// @docImport 'hint_target.dart';
/// @docImport 'tour_scope.dart';
library;

import 'package:flutter/foundation.dart';

/// Signature for rendering a step counter.
///
/// [step] is one-based and [length] is the number of steps in the tour.
typedef TourProgressBuilder = String Function(int step, int length);

/// The words on the default tour step card.
///
/// The package ships no translations — it has zero dependencies, which rules
/// out `intl` and generated ARB lookups. Instead every string on the card is a
/// value you supply, so it can come from whatever localisation your app
/// already has:
///
/// ```dart
/// TourScope(
///   labels: TourLabels(
///     skip: context.l10n.tourSkip,
///     back: context.l10n.tourBack,
///     next: context.l10n.tourNext,
///     done: context.l10n.tourDone,
///     progress: (int step, int length) =>
///         context.l10n.tourProgress(step, length),
///   ),
///   child: const MyApp(),
/// )
/// ```
///
/// [progress] takes a callback rather than a format string because word order
/// is not universal: "2 of 5", "2 / 5" and "5 中 2" cannot all be produced by
/// substituting into one template.
///
/// A step card built with [HintTarget.contentBuilder] gets the same labels via
/// [TourStepInfo.labels], so a custom card can be localised the same way
/// without reaching for a second mechanism.
@immutable
class TourLabels {
  /// Creates a set of labels. The defaults are English.
  const TourLabels({
    this.skip = 'Skip',
    this.back = 'Back',
    this.next = 'Next',
    this.done = 'Done',
    this.progress = _defaultProgress,
  });

  /// Leaves the tour without finishing it. Hidden on the last step.
  final String skip;

  /// Returns to the previous step. Hidden on the first step.
  final String back;

  /// Advances to the next step.
  final String next;

  /// Advances past the last step, ending the tour.
  final String done;

  /// Renders the "2 of 5" counter. Shown only for tours with several steps.
  final TourProgressBuilder progress;

  static String _defaultProgress(int step, int length) => '$step of $length';

  /// The label for the advance button on a given step.
  ///
  /// [done] on the last step, [next] everywhere else — the one piece of logic
  /// the card would otherwise have to repeat.
  String advance({required bool isLast}) => isLast ? done : next;

  /// Returns a copy with the given fields replaced.
  TourLabels copyWith({
    String? skip,
    String? back,
    String? next,
    String? done,
    TourProgressBuilder? progress,
  }) {
    return TourLabels(
      skip: skip ?? this.skip,
      back: back ?? this.back,
      next: next ?? this.next,
      done: done ?? this.done,
      progress: progress ?? this.progress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourLabels &&
          other.skip == skip &&
          other.back == back &&
          other.next == next &&
          other.done == done &&
          other.progress == progress;

  @override
  int get hashCode => Object.hash(skip, back, next, done, progress);

  @override
  String toString() => 'TourLabels($skip, $back, $next, $done)';
}
