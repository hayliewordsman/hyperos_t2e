# iodéOS on the Unihertz Titan 2 Elite — plan and constraints

Last updated: 2026-09-17

## Direction

Run **iodéOS** (LineageOS-derived, privacy-focused) on the Titan 2 Elite via its
**official GSI**, with a physical-keyboard IME bundled as the system default and
a glass-style UI layer on top.

This replaces an earlier attempt to use a HyperOS 3 GSI, which was abandoned for
a concrete reason preserved below.

## Why the HyperOS route was dropped

The HyperOS 3 GSI declared its own build inputs in its system VINTF manifest:

```
device/qcom/qssi_64/framework_manifest.xml
```

**QSSI is Qualcomm's Single System Image target.** That system layer was compiled
expecting Qualcomm telephony and asked vendor for three QTI HALs
(`vendor.qti.hardware.radio.atcmdfwd`, `qccsyshal`, `systemhelper`) that do not
exist on a Dimensity 7400. It also shipped **no IMS implementation at all**.

"Generic" there meant generic across Qualcomm Xiaomi devices, not vendor-neutral.
An AOSP-derived GSI has none of that baggage, which is the whole argument for the
change.

## What is achievable

| Goal | Status |
|---|---|
| iodéOS GSI on the device | **Realistic.** Official GSI, built for arbitrary Treble devices |
| Pastiera bundled as default IME | **Done** — `tools/inject-ime.sh` is ROM-agnostic and works on any GSI |
| Camera / fingerprint / VoLTE / Widevine | **Better odds than HyperOS**, still unverified without the device |
| Glass UI layer | Partially — see below |
| **Building a complete ROM from source** | **Not achievable.** See below |

### Why a full source build is out of reach

Two independent blockers.

**Infrastructure.** An iodé/LineageOS tree is roughly 100 GB synced, with another
150–300 GB for build output and many CPU-hours. This environment has ~21 GB of
disk, 4 cores and 15 GB RAM. Not a matter of patience.

**Inputs that do not exist.** A device port needs three things for the Titan 2
Elite, and none are available:

- a **device tree** — none exists; the device is new and has no community support
- **kernel source** — Unihertz owes this under GPL, but publication is often late
- **vendor blobs** — extracted from stock firmware, which is not published
  anywhere (searched thoroughly) and cannot be dumped without the device

So a source build is blocked on strictly more than the GSI route was. The GSI
sidesteps all three by keeping the device's own kernel and vendor partition.

### The glass UI layer

A system-wide Android theme is normally a **Runtime Resource Overlay** (RRO),
which must be compiled with `aapt2` from the Android SDK. `dl.google.com` is
blocked in this environment, so an overlay APK cannot be built here.

Two routes, in increasing order of invasiveness:

1. **Userspace** — a launcher, icon pack and wallpaper. No ROM changes, works on
   stock or any GSI, reversible. Gets most of the visual effect for none of the risk.
2. **RRO overlay** — real system-wide theming of SystemUI, quick settings and
   framework surfaces. Needs SDK access to build, and the design work can be done
   in advance either way.

Note on naming: *Liquid Glass* is Apple's design language. What is planned here
is an original glass/translucency design system — blur, depth and layering are
general techniques — not a reproduction of Apple's visual identity or assets.

## Carried over from the earlier work

These findings are ROM-agnostic and still apply.

- **GSIs may be ext4 or EROFS.** The HyperOS one was ext4, contradicting the
  assumption that Android 14+ images are always EROFS. `inject-ime.sh` handles
  both, plus raw and sparse, in either root layout.
- **A GSI contains no kernel.** `/boot` is device-specific and stays on the phone.
  This is why a GSI can run on hardware from a different SoC vendor at all.
- **Check `shared_blocks` before modifying an ext4 image.** The HyperOS image did
  not set it, which is what made in-place `debugfs` edits safe. An image that
  does set it must not be modified that way.
- **Read the IME component from the APK, never guess.** Pastiera's nightly has
  applicationId `it.palsoftware.pastiera.nightly` while its IME class keeps the
  `it.palsoftware.pastiera` namespace, because Gradle's `applicationIdSuffix`
  does not move the Java package. Use `tools/axml.py`.

## Next steps

1. Fetch an iodéOS GSI from `https://gitlab.iode.tech/ota/release/-/tree/master/gsi`
   and confirm its filesystem, arch and A/B variant.
2. Run `tools/inject-ime.sh` against it with the archived Pastiera APK.
3. Everything else waits on hardware — see `day-one.md`.
