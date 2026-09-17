# titan2e-iode

Tooling to put a privacy-focused Android on the **Unihertz Titan 2 Elite** via a
GSI, with a physical-keyboard IME as the system default and **Facet**, an
original glass UI layer.

## Status

**No hardware yet**, and **nothing has been compiled.** Everything below was
built and verified against images and source, not a running device.

| Piece | State |
|---|---|
| GSI base | **/e/OS 4.3, Android 16** — downloaded, inspected, adopted |
| IME injection | **Working**, verified on the real /e/OS image: files labelled, APK byte-identical, `e2fsck` clean |
| `build.prop` editing | **Working** — sets the blur property inside the image |
| Facet overlay (Tier 2) | Written; every overridden resource verified to exist upstream |
| Facet patch `0001` (edge) | Applies cleanly; **never compiled** |
| Facet patch `0002` (refraction) | ⚠️ **Proven ineffective** — see below |
| Build + emulator guide | Written |

## Read first when the hardware arrives

**[docs/day-one.md](docs/day-one.md).** There is **no public Titan 2 Elite
firmware** — searched thoroughly. Overwrite stock without a backup and there may
be no way back. The dump you take on day one is the only one that will exist.

## Contents

| Path | What it is |
|---|---|
| [tools/inject-ime.sh](tools/inject-ime.sh) | Injects an IME and sets properties in a GSI. ext4 + EROFS, raw + sparse, both root layouts, verified afterwards |
| [tools/axml.py](tools/axml.py) | Reads an APK's package and IME component from its binary manifest, without the Android SDK |
| [tools/collect-device-info.sh](tools/collect-device-info.sh) | Pulls HAL, telephony, DRM and fingerprint state off the device over adb. **Untested against hardware** |
| [overlay/](overlay/) | Facet RRO overlay sources (Tier 2) and a build script |
| [patches/systemui/](patches/systemui/) | Facet SystemUI source patches (Tier 3) |
| [docs/glass-ui.md](docs/glass-ui.md) | The Facet design system and the rule that governs it |
| [docs/preview/](docs/preview/) | Renders of the shader math — **not screenshots** |
| [docs/building.md](docs/building.md) | Compiling and emulating with no device |
| [docs/iode-port.md](docs/iode-port.md) | Base selection, HAL findings, what is and isn't achievable |
| [docs/DISTRIBUTION-COMPLIANCE.md](docs/DISTRIBUTION-COMPLIANCE.md) | GPLv3 obligations if you share a built image |
| [prebuilts/pastiera/](prebuilts/pastiera/) | The verified Pastiera APK, with provenance |

## Quick start

```bash
apt-get install -y erofs-utils android-sdk-libsparse-utils e2fsprogs python3

python3 tools/axml.py prebuilts/pastiera/*.apk     # never assume the component

tools/inject-ime.sh \
  --image   system.img \
  --apk     prebuilts/pastiera/pastiera-nightly-0.86-nightly.20260820.222455.apk \
  --out     system-facet.img \
  --name    Pastiera \
  --ime-id  it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService \
  --set-prop ro.surface_flinger.supports_background_blur=1
```

## Two findings worth carrying forward

**The IME component trap.** Pastiera's nightly has applicationId
`it.palsoftware.pastiera.nightly`, but its IME class keeps the
`it.palsoftware.pastiera` namespace — `applicationIdSuffix` does not move the
Java package. The short form expands to a class that does not exist, and the
keyboard installs, flashes and boots while silently never activating. Read the
component with `axml.py`.

**The blur rule.** On a blurred surface, any effect that works by *displacing
samples* is invisible; only effects that *modify values* survive. Established by
rendering the shader math, and it killed the refraction shader before it cost a
build. See [docs/preview/](docs/preview/).

## Open items

- [ ] **Compile something.** Nothing here has been built; that is the largest untested surface
- [ ] Replace `0002` with a value-modifying rim treatment (rim darkening renders well)
- [ ] Device arrives → `collect-device-info.sh` on **stock**, before anything else
- [ ] Full partition backup before unlocking (unlocking wipes user data)
- [ ] Fill the remaining placeholders in the compliance doc before any public release

## Worth considering before you flash

If the goal is better typing, installing Pastiera as a normal app on the **stock**
ROM delivers the symbols, keypad scrolling and emoji on its own — no unlock, no
flashing, and camera, fingerprint, VoLTE and Widevine all keep working.
