# Choosing a base for the Unihertz Titan 2 Elite

How the GSI base was chosen, what the hardware work needs, and what is not
achievable. The conclusion is **/e/OS, Android 16**; iodéOS is covered because
it was evaluated first and the reasons for moving off it still matter.

Last updated: 2026-09-17

## Direction

Run **/e/OS, Android 16** on the Titan 2 Elite via its **official GSI**, with a
physical-keyboard IME bundled as the system default and the Facet glass layer on
top.

Two earlier bases were evaluated and rejected — HyperOS 3 and iodéOS. Both are
documented under **History** below, because the reasons still constrain the
work: HyperOS was built for the wrong silicon, and iodé is two Android versions
behind.

## History: why HyperOS was dropped

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
| /e/OS GSI on the device | **Realistic.** Official GSI, built for arbitrary Treble devices |
| Pastiera bundled as default IME | **Done** — `tools/inject-ime.sh` is ROM-agnostic and works on any GSI |
| Camera / fingerprint / VoLTE / Widevine | Re-measured on /e/OS — see below. Three of four improved; none verified without the device |
| Glass UI layer | Partially — see below |
| **Building a complete ROM from source** | **Not achievable.** See below |

### Why a full source build is out of reach

Two independent blockers.

**Infrastructure.** A LineageOS-derived tree needs 150–200 GB synced, because
`.repo` and the checkout both exist at once, plus 100–200 GB for build output.
See `building.md` for the full breakdown. This environment has ~21 GB of
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

1. Fetch an /e/OS GSI from `https://sourceforge.net/projects/e-os/files/GSI/16/`
   and confirm its filesystem, arch and A/B variant.
2. Run `tools/inject-ime.sh` against it with the archived Pastiera APK.
3. Everything else waits on hardware — see `day-one.md`.

## History: why iodéOS was dropped

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

## The base: /e/OS ships an Android 16 GSI

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

## What "/e/OS is a layer over LineageOS" actually means

/e/OS does not fork the whole platform. Its `repo` manifest pulls most of the
~600 projects straight from LineageOS and overrides a specific subset with its
own forks. The manifest repo carries `lineage-23.0`, `.1` and `.2` branches
alongside its own `a16`, and a `features/eos-over-lineageos-specs` branch.

That is why the Facet patches, generated against LineageOS `frameworks/base`,
are expected to apply to an /e/OS tree.

### What /e/OS adds, read from the GSI

| Component | Location |
|---|---|
| microG `GmsCore` | `/system/priv-app/GmsCore` |
| microG `FakeStore` | `/system/priv-app/FakeStore` |
| microG `GsfProxy` | `/system/app/GsfProxy` |
| App Lounge (its own store) | `/system/priv-app/AppLounge` |
| Privileged permissions for microG | `/system/etc/permissions/privapp-permissions-com.google.android.gms.xml` |

That last file is the interesting one: it grants privileged permissions under
**Google's** package name, which is how microG stands in for Play Services.

**Not bundled:** F-Droid and Aurora Store. Those are ordinary user installs on
any ROM.

## Could microG be added to plain LineageOS instead?

- **F-Droid** — yes, trivially. It is just an APK, and /e/OS does not ship it
  either.
- **Aurora Store** — yes, trivially. An APK, installable from F-Droid.
- **microG** — this is the hard one. It has to *run as* `com.google.android.gms`
  with privileged permissions, which is system-level integration, not an install.
  Historically this needs signature spoofing, a framework patch stock LineageOS
  does not ship.

**An honest gap:** `FAKE_PACKAGE_SIGNATURE` was not found in this GSI's
`platform.xml`, `privapp-permissions-platform.xml` or `framework-res.apk`, so
/e/OS is not using the classic spoofing permission in the place one would expect.
How it achieves the integration was not traced. Treat "microG needs signature
spoofing" as the general rule, not as a description of what /e/OS does.

Three routes if you wanted it on LineageOS: use **LineageOS for microG**, which
already does the work but trails Android versions; **patch and build it
yourself**, which is reimplementing what /e/OS solved; or a **Magisk module**,
which needs root and weakens the posture described in `security-posture.md`.

