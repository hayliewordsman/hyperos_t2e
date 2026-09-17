# hyperos_t2e

HyperOS 3 on the **Unihertz Titan 2 Elite** via a GSI, with a physical-keyboard
input method bundled as the system default.

- **[docs/feasibility.md](docs/feasibility.md)** — why a direct Xiaomi 17 ROM port
  is not possible, and why a GSI is the only viable route
- **[docs/gsi-port.md](docs/gsi-port.md)** — GSI candidates, tooling, blockers
- **[tools/inject-ime.sh](tools/inject-ime.sh)** — bundles any IME into a
  GSI system image as a system app and default input method
- **[tools/axml.py](tools/axml.py)** — reads an APK's package and IME component
  out of its binary manifest, without the Android SDK
- **[docs/DISTRIBUTION-COMPLIANCE.md](docs/DISTRIBUTION-COMPLIANCE.md)** — GPLv3
  source and installation information, required if you share a built image

## Quick start

```bash
apt-get install -y erofs-utils android-sdk-libsparse-utils
tools/inject-ime.sh --image system.img --apk Keyboard.apk --out out.img
```

## Status

The injection tool supports **ext4 and EROFS**, raw and sparse, in both root
layouts, and verifies every injected file afterwards.

It has been **validated end-to-end against a real HyperOS 3 GSI**
(`OS3.0.50.2.W`, Android 16, 7.5 GB ext4 system-as-root): correct layout
detection, 741 real SELinux policy rules parsed, files injected and labelled,
APK byte-identical out of the image, pre-existing content untouched, and the
result passes a read-only `e2fsck`. Runtime 24 s.

Still missing: a Pastiera APK. `pastiera.eu`, `f-droid.org` and `dl.google.com`
are all blocked by the network policy, so it can neither be downloaded nor built
here.

Seven HyperOS 3 (Android 16) arm64 A/B GSIs are catalogued in the port notes.

**Before doing any of this:** confirm the Titan 2 Elite's bootloader can be
unlocked. It gates the entire project and is still unanswered.

If the goal is simply better typing, installing Pastiera on the stock ROM
delivers that on its own — no unlock, no GSI, no broken camera.
