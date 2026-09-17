# HyperOS 3 GSI + Pastiera — port working notes

Last updated: 2026-09-17 (rev 3)

## What exists now

`tools/inject-pastiera.sh` takes a GSI system image and a Pastiera APK and
produces a modified image with Pastiera preinstalled as a system app and
selected as the default IME on first boot.

```
tools/inject-pastiera.sh --image system.img --apk Pastiera.apk --out system-pastiera.img
```

It handles Android sparse and raw images and **both filesystems GSIs ship**:

- **ext4** — modified in place with `debugfs` (no mount, no `e2fsdroid`)
- **EROFS** — unpacked, injected, repacked with `mkfs.erofs --file-contexts`

Three files are injected, each given an SELinux label resolved from the image's
own `plat_file_contexts` (most-specific rule wins), falling back to
`u:object_r:system_file:s0`:

| Path | Mode | Purpose |
|---|---|---|
| `/system/app/Pastiera/Pastiera.apk` | 0644 | the IME, as a system app |
| `/system/bin/pastiera-setup-ime.sh` | 0755 | one-shot first-boot setup |
| `/system/etc/init/pastiera-ime.rc` | 0644 | starts it at `sys.boot_completed=1` |

The setup script waits for package manager to scan the app, then sets
`enabled_input_methods`, `default_input_method`, and `show_ime_with_hard_keyboard`
(without that last one a physical-keyboard device hides the IME entirely), and
stamps `/data/misc/pastiera/` so it only runs once.

### The images are ext4, not EROFS

The earlier assumption that Android 16 GSIs would be EROFS was **wrong for these
builds**. Probing the real archive without downloading it — reading the ZIP
central directory over HTTP range requests, then inflating only the first ~36 MB
of the entry — shows:

```
Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip   3.99 GB
  └── system.img   7.51 GB uncompressed, deflate
        @0x438 = 53ef   -> ext4
        @1024  = 00000700 -> not EROFS
```

The archive holds a single bare `system.img`, not sparse. An EROFS-only tool
would have rejected it outright, so ext4 support is the path that actually
matters.

### Verification status

Tested against synthetic images covering five cases:

| Case | Result |
|---|---|
| ext4, rooted at the system partition | pass, verified |
| ext4, Android sparse wrapper | pass, converted and verified |
| EROFS, tree containing `system/` | pass, labels applied |
| EROFS, tree rooted at the system dir | pass |
| unrecognised filesystem | correctly rejected |

Those tests caught four real bugs:

1. EROFS superblock magic was byte-reversed — `od -tx4` prints the little-endian
   word, so it reads `e0f5e1e2`.
2. `--mount-point` logic was inverted, silently producing images with **no
   SELinux labels at all** on injected files.
3. `debugfs sif mode 0644` writes `i_mode` verbatim, clearing the `S_IFREG`
   type bits; `e2fsck` then deleted the injected inodes as corrupt. Modes must
   be `0100644`/`0100755`.
4. The ext4 path reported success while injecting nothing, because `debugfs`
   exits 0 even when individual commands fail. The tool now verifies every file
   is present, is a regular file, and carries an SELinux label, and fails loudly
   otherwise.

### Validated against a real HyperOS 3 GSI

`Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip` was downloaded
(3.99 GB, exact size match), extracted, and run through the tool.

The image is **HyperOS OS3.0.50.2.W / Android 16 (SDK 36)**, a 7.5 GB ext4
**system-as-root** filesystem: the image root is `/`, holding `/apex`, symlinked
`bin` and `etc`, and the real content under `/system/`. It carries a genuine
48,989-byte `plat_file_contexts` (741 rules) and has ~203 MiB free. Notably it
does **not** set the `shared_blocks` feature, so `debugfs` writes are safe;
an image that does set it must not be modified this way.

Results:

| Check | Result |
|---|---|
| Filesystem detection | ext4 |
| Root layout detection | correctly found the nested `/system` |
| Policy parsing | 741 rules, all three files resolved to `system_file:s0` |
| Free space | 203 MiB available, 35 MiB payload, no growth needed |
| Injected files | present, regular, correct modes, correctly labelled |
| APK integrity | byte-identical out of the image (36,000,629 bytes) |
| Pre-existing content | `build.prop` identical to pristine |
| Filesystem consistency | read-only `e2fsck` clean, exit 0 |
| Runtime | 24 s |

The pristine image fscks clean and so does the output; the block and inode
deltas match the payload exactly (+4 inodes, +8,811 blocks ≈ 36 MB).

One refinement came out of this run. `debugfs` leaves the free block/inode
accounting stale, so the repair pass *always* prints `FILE SYSTEM WAS MODIFIED`
even on a perfectly good image — the first version treated that as a warning and
cried wolf. The tool now runs a second, read-only `e2fsck` and only fails if
*that* reports a problem.

A dummy 36 MB APK stood in for Pastiera, since no real APK could be obtained
here. Everything except the APK's actual contents is therefore validated
end-to-end on a real image.

### Limitations

- **The first-boot hook is best-effort.** The `.rc` runs `/system/bin/sh`, whose
  `shell_exec` label means an enforcing build may deny init invoking `settings`.
  The reliable fallback, which always works:
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
| ~~SourceForge blocking~~ | ~~Could not confirm filesystem~~ | **Resolved** — mirrors 403 a browser-like User-Agent; plain curl defaults work |
| Titan 2 Elite bootloader unlock unverified | **Gates the entire project** | Ask Unihertz |

The bootloader question is still the one that decides whether any of this is
worth doing. Nothing else matters if the device will not unlock.

## Order of work

1. Confirm the bootloader unlocks. Stop here if it does not.
2. Install Pastiera on the **stock** ROM and confirm it works on this keyboard.
   This is independent of the GSI and is most of the value.
3. Back up stock firmware.
4. Download a HyperOS 3 GSI (they are ext4), run the tool, flash.
5. Expect camera, fingerprint, VoLTE and Widevine L1 to be degraded or broken.
