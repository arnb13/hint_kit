A scrim, a spotlight and a sequence of steps.

A tour is the same bubble the hints use, plus a hole cut in a dim overlay and
something to advance it. Wrap the app in a `TourScope`, mark each step with a
`HintTarget`, and start it with `Tour.of(context).start('onboarding')`.

Steps render through their own target's overlay, so a tour can cross routes: a
step whose target is not on screen yet simply waits for it. `TourStorage`
decides whether a finished tour stays finished after a restart.
