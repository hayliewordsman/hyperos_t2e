# titan2e-iode

Tooling to run **iodéOS** on the **Unihertz Titan 2 Elite** via a GSI, with a
physical-keyboard input method bundled as the system default and a glass-style
UI layer on top.

## Status

**No hardware yet.** The Titan 2 Elite has not arrived, so everything needing a
device is parked. The bootloader is confirmed unlockable.

Done and verified:

- **The IME injection pipeline**, validated end-to-end against a real 7.5 GB
  ext4 system-as-root GSI: correct layout detection, 741 real SELinux rules
  parsed, files injected and labelled, APK byte-identical out of the image,
  pre-existing content untouched, clean `e2fsck`. 24 s. It is ROM-agnostic and
  works on any GSI.
- **The Pastiera APK**, archived and hash-verified in `prebuilts/pastiera/`.
- **GPLv3 source and installation information**, with the source offer pointing
  at a mirror under our control.

Next: fetch an iodéOS GSI and run the pipeline against it. See
[docs/iode-port.md](docs/iode-port.md).

## Scope, honestly

**A complete ROM built from source is not achievable**, for two independent
reasons: this environment has ~21 GB of disk against the ~250–400 GB a
LineageOS-class build needs, and a Titan 2 Elite device port would require a
device tree, kernel source and vendor blobs — none of which exist. The GSI route
sidesteps all three by keeping the device's own kernel and vendor partition.
[docs/iode-port.md](docs/iode-port.md) has the detail.

## Read first when the hardware arrives

**[docs/day-one.md](docs/day-one.md).** There is **no public Titan 2 Elite
firmware** — searched thoroughly. Overwrite the stock partitions without a backup
and there may be no way back. The dump you take on day one is the only one that
will ever exist.

## Contents

| Path | What it is |
|---|---|
| [tools/inject-ime.sh](tools/inject-ime.sh) | Bundles any IME into a GSI as a system app and default input method. Handles ext4 and EROFS, raw and sparse, both root layouts |
| [tools/axml.py](tools/axml.py) | Reads an APK's package and IME component from its binary manifest, without the Android SDK |
| [tools/collect-device-info.sh](tools/collect-device-info.sh) | Pulls HAL manifests, telephony, DRM, fingerprint and camera state off the device over adb. **Untested against hardware** |
| [prebuilts/pastiera/](prebuilts/pastiera/) | The verified Pastiera APK, with provenance and licence notes |
| [docs/iode-port.md](docs/iode-port.md) | The plan, what is achievable, and what is not |
| [docs/day-one.md](docs/day-one.md) | Order of operations for when the device arrives |
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

`--ime-id` selects any input method; the tool is not tied to Pastiera.

### The trap worth knowing

Pastiera's nightly has applicationId `it.palsoftware.pastiera.nightly`, but its
IME class keeps the original `it.palsoftware.pastiera` namespace — Gradle's
`applicationIdSuffix` does not move the Java package. The short form
`.inputmethod.…` expands to a class that does not exist, and the keyboard
installs, flashes and boots while silently never activating. Always read the
component with `axml.py`.

## Worth considering before you flash

If the goal is better typing, **installing Pastiera as a normal app on the stock
ROM** delivers the symbols, keypad scrolling and emoji on its own — no unlock, no
flashing, and camera, fingerprint, VoLTE and Widevine keep working.

## Open items

- [ ] Fetch an iodéOS GSI and run the pipeline against it
- [ ] Device arrives; run `collect-device-info.sh` on **stock**, before anything else
- [ ] Full partition backup before unlocking (unlocking wipes user data)
- [ ] Design the glass UI layer; an RRO overlay needs Android SDK access to build
- [ ] Fill the remaining placeholders in the compliance doc before any public release

## Caveat

Everything here was validated against **images, not hardware**. Treat the first
boot as an experiment.
