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

## Hard dependency: `ro.surface_flinger.supports_background_blur`

If this vendor property is not `1`, SurfaceFlinger does no cross-window blur and
**every value above degrades to flat translucency**. It is a device property, not
a GSI one, so it cannot be confirmed until the hardware exists.

The framework also exposes `config_sf_slowBlur` (default `true`), a quality/cost
tradeoff worth testing on Mali-G615 once the device is in hand.

`collect-device-info.sh` captures `getprop`; check for the blur property before
investing in the overlay.

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

Recompiling SystemUI is required only for:

- specular edge highlights that track device tilt
- custom AGSL shaders for refraction at panel edges
- reshaped QS tile geometry beyond what dimens allow

A source build also **fixes the Android version problem**: LineageOS has branches
through `lineage-24.0`, so you can target the version the device actually ships
rather than being stuck on iodé's Android 14 prebuilt.

Building a GSI needs **no device tree** — GSI targets are generic — but it does
need roughly 250–400 GB and many CPU-hours, which is why it cannot happen in this
environment.
