# Facet preview renders

**These are not screenshots.** Nothing in this repo has been compiled. Each image
is the output of evaluating the *same math* the AGSL shaders compute, in Python,
so the design can be checked before spending a build cycle on it.

| File | What it shows |
|---|---|
| `facet-edge-term.png` | The specular edge term alone — squared falloff from the top, biased toward centre |
| `facet-refraction-field.png` | The refraction displacement field — inward at both rims, zero across the middle |
| `facet-panel.png` | Composed panel: blur → tint → refraction → edge highlight |
| `facet-refraction-negative.png` | Evidence that the refraction does nothing (see below) |
| `facet-rim-comparison.png` | Control vs chromatic rim vs rim darkening |

## What these renders caught

**The refraction shader is a no-op.** `facet-refraction-negative.png` shows three
rows: strength 18px, strength 90px, and refraction applied *before* the blur
instead of after. All three are indistinguishable. A 24px blur kernel is wider
than the displacement gradient, so horizontal sample-shifting disappears into it
in either order.

**Chromatic separation at the rim fails for the same reason.**
`facet-rim-comparison.png` row B is indistinguishable from the control: sampling
R, G and B at different offsets over already-smooth content returns nearly the
same colour.

**Rim darkening works.** Row C is clearly different — the panel gains definition
at its vertical edges.

## The principle

> On a blurred surface, any effect that works by **displacing samples** is
> invisible. Only effects that **modify values** — brightness, tint, contrast —
> survive the blur.

That rules out refraction and chromatic aberration, and points at rim darkening,
the top edge highlight, and tint as the tools that actually do the work.

This is why `patches/systemui/0002` should not be built as it stands: it costs
GPU time for no visible result.
