# hyperos_t2e

Tooling to run **HyperOS 3** on the **Unihertz Titan 2 Elite** via a GSI, with a
physical-keyboard input method bundled as the system default.

## Status

**No hardware yet.** The Titan 2 Elite has not arrived, so everything that needs
a device is parked. The bootloader is confirmed unlockable.

What is done and verified:

- The injection pipeline is built and **validated end-to-end against a real
  HyperOS 3 GSI** — `OS3.0.50.2.W`, Android 16, a 7.5 GB ext4 system-as-root
  image. Correct layout detection, 741 real SELinux rules parsed, files injected
  and labelled, APK byte-identical out of the image, pre-existing content
  untouched, clean `e2fsck`. 24 s.
- The Pastiera APK is **archived and hash-verified** in `prebuilts/pastiera/`.
- GPLv3 source and installation information is written and the source offer
  points at a mirror we control.

What is blocked on the device: camera, fingerprint, VoLTE and Widevine L1. See
[docs/gsi-port.md](docs/gsi-port.md) for the evidence behind each. **VoLTE may
not be winnable on a HyperOS base at all** — the GSI ships no IMS stack and its
manifest expects Qualcomm telephony, while the Elite is MediaTek.

## Read first when the hardware arrives

**[docs/day-one.md](docs/day-one.md).** There is **no public Titan 2 Elite
firmware** — this was searched thoroughly. Overwrite the stock partitions without
a backup and there may be no way back. The dump you take on day one is the only
one that will ever exist.

## Contents

| Path | What it is |
|---|---|
| [tools/inject-ime.sh](tools/inject-ime.sh) | Bundles any IME into a GSI system image as a system app and default input method. Handles ext4 and EROFS, raw and sparse, both root layouts |
| [tools/axml.py](tools/axml.py) | Reads an APK's package and IME component from its binary manifest, without the Android SDK |
| [tools/collect-device-info.sh](tools/collect-device-info.sh) | Pulls HAL manifests, telephony, DRM, fingerprint and camera state off the device over adb. **Untested against hardware** |
| [prebuilts/pastiera/](prebuilts/pastiera/) | The verified Pastiera APK the image was built against, with provenance and licence notes |
| [docs/day-one.md](docs/day-one.md) | Order of operations for when the device arrives |
| [docs/gsi-port.md](docs/gsi-port.md) | GSI candidates, tooling notes, HAL findings, blockers, reproduction recipe |
| [docs/feasibility.md](docs/feasibility.md) | Why a direct Xiaomi 17 ROM port is impossible and a GSI is the only route |
| [docs/DISTRIBUTION-COMPLIANCE.md](docs/DISTRIBUTION-COMPLIANCE.md) | GPLv3 source and installation information, required if you share a built image |

## Quick start

```bash
apt-get install -y erofs-utils android-sdk-libsparse-utils e2fsprogs python3

# Confirm what the APK declares - never assume the component
python3 tools/axml.py prebuilts/pastiera/*.apk

tools/inject-ime.sh \
  --image  system.img \
  --apk    prebuilts/pastiera/pastiera-nightly-0.86-nightly.20260820.222455.apk \
  --out    system-pastiera.img \
  --name   Pastiera \
  --ime-id it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService
```

The tool is not tied to Pastiera; `--ime-id` selects any input method.
[docs/gsi-port.md](docs/gsi-port.md) has the recipe for fetching a GSI.

### The trap worth knowing

Pastiera's nightly has applicationId `it.palsoftware.pastiera.nightly`, but its
IME class keeps the original `it.palsoftware.pastiera` namespace — Gradle's
`applicationIdSuffix` does not move the Java package. Passing the short form
`.inputmethod.…` expands to a class that does not exist, and the keyboard
installs, flashes and boots while silently never activating. Always read the
component with `axml.py` rather than guessing.

## Worth considering before you flash

If the goal is better typing, **installing Pastiera as a normal app on the stock
ROM** delivers the symbols, keypad scrolling and emoji on its own — no unlock, no
flashing, and camera, fingerprint, VoLTE and Widevine keep working.

The GSI route trades those four for the HyperOS interface. If you want the
features more than the look, a Treble/AOSP GSI is a far better base than HyperOS;
[docs/gsi-port.md](docs/gsi-port.md) compares the three options.

## Open items

- [ ] Device arrives; run `collect-device-info.sh` on **stock**, before anything else
- [ ] Full partition backup before unlocking (unlocking wipes user data)
- [ ] Optional: pin the Pastiera source tag in the mirror — steps in
      [prebuilts/pastiera/README.md](prebuilts/pastiera/README.md). Compliance holds without it
- [ ] Fill the remaining placeholders in the compliance doc before any public release

## Caveat

Everything here was validated against **images, not hardware**. Unverified: that
HyperOS boots on Dimensity 7400 vendor at all, that the first-boot IME hook
survives SELinux enforcement, and that Pastiera behaves correctly on Titan 2
**Elite** keys. Treat the first boot as an experiment.
