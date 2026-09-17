# Facet — a glass design system for the Titan 2 Elite

An original glass/translucency language for Android. Not a reproduction of any
vendor's design identity; blur, depth and layering are general techniques and
this defines its own use of them.

## The key discovery

LineageOS **already ships the blur machinery** — it is just configured
conservatively. Read from `lineage-23.0`, `packages/SystemUI/res/values`:

| Resource | Stock value | Meaning |
|---|---|---|
| `config_volumeDialogUseBackgroundBlur` | `false` | volume dialog blur **off** |
| `volume_dialog_background_blur_radius` | `0dp` | …and its radius zeroed |
| `notification_scrim_transparent` | `false` | shade scrim **opaque** |
| `max_window_blur_radius` | `23px` | shallow ceiling |
| `max_shade_window_blur_radius` | `34dp` | shade blur ceiling |

Every one of these is a `bool`, `dimen` or `color` — i.e. **overridable by an
RRO, with no SystemUI recompile**. That moves most of the glass effect from
Tier 3 into Tier 2.

Tier 3 is then reserved for what resources genuinely cannot express: specular
edge highlights, custom shaders, reshaped geometry.

## The rule that governs everything here

> On a blurred surface, any effect that works by **displacing samples** is
> invisible. Only effects that **modify values** — brightness, tint, contrast —
> survive the blur.

Established by rendering the shader math rather than reasoning about it; see
`docs/preview/`. It killed the refraction shader and points at rim darkening,
the edge highlight and tint as the tools that actually do the work.

## Depth model

Glass reads as depth only if blur is *hierarchical* — a single radius everywhere
looks like frosted plastic. Facet defines five tiers:

| Tier | Radius | Used for |
|---|---|---|
| `L0` | 0 | opaque surfaces; wallpaper, app content |
| `L1` | 8dp | inline chips, inactive QS tiles |
| `L2` | 24dp | volume dialog, power menu, small popups |
| `L3` | 48dp | notification shade content |
| `L4` | 64dp | full shade window, the deepest layer |

Each tier up roughly doubles. The eye reads the ratio, not the absolute value.

## Tint and scrim

Blur alone is grey and muddy. A glass surface needs a **tint** — a low-alpha
wash pulled from the system accent so the panel samples the wallpaper beneath it
rather than flattening it.

| Token | Light | Dark |
|---|---|---|
| Panel tint | `system_accent1_100` @ 18% | `system_accent2_800` @ 22% |
| Scrim | `system_surface_dim_light` @ 12% | `#000000` @ 28% |
| Hairline stroke | `#FFFFFF` @ 12% | `#FFFFFF` @ 18% |

The hairline is what separates "glass" from "translucent grey". A 1px stroke at
the panel edge catches light and gives the surface a boundary.

## The blur gate, and who actually controls it

Blur is gated in code, not merely in config. `BlurUtils` in SystemUI requires
three things at once:

1. `CROSS_WINDOW_BLUR_SUPPORTED` — a constant that reflects the system property
   `ro.surface_flinger.supports_background_blur`
2. `ActivityManager.isHighEndGfx()` — fails on low-RAM/low-graphics devices
3. a runtime toggle, which battery saver and the developer "disable blurs"
   option both switch off

**Correction to an earlier assumption in this repo.** That property was described
as vendor-side and therefore unknowable without the device. That is wrong:
`/system/bin/surfaceflinger` ships **inside the GSI**, so the compositor that
performs the blur comes from the system image, and the property can be set in
the GSI's own `/system/build.prop`.

The iodé GSI sets no `ro.surface_flinger.*` property at all, and
`/system/build.prop` is the only prop file present (`prop.default`,
`system_ext/build.prop` and `product/build.prop` are all absent), so that is the
single injection point.

What the device still controls is the **GPU driver**. Setting the property makes
SurfaceFlinger attempt blur; whether it renders correctly and at acceptable cost
on Mali-G615 is a performance question to measure, not a permission the device
grants. That is a much better position than waiting to find out.

Note that a property cannot be delivered by an RRO — resources and properties are
different mechanisms. Setting it means editing `/system/build.prop` inside the
image, which is the same class of operation `inject-ime.sh` already performs.

## Build

Overlay sources are in `overlay/`. They need `aapt2` and `apksigner` from the
Android SDK, which cannot be installed in this environment (`dl.google.com` is
blocked), so build them on your own machine:

```bash
overlay/build.sh            # produces FacetSystemUI.apk, FacetFramework.apk
```

Then inject with the same mechanism the IME uses, into `/system/product/overlay/`
— a directory the iodé GSI already populates, so it is a precedented location.

## What still needs Tier 3

Recompiling SystemUI is required for anything resources cannot express. The
first of these is **written**: see `patches/systemui/`, which adds an AGSL
specular edge shader and hooks it into `ScrimView`. It applies cleanly to
`lineage-23.0` but has not been compiled.

Still outstanding at this tier:

- refraction at panel edges, sampling what is behind the surface
- reshaped QS tile geometry beyond what dimens allow

A source build also **fixes the Android version problem**: LineageOS has branches
through `lineage-24.0`, so you can target the version the device actually ships
rather than being stuck on iodé's Android 14 prebuilt.

Building a GSI needs **no device tree** — GSI targets are generic — but it does
need roughly 250–400 GB and many CPU-hours, which is why it cannot happen in this
environment.
