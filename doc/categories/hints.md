A bubble attached to a widget, and whatever opens it.

`Hint` is the whole feature: a tooltip on hover or long-press, a persistent
callout you open from code with a `HintController`, and — the case the package
was written for — a hint on a **disabled** control, because triggers are read
from raw pointer events rather than the gesture arena.

Start with `Hint`. Reach for `HintController` when something other than the
user opens the bubble, `HintQueue` when several should appear in turn, and
`Beacon` when the problem is that nobody has noticed the widget at all.