**The practical conclusion:** if you are building from source for Facet anyway,
building /e/OS gets microG already integrated. Building LineageOS and adding it
is strictly more work for the same result.


## The four hardware subsystems, re-measured on /e/OS

The original assessment was made against the **HyperOS** image. Changing base
invalidated it, so it was re-run against `v4.3-a16-20260821-microG-gsi.img`.
Three of the four answers changed.

| | HyperOS GSI | /e/OS GSI |
|---|---|---|
| **VoLTE** | no IMS component at all; demanded 3 QTI HALs; built from `device/qcom/qssi_64` | **zero** qti/qcom HAL demands; built from `device/phh/treble`; ships `ImsServiceEntitlement`, `CarrierConfig`, `CarrierDefaultApp` |
| **Camera** | no camera app whatsoever | ships `/system/app/Camera` |
| **Fingerprint** | HIDL `@2.1` only | HIDL `@2.1`, plus `oplus` and `oppo` vendor shims |
| **Widevine** | nothing in `/system`; vendor-provided | unchanged |

### VoLTE — the structural blocker is gone

This is the big change. The HyperOS image was compiled from Qualcomm's Single
System Image target and asked vendor for QTI radio HALs that do not exist on a
Dimensity 7400. No amount of grafting fixes a framework built against the wrong
radio. That was the basis for calling VoLTE possibly unwinnable.

The /e/OS manifest demands **no** Qualcomm HALs and is built from
`device/phh/treble`, which is vendor-neutral by construction.

It is still not solved. `ImsServiceEntitlement` is a provisioning app, not an IMS
implementation — MediaTek's actual IMS stack lives in the device's own
`/system`, so grafting from a stock dump is likely still required. But that is
now *plausible grafting onto a neutral framework* rather than fighting a
Qualcomm-flavoured one. **Downgraded from "may be unwinnable" to "unverified".**

### Camera — improved

HyperOS shipped no camera application at all, having been stripped of Xiaomi's.
/e/OS ships one, so basic Camera2 capture against the device's own MediaTek HAL
is plausible. Multi-lens switching and tuned processing remain vendor-side and
should not be expected.

### Fingerprint — unchanged observation, lower risk

Only the legacy HIDL `@2.1` interface is visible in `/system/lib64`, as on
HyperOS. Two caveats pull in opposite directions.

First, that was a filename search, so it does not prove AIDL support is absent.

Second, the image carries **16 vendor-specific compatibility libraries** in
`/system/lib64` — `oplus`, `oppo` and others — including fingerprint shims.
Those come from the phh/TrebleDroid layer described below, which exists to make
one image work across many vendors' HALs. HyperOS had no such layer. Lower risk
than before, not eliminated.

### Why TrebleDroid is mentioned when the base is /e/OS

These are not competing bases; they are three layers of the same image:

```
LineageOS 23          the platform
  + /e/ changes       microG, App Lounge, de-Googling   -> "/e/OS"
  + phh/TrebleDroid   the generic device tree that makes it a GSI
```

Read from the image itself:

```
ro.build.fingerprint = google/treble_arm64_bmGN/tdgsi_arm64_ab:16/...
ro.build.product     = tdgsi_arm64_ab          # tdgsi = TrebleDroid GSI
# from device/phh/treble/system.prop           # in build.prop
manifest built from: device/phh/treble/framework_manifest
```

A device-specific /e/OS build, for a Fairphone or a Pixel, has no such layer. But
no Titan 2 Elite device tree exists, so the GSI is the only route, and a GSI must
be built against *some* generic target. phh/TrebleDroid is the one /e/OS uses.

Worth noting that `phh-securize.sh` and `PhhTrebleApp` are **absent**: /e/OS uses
phh's device tree to build, but strips the user-facing Treble tooling.

### Widevine — unchanged

Nothing Widevine-specific in `/system`, so the vendor provides it and the TEE
keybox stays. L1 has a real chance. Note again that an unlocked bootloader
breaks Play Integrity regardless, so HD streaming may refuse even with L1 intact.

**None of this is verified.** `collect-device-info.sh` on the stock ROM answers
all four properly, and that needs the device.
