# hyperos_t2e

HyperOS 3 on the **Unihertz Titan 2 Elite** via a GSI, with
[Pastiera](https://pastiera.eu) bundled as the default input method.

- **[docs/feasibility.md](docs/feasibility.md)** — why a direct Xiaomi 17 ROM port
  is not possible, and why a GSI is the only viable route
- **[docs/gsi-port.md](docs/gsi-port.md)** — GSI candidates, tooling, blockers
- **[tools/inject-pastiera.sh](tools/inject-pastiera.sh)** — bundles Pastiera into a
  GSI system image as a system app and default IME

## Quick start

```bash
apt-get install -y erofs-utils android-sdk-libsparse-utils
tools/inject-pastiera.sh --image system.img --apk Pastiera.apk --out system-pastiera.img
```

## Status

The injection tool is written and tested against synthetic EROFS images (raw,
sparse, and both root layouts), with SELinux relabelling verified. It has **not**
been run against a real HyperOS GSI yet, and no Pastiera APK could be obtained in
this environment — `pastiera.eu`, `f-droid.org` and `dl.google.com` are all
blocked by the network policy, so the APK can neither be downloaded nor built.

Seven HyperOS 3 (Android 16) arm64 A/B GSIs are catalogued in the port notes.

**Before doing any of this:** confirm the Titan 2 Elite's bootloader can be
unlocked. It gates the entire project and is still unanswered.

If the goal is simply better typing, installing Pastiera on the stock ROM
delivers that on its own — no unlock, no GSI, no broken camera.
