# Hero wordmark animation — "Clear Next Step" settles from sand

> **Scope:** the animated wordmark at the top of the brain-dump (first) screen
> (`BrainDumpView.swift`), rendered by `SandTextView`
> (`Unstickit/Vendor/AnimationLoadersKit/LoadingSandTextStreamView.swift`).

## Problem

The original animation streamed sand grains *continuously* around the letter
**outlines** and never resolved. Two consequences:

- **The wordmark was never readable.** Grains perpetually orbited the contours,
  so "Clear Next Step" never formed a legible, solid shape — the opposite of what
  a hero wordmark should do.
- **Neutral, off-brand color.** Grains were drawn in `.primary` (black in light
  mode, white in dark), giving the hero moment no color identity.

## Decision

The wordmark now performs a **one-shot settle**: sand grains flow in, converge
onto the letters, and **fill in to a solid, readable "Clear Next Step" over ~2.5
seconds**, then hold. Reading the settled wordmark is the point; the sand is the
entrance, not a permanent state.

Specifics:

1. **Settle, don't loop.** Over a `settleDuration` (~2.5s, within the requested
   2–3s), a `settle` progress ramps 0 → 1:
   - the grains' radial spread collapses toward the glyph contours (they "gather"
     onto the letters), and their opacity fades out; and
   - a **solid fill** of the actual glyph paths fades in (even-odd fill so
     counters in `e`, `a`, `p` stay open).
   After settle the grains are gone and the solid wordmark remains — no
   continuous churn.
2. **Blue, adaptive to appearance.** The sand and the settled fill are blue, with
   a light/dark variant supplied by the call site:
   - light mode: a deeper, higher-contrast blue on the light background;
   - dark mode: a lighter, airier blue so it reads on the dark background.
   `SandTextView` stays color-agnostic (takes a `dotColor`); the appearance
   choice lives in `BrainDumpView` via `@Environment(\.colorScheme)` so the view
   layer owns theming.
3. **Typeface: Georgia Bold** (chosen after trialing SF Black, SF Rounded, Futura,
   Helvetica Neue, and Arial Black in the running app). A warm, familiar serif
   reads as calm and comforting and pairs deliberately with the sans-serif UI
   below it. The glyph path is built from the font **descriptor**, not
   `font.fontName` — the system font's internal name (`.SFUI-…`) does not resolve
   through `CTFontCreateWithName` and silently falls back to a serif (Times),
   dropping the weight; the descriptor preserves the intended face and weight.
4. **Optional faux-bold (`weightBoost`).** `SandTextView` can fatten any face by
   stroking the glyph outline over the fill (a fraction of the wordmark height).
   It is **retained but set to 0** for Georgia — the serifs read crisper at the
   font's own weight. It exists so a lighter face can be thickened without
   swapping fonts.

## Consequences

+ The hero wordmark is finally **legible** and owns a color identity, matching
  the calm, intentional tone of the product (`copy_principles.md`).
+ The settle is a one-shot, so once formed the wordmark stops animating — cheaper
  than a permanent grain field and less visually noisy behind the prompt
  (keeps the brain-dump the primary affordance).
− The solid fill is reconstructed from the flattened glyph contours rather than a
  live `CTFont` fill; acceptable for a display wordmark at this size.
− `TimelineView(.animation)` keeps ticking after settle; invisible grains are
  skipped and only one cheap fill path is drawn per frame, so the residual cost
  is negligible. Revisit if it ever shows on a profiler.
