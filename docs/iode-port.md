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

## The iodéOS GSI, inspected

`iode-5.27-20260827-arm64_ab.img.xz` — 1,132,205,824 bytes, SHA-256 verified
against the published checksum (iodé also ships a minisign `.minisig`).
Decompresses to 3,218,706,432 bytes.

| Property | Value |
|---|---|
| Filesystem | ext4, nested under `/system` — the layout `inject-ime.sh` already handles |
| Base | phh/TrebleDroid (`# from device/phh/treble/system.prop`), LineageOS-derived |
| Fingerprint | `google/lineage_arm64_ab/tdgsi_arm64_ab:14/AP2A.240905.003/…` |
| iodé version | `5.27-20260827-arm64_ab` |
| **Android version** | **14** |
| Security patch | 2026-08-01 |
| SystemUI | `/system/system_ext/priv-app/SystemUI` |
| Overlay directory | `/system/product/overlay` — exists, already populated |

The good news is that this is genuinely vendor-neutral. It is a TrebleDroid build
with no QSSI lineage and none of the Qualcomm HAL demands that made the HyperOS
image a dead end.

### The problem: it is Android 14

Treble's compatibility contract runs **forward**, not backward. A vendor
implementation is supported with a system image of the **same or newer** Android
version. An Android 14 GSI on an Android 15 or 16 vendor is the unsupported
direction.

The Titan 2 Elite is a 2026 device and will almost certainly ship Android 15 or
16. iodé currently publishes **only** Android 14 GSIs — `5.26` and `5.27` are the
entire `gsi/` directory.

So the iodé GSI as it stands is likely the wrong way round for this device. Three
ways out, to be decided when the device's actual Android version is known:

1. **Wait** for iodé to publish an Android 15/16 GSI.
2. **Use a TrebleDroid or LineageOS GSI at Android 15/16.** Architecturally the
   same base as iodé, minus iodé's privacy stack.
3. **Build one**, which needs no device tree for a GSI target, only the
   infrastructure described above.

Confirm the device's shipped Android version with `collect-device-info.sh` before
committing to any GSI.

### What this means for theming

- `/system/product/overlay` exists and already carries RRO overlays, so dropping
  an overlay APK there is a precedented operation, mechanically identical to what
  `inject-ime.sh` already does for the IME.
- `ro.surface_flinger.supports_background_blur` is **not set** by this GSI, and
  the image sets almost nothing SurfaceFlinger-related. That property is normally
  vendor-side, so whether real background blur is available is determined by the
  **device**, not by the GSI. It cannot be settled until the hardware exists.
  Without it, translucency renders flat and a glass treatment loses most of its
  effect.

## Base reconsidered: /e/OS ships an Android 16 GSI

The Android 14 problem above has a straightforward answer. **/e/OS publishes GSIs
for Android 14, 15 and 16**, verified directly on SourceForge:

```
/e/OS/files/GSI/16/  ->  v4.3-a16-20260821-microG-gsi.img.xz
```

/e/OS is LineageOS-derived and de-Googled with microG, so it is the same
architectural family as iodé — but current, where iodé is two Android versions
behind. For a 2026 device this is the right way round for Treble.

### Why the obvious names are not options here

This project needs a **GSI**, because no device tree exists for the Titan 2
Elite. That rules out the two ROMs people usually reach for first:

- **GrapheneOS** — Pixel-only. Its security model depends on verified boot with
  user-supplied keys, which needs specific hardware support. It does not ship a
  GSI and is unlikely to.
- **CalyxOS** — device-specific builds only (Pixel, Fairphone, some Motorola).
  No GSI.

Both are strong projects; neither is applicable without a device port.

### The tradeoff worth understanding

/e/OS gives a **privacy** stack — de-Googled, microG, no telemetry. It does not
give a **hardening** stack: no hardened memory allocator, no extra exploit
mitigations, no hardened WebView. That class of work is what GrapheneOS does, and
it is tied to Pixel hardware.

No GSI-shipping ROM offers GrapheneOS-level hardening. If hardening rather than
de-Googling is the goal, the honest answer is that this device cannot deliver it.

### Candidates, ranked for this project

| ROM | GSI | Android | Verdict |
|---|---|---|---|
| **/e/OS** | yes | **16** | best fit — current, privacy stack, right Treble direction |
| iodéOS | yes | 14 | same family, two versions behind |
| LineageOS + microG | yes | trails | check current branch before choosing |
| GrapheneOS | no | — | Pixel-only, not applicable |
| CalyxOS | no | — | device-specific, not applicable |

The Facet overlay is unaffected by this choice: every resource it overrides is
upstream LineageOS SystemUI, which all of these share.

### /e/OS Android 16 GSI, inspected

`v4.3-a16-20260821-microG-gsi.img.xz` — 1,416,191,504 bytes, decompressing to
3,896,528,896 bytes.

| Property | Value |
|---|---|
| **Android version** | **16** (`BP2A.250805.005`) — the version problem is solved |
| Filesystem | ext4, nested under `/system` — `inject-ime.sh` handles it unchanged |
| Base | `tdgsi_arm64_ab`, flavor `treble_arm64_bmGN-userdebug` — same TrebleDroid family as iodé |
| `/system/product/overlay` | present — RRO injection point |
| `/system/system_ext/priv-app/SystemUI` | present — Tier 3 target |
| `/system/bin/surfaceflinger` | present — the compositor is ours, so the blur property is ours to set |
| `ro.surface_flinger.supports_background_blur` | **not set** — only a frame-rate override is present |

Because it is the same TrebleDroid/LineageOS lineage as iodé, **the Facet overlay
applies unchanged**. Every resource it overrides is upstream SystemUI.

Two things to be aware of:

**No published checksum.** Unlike iodé, which ships `.sha256` and a minisign
`.minisig`, the /e/OS GSI directory carries the image alone. Verify future
downloads against this, computed here:

```
sha256  c1442b4fc543ec1b1b1552c279652b36cae4c93c7767c38b61837b3615732f43
size    1416191504 bytes  (the .xz)
```

**It is a userdebug build** (`eng.root:userdebug`). That is normal for GSIs and
convenient for development, since adb root is available, but it is a weaker
security posture than a user build — worth weighing for a ROM chosen on privacy
grounds.

### Recommendation

Use the **/e/OS Android 16 GSI** as the base. It resolves the Treble version
direction, keeps the privacy stack, and changes nothing about the Facet work.
