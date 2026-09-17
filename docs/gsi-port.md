# HyperOS 3 GSI + Pastiera — port working notes

Last updated: 2026-09-17 (rev 4)

## What exists now

`tools/inject-ime.sh` takes a GSI system image and any input-method APK and
produces a modified image with that IME preinstalled as a system app and
selected as the default on first boot. It is not tied to one keyboard:
`--ime-id <package>/<component>` selects which, defaulting to Pastiera.

```
tools/inject-ime.sh --image system.img --apk Keyboard.apk --out out.img \
    --ime-id com.example.kb/.MyInputMethodService   # optional, defaults to Pastiera
```

It handles Android sparse and raw images and **both filesystems GSIs ship**:

- **ext4** — modified in place with `debugfs` (no mount, no `e2fsdroid`)
- **EROFS** — unpacked, injected, repacked with `mkfs.erofs --file-contexts`

Three files are injected, each given an SELinux label resolved from the image's
own `plat_file_contexts` (most-specific rule wins), falling back to
`u:object_r:system_file:s0`:

| Path | Mode | Purpose |
|---|---|---|
| `/system/app/<Name>/<Name>.apk` | 0644 | the IME, as a system app |
| `/system/bin/default-ime-setup.sh` | 0755 | one-shot first-boot setup |
| `/system/etc/init/default-ime.rc` | 0644 | starts it at `sys.boot_completed=1` |

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

Verify a re-download against the extracted image:

```
sha256  e0ff2bcb4198d2c23b35e29b7e02a0d0426626a60e2be65973a3982ea61864be
size    7505539072 bytes   (system.img, after unzip)
```

### Why the GSI is not vendored in this repo

Unlike the Pastiera APK in `prebuilts/`, the GSI is not committed, for two
independent reasons.

**Size.** At 7.5 GB it is 72x GitHub's 100 MB per-file limit; even the 3.99 GB
archive is 38x over. Git LFS does not help at this scale either.

**Licence.** The APK is GPLv3 — redistribution is explicitly permitted, which is
why committing it was straightforward and why the obligations are documented.
The GSI is a community repackaging of Xiaomi's **proprietary** HyperOS.
Publishing it would be redistributing Xiaomi's copyrighted code, which is exactly
what §7 of `DISTRIBUTION-COMPLIANCE.md` warns against. The size limit makes the
question moot, but the licence answer would be the same at any size.

**The residual risk.** The APK was archived precisely because upstream nightlies
get pruned. The same risk applies to this GSI — SourceForge could remove it — and
it cannot be mitigated the same way. The hash above at least makes any future
download verifiable. **Keep a local copy of the archive**; the recipe above will
not help if the file is gone.

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

## Choosing the keyboard

The tool is IME-agnostic, so the choice is on merit, not on what the tooling
supports.

### Kika Keyboard — rejected

Considered and ruled out on two independent grounds.

**Security.** Google removed Kika Keyboard from Play after an internal
investigation found code performing ad fraud (click injection / click flooding),
first documented by Kochava and reported by BuzzFeed News in 2018. The apps
requested permissions including the ability to track keystrokes. An IME observes
every password, message and 2FA code typed on the device, and this tool installs
it to `/system/app`, where it is privileged and cannot be uninstalled normally.
The Unihertz Treble community independently flagged it — see
`phhusson/unihertz_titan` issue #2, "Kika keyboard is suspect".

**Fit.** The consumer Kika app is an on-screen keyboard for emoji, themes and
GIFs. Keypad scrolling — using the physical keys as a trackpad — is a
hardware-keyboard feature it does not implement. Kika's advertised
hardware-keyboard support belongs to their B2B OEM licensing product, which is
not a downloadable app.

### The acquisition blocker is not keyboard-specific

No APK can be fetched from this environment at all: GitHub release assets return
403, and F-Droid, Play, the Kika site, apkmirror, uptodown and apkpure are all
refused by the egress policy. Switching keyboards does not unblock anything —
the APK has to be supplied by hand whichever one is chosen.

### What actually fits the requirement

Advanced symbols, keypad scrolling and emoji on a physical QWERTY are
hardware-keyboard IME features. Pastiera implements exactly these (SYM pages,
swipe-pad cursor gestures, emoji picker, long-press variations) and names the
Unihertz Titan 2 as a reference device, which is why it was chosen. If it is
rejected for other reasons, the replacement should still be an IME that handles
hardware key events — a soft keyboard cannot provide keypad scrolling regardless
of its emoji support.

## Build completed against real inputs

Both inputs were fetched and the image was built and verified.

**Keyboard.** Stable 0.85 could not be obtained: it is published only through
GitHub releases on `palsoftware/pastiera`, and this session cannot reach that
repository's API (cross-owner attach is unsupported) — a session repo-scope
limit, unrelated to network egress. `pastiera.eu` hosts only the **nightly**
F-Droid repo, so the build uses:

