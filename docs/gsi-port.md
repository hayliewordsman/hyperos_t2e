# HyperOS 3 GSI + Pastiera — port working notes

Last updated: 2026-09-17

## What exists now

`tools/inject-pastiera.sh` takes a GSI system image and a Pastiera APK and
produces a modified image with Pastiera preinstalled as a system app and
selected as the default IME on first boot.

```
tools/inject-pastiera.sh --image system.img --apk Pastiera.apk --out system-pastiera.img
```

It handles Android sparse and raw images, unpacks EROFS, injects three files,
and repacks with SELinux labels reapplied from the image's own
`plat_file_contexts`:

| Path | Mode | Purpose |
|---|---|---|
| `/system/app/Pastiera/Pastiera.apk` | 0644 | the IME, as a system app |
| `/system/bin/pastiera-setup-ime.sh` | 0755 | one-shot first-boot setup |
| `/system/etc/init/pastiera-ime.rc` | 0644 | starts it at `sys.boot_completed=1` |

The setup script waits for package manager to scan the app, then sets
`enabled_input_methods`, `default_input_method`, and `show_ime_with_hard_keyboard`
(without that last one a physical-keyboard device hides the IME entirely), and
stamps `/data/misc/pastiera/` so it only runs once.

### Verification status

Tested against synthetic EROFS images covering four cases:

- raw EROFS, tree containing `system/` → **pass**, labels applied (`Xattr size: 16`)
- Android sparse wrapper → **pass**, converted and injected
- tree rooted at the system dir itself → **pass**
- ext4 image → **correctly rejected** (see limitations)

Two real bugs were found and fixed by those tests: the EROFS superblock magic was
byte-reversed (`od -tx4` prints the little-endian word, so it reads `e0f5e1e2`),
and the `--mount-point` logic was inverted, which silently produced an image with
**no SELinux labels at all** on the injected files.

**Not yet validated against a real HyperOS GSI.** See blockers.

### Limitations

- **EROFS only.** ext4 repacking needs `e2fsdroid` to restore SELinux labels,
  which is not available here. Android 14+ GSIs are normally EROFS, but this is
  unconfirmed for the HyperOS 3 builds below.
- **The first-boot hook is best-effort.** An enforcing GSI may deny an init
  service invoking `settings`. The reliable fallback, which always works:
  ```
  adb shell ime enable it.palsoftware.pastiera/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService
  adb shell ime set    it.palsoftware.pastiera/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService
  ```

## Pastiera facts (from source)

Cloned from `github.com/palsoftware/pastiera`:

- package `it.palsoftware.pastiera`, nightly builds use `.nightly` suffix
- IME service `.inputmethod.PhysicalKeyboardInputMethodService`
- `minSdk 29`, `targetSdk 36`
- **GPLv3**
- README names the Unihertz Titan 2 as a target device

GPLv3 matters if you redistribute the resulting image: you would have to ship
Pastiera's corresponding source and installation information alongside it.
Flashing a build to your own phone is not distribution, so nothing is triggered.

## HyperOS 3 GSI candidates

Mystic GSI Updates on SourceForge carries 230 HyperOS GSIs; seven are HyperOS 3
(Android 16, `OS3.0.x`, `W` build prefix), all arm64 A/B:

| Date | File |
|---|---|
| 2026-01-22 | `Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` |
| 2026-01-18 | `Hyperos-nezha-16-OS3.0.5.0.WPACNDM-AB-20260118-MysticGSI.zip` |
| 2026-01-14 | `Hyperos-dijun-16-OS3.0.9.0.WODCNXM-AB-20260114-MysticGSI.zip` |
| 2025-12-10 | `Hyperos-fuxi-16-OS3.0.2.0.WMCCNXM-AB-20251210-MysticGSI.zip` |
| 2025-12-07 | `Hyperos-goya-16-OS3.0.5.0.WOEMIXM-AB-20251207-MysticGSI.zip` |
| 2025-12-05 | `Hyperos-dada-16-OS3.0.5.0.WOCCNXM-AB-20251205-MysticGSI.zip` |
| 2025-12-05 | `Hyperos-duchamp-16-OS3.0.0.4.WNLCNXM-AB-20251205-MysticGSI.zip` |

Note none of these is the Xiaomi 17 `3.0.335.0.XPCMIXM` build originally asked
for, and none needs to be — a GSI is device-independent by construction. These
are community ports of other Xiaomi devices' HyperOS 3 builds.

## Blockers

| Blocker | Impact | Unblock |
|---|---|---|
| No Pastiera APK obtainable here | Cannot run the tool end-to-end | Allowlist `pastiera.eu`, or supply an APK |
| `dl.google.com` blocked | Cannot build the APK from source (no Android SDK) | Allowlist `dl.google.com` |
| SourceForge now rate-limiting | Could not confirm the GSI is EROFS | Retry later, or download manually |
| Titan 2 Elite bootloader unlock unverified | **Gates the entire project** | Ask Unihertz |

The bootloader question is still the one that decides whether any of this is
worth doing. Nothing else matters if the device will not unlock.

## Order of work

1. Confirm the bootloader unlocks. Stop here if it does not.
2. Install Pastiera on the **stock** ROM and confirm it works on this keyboard.
   This is independent of the GSI and is most of the value.
3. Back up stock firmware.
4. Download a HyperOS 3 GSI, confirm it is EROFS, run the tool, flash.
5. Expect camera, fingerprint, VoLTE and Widevine L1 to be degraded or broken.
