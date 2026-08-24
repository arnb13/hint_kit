Extension points, and the parts the package is built from.

Nothing here is needed to use hint_kit. It is exported because the pieces are
useful on their own and because a package that hides its internals forces you
to fork it: `resolvePlacement` is the side-picking algorithm, `buildBubblePath`
the fused bubble-and-caret path, `HintRectTracker` the target tracking, and
`AnchoredHintBubble` the measure-resolve-place-animate engine that `Hint` and
`HintTarget` both run on.

`HintObserver` is the exception worth knowing about early: it reports every
hint and tour lifecycle event in one place, which is where analytics goes.