```
pastiera-nightly-0.86-nightly.20260820.222455.apk   45,576,726 bytes
sha256 be36f7c3e0a28df56b1a2d112c017d999d65790031d99b171e34d2a01d9643e2   (matches repo index)
```

0.86-nightly is newer than 0.85, so it includes the 0.85 work — whose release
notes explicitly list **"Titan 2 Elite QWERTY"** among expanded device support.
It is a nightly, not a stable build.

**A trap worth recording.** The nightly's applicationId is
`it.palsoftware.pastiera.nightly`, but its IME class keeps the original
namespace, because Gradle's `applicationIdSuffix` does not move the Java
package. The component is therefore:

```
it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService
```

Passing the short form `.inputmethod.…` would expand to
`it.palsoftware.pastiera.nightly.inputmethod.…`, which does not exist, and the
keyboard would silently never activate. `tools/axml.py` reads the package and
IME service straight out of the APK's binary manifest so this is never guessed.

**Result** (6m30s):

| Check | Result |
|---|---|
| Injected files | present, regular, correct modes, `system_file:s0` |
| APK in image | sha256 identical to the signed upstream |
| Manifest re-parsed from in-image copy | package and component intact |
| Boot hook | wired to the fully-qualified component |
| `build.prop` | identical to pristine |
| `e2fsck -fn` | clean |
| Output | `system-pastiera.img`, 7,505,539,072 bytes |

## Reproducing the build

The 7.5 GB image cannot be shipped through this repo or a chat attachment, but
both inputs are public, so the build reproduces in about ten minutes:

```bash
apt-get install -y erofs-utils android-sdk-libsparse-utils e2fsprogs

# 1. GSI  (plain curl defaults - a browser-like User-Agent gets 403 from the mirrors)
curl -sSLO "https://downloads.sourceforge.net/project/mystic-gsi-updates/HyperOS/\
Hyperos-pudding-16-OS3.0.50.2.W-AB-20260122-MysticGSI.zip"
unzip -o Hyperos-pudding-16-*.zip          # -> system.img, 7.5 GB ext4

# 2. Keyboard
curl -sSL -o pastiera.apk \
  "https://pastiera.eu/fdroid/nightly/repo/pastiera-nightly-0.86-nightly.20260820.222455.apk"

# 3. Confirm what the APK actually declares, then inject
python3 tools/axml.py pastiera.apk
tools/inject-ime.sh --image system.img --apk pastiera.apk --out system-pastiera.img \
  --name Pastiera \
  --ime-id it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService
```

Swap in the stable 0.85 APK and its component (package `it.palsoftware.pastiera`,
same class) whenever it is available.

Note that the image now embeds a GPLv3 application. Flashing it to your own
phone is not distribution and triggers nothing; sharing the image would oblige
you to provide Pastiera's corresponding source and installation information.

## Titan 2 Elite firmware: not publicly available

Searched for a stock firmware image to use as a donor for camera, fingerprint,
VoLTE and Widevine work. It does not appear to exist publicly.

| Source | Outcome |
|---|---|
| `lichtmetzger.de` firmware archive | **Standard Titan 2 only.** No mention of the Elite or the Dimensity 7400 |
| `unihertz.com` | No firmware downloads at all; users are directed to OTA (`Settings > About Phone > System Update`). Elite appears only in MWC announcement posts |
| Unihertz official Google Drive | Referenced second-hand, no URL found; reportedly prunes older builds |
| `firmwarebd.com` | **SEO filler.** Shows a plausible filename but carries no download link whatsoever |
| `needrom.com` | Unreachable, and standard Titan 2 regardless |

Two cautions. Titan 2 and Titan 2 Elite are **different SoCs** — Helio-class
versus Dimensity 7400 — so standard Titan 2 firmware is not a valid donor and
would actively mislead. And firmware aggregator sites are a poor provenance for
vendor blobs, which run at high privilege; a repackaged or modified HAL is a real
risk, not a theoretical one.

### Better route: pull it from the device

Now that the bootloader unlocks, the device itself is a better source than any
download — authentic, current, and exactly the right build. Most of what is
needed needs **no root**, because the relevant parts of `/system` and `/vendor`
are world-readable:

```bash
tools/collect-device-info.sh
```

This gathers HAL manifests, build properties, telephony/IMS layout, DRM and
fingerprint state, camera configuration, package lists, and pulls any IMS APKs
and MediaTek telephony jars it finds, then tars the result. Root is used if
present and skipped cleanly if not.

The single most valuable file is `vintf/vendor-manifest.xml`: it names the real
HAL versions and settles the fingerprint AIDL-versus-HIDL question immediately.

Note: this script has not been run against hardware — there is no device in this
environment. Expect to adjust paths once real output exists.
