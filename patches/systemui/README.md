# Tier 3 — SystemUI source patches

Changes that RRO overlays cannot express, applied to `frameworks/base` before
building a GSI.

| Patch | What it does |
|---|---|
| `0001-facet-specular-edge.patch` | Adds `FacetEdgeShader` (AGSL) and draws a specular highlight along the top of the shade scrim |
| `0002-facet-edge-refraction.patch` | ⚠️ **Do not build as-is — proven ineffective.** See below |

Apply them in order; `0002` builds on `0001`.

## Applying

```bash
cd <your tree>/frameworks/base
git apply --check ../../patches/systemui/0001-facet-specular-edge.patch   # verify first
git apply         ../../patches/systemui/0001-facet-specular-edge.patch
```

Generated against **`LineageOS/android_frameworks_base`, branch `lineage-23.0`**.
It should port across nearby branches, but re-check with `--check` first; the
`ScrimView.onDraw` hunk is the part most likely to drift.

## What 0001 does

Blur alone reads as frosted plastic. What makes a surface look like *glass* is
the edge — a narrow bright band where the surface curves away and catches light.
The patch adds:

- **`com/android/systemui/facet/FacetEdgeShader.kt`** — a `RuntimeShader`
  following the pattern SystemUI already uses in `DwellRippleShader`. The AGSL
  computes a squared falloff from the top edge, multiplied by a centre bias so
  the highlight reads as a curved surface rather than a painted stripe, and
  returns premultiplied alpha.
- **A hook in `ScrimView.onDraw`** that draws the highlight after the scrim
  drawable. Intensity tracks the scrim's own alpha, so the edge fades with the
  panel instead of appearing detached. The shader and paint are created lazily
  and the draw is bounded to `3 × thickness`, since the falloff is already
  transparent beyond that and drawing the full height would waste fill rate.

## ⚠️ 0002 does not work

Rendering the shader math before building (see `docs/preview/`) showed the
refraction is **invisible**: at 18px, at 90px, and with the order reversed, the
result is indistinguishable from blur alone. A 24px blur kernel is wider than
the displacement gradient, so sample-shifting vanishes into it.

Chromatic separation at the rim fails identically. **Rim darkening works**,
because it modifies values rather than displacing samples.

The patch is kept for its `createChainEffect` plumbing, which is correct and
reusable, but the shader it chains should be replaced with a value-modifying rim
treatment before anyone spends a build on it.

## What 0002 does, and the trap it avoids

Real glass is thickest where it curves away, so light near the rim is displaced
further than light through the middle. The shader reproduces that: sampling is
pushed inward at both vertical edges, falling to nothing across the centre.

**`ScrimView` already applies a `RenderEffect`** — its blur, set in
`setBlurRadius`. Calling `setRenderEffect` again for the refraction would have
*discarded the blur entirely*, destroying the effect this whole design depends
on, and it would have looked like the shader simply "didn't work".

So `0002` composes them with `RenderEffect.createChainEffect(refraction, blur)`.
That is also the right order physically: light is diffused by the body of the
glass, then bent as it leaves the curved rim.

## Verification status

- both patches `git apply --check` **pass**, in sequence, against a pristine
  `lineage-23.0` tree
- every symbol introduced is declared or imported, checked explicitly. On
  `0001` the import was missing on the first attempt and would not have
  compiled, despite the diff looking healthy

**Not compiled and not run.** There is no Android SDK or build tree in the
environment this was written in. Treat it as reviewed-but-unbuilt: expect to fix
something on first compile.

## Depends on blur actually working

The edge highlight is drawn regardless, but it only makes sense on top of a
blurred surface. That needs
`ro.surface_flinger.supports_background_blur=1`, which is a property, not a
resource — see `docs/glass-ui.md`.
