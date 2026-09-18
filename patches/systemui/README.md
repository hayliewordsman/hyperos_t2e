# Tier 3 — SystemUI source patches

Changes that RRO overlays cannot express, applied to `frameworks/base` before
building a GSI.

| Patch | What it does |
|---|---|
| `0001-facet-specular-edge.patch` | Adds `FacetEdgeShader` (AGSL) and draws a specular highlight along the top of the shade scrim |
| `0002-facet-rim-darkening.patch` | Adds `FacetRimShader` (AGSL) and **chains** it onto the scrim's existing blur |
| `0003-facet-status-bar-icon-modes.patch` | Four modes for notification icons in the status bar, selected by a resource |

Apply them in order; `0002` builds on `0001`.

## Applying

```bash
cd <your tree>/frameworks/base
git apply --check ../../patches/systemui/0001-facet-specular-edge.patch   # verify first
git apply         ../../patches/systemui/0001-facet-specular-edge.patch
```

Generated against **`LineageOS/android_frameworks_base`, branch `lineage-23.0`**,
and intended to be applied to an **/e/OS `a16`** tree, which is built as a layer
over LineageOS 23 and carries the same `frameworks/base` lineage.
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

## What 0002 does

A pane of glass is optically thicker where it curves away, so it absorbs more
light at the rim than through the middle. `FacetRimShader` reproduces that,
darkening toward both vertical edges and leaving the centre untouched. The panel
gains a defined boundary without a border being drawn on it.

**This replaced an earlier refraction shader**, which displaced sampling at the
rim. Rendering the math showed it was invisible: the scrim's blur kernel is
wider than the displacement gradient, so shifting samples changes nothing once
the content behind is diffused — at 18px, at 90px, and with the order reversed.
Chromatic separation at the rim failed identically.

> On a blurred surface, effects that **displace samples** are invisible. Only
> effects that **modify values** survive.

Measured on the replacement: mean change **0.154 at the rim, 0.0000 at the
centre**. See `docs/preview/facet-rim-effect.png`.

## The trap 0002 avoids

`ScrimView` already applies a `RenderEffect` — its blur, set in `setBlurRadius`.
Calling `setRenderEffect` again would have *discarded the blur entirely*,
destroying what the design depends on while presenting as "the shader doesn't
work". `0002` composes them with `RenderEffect.createChainEffect(rim, blur)`,
which is also correct physically: diffused by the body of the glass, then
absorbed by the thicker rim.

## What 0003 does

Adds an integer resource controlling what reaches the status bar:

| Mode | Behaviour |
|---|---|
| 0 | all icons — stock Android |
| 1 | alerting only, hiding silent and ambient notifications |
| **2** | **a single icon, the most recent notification — the default** |
| 3 | hidden entirely |

The filtering happens in `NotificationIconContainerStatusBarViewModel` before the
icons are mapped, so the limit applies to what survives rather than to the
unfiltered set. Mode 2 sorts by `whenTime` first, because the source is a `Set`
and `take(1)` on an unordered collection would pick an arbitrary notification.

**Mode 2 is a single icon, not a neutral dot.** It shows the most recent
notification's own icon. A true neutral dot means substituting the drawable,
which is a substantially larger change than filtering a flow, and was not
attempted here.

Because the mode is a resource, `overlay/` carries it too — so once this patch is
built in, the mode can be changed by replacing the overlay rather than rebuilding
the ROM. On a build without 0003 the overlay entry is simply unused.

## Verification status

- all three patches `git apply --check` **pass**, in sequence, against a pristine
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
