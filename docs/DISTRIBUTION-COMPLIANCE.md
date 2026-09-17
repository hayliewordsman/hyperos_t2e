# Source and Installation Information for Redistributed Images

**Ship this file alongside any image built by `tools/inject-ime.sh` that contains
Pastiera.** It is written to satisfy GPLv3 §6 (conveying non-source forms) and
the Installation Information requirement that applies to User Products.

Placeholders in `<ANGLE BRACKETS>` must be filled in before you publish. This is
a compliance template, not legal advice — if the distribution is commercial, have
a lawyer read it.

---

## 1. What this covers

The image includes **Pastiera**, an Android input method licensed under the
**GNU General Public License, version 3**. Conveying the image conveys Pastiera,
which obliges you to offer its Corresponding Source and, because a phone is a
User Product, the information needed to install a modified version.

It does **not** cover the rest of the image. See §7.

## 2. The exact binary conveyed

| | |
|---|---|
| File in image | `/system/app/Pastiera/Pastiera.apk` |
| Upstream filename | `pastiera-nightly-0.86-nightly.20260820.222455.apk` |
| SHA-256 | `be36f7c3e0a28df56b1a2d112c017d999d65790031d99b171e34d2a01d9643e2` |
| Package (applicationId) | `it.palsoftware.pastiera.nightly` |
| Version | `0.86-nightly.20260820.222455` |
| Obtained from | `https://pastiera.eu/fdroid/nightly/repo/` |

**The APK is unmodified.** `tools/inject-ime.sh` copies it byte-for-byte; the
hash above matches both the upstream F-Droid repo index and the copy extracted
back out of the finished image. You are therefore conveying an unmodified
upstream work, and the Corresponding Source is simply upstream's source at the
matching revision.

If you rebuild Pastiera yourself, or ship a different version, **update this
entire section** — Corresponding Source must correspond to the binary you
actually convey.

## 3. Corresponding Source (GPLv3 §1 and §6)

| | |
|---|---|
| Project | Pastiera |
| Upstream repository | `https://github.com/palsoftware/pastiera` |
| Tag | `nightly/v0.86-nightly.20260820.222455` |
| Commit | `138b67161e6a8c14c6723088cc933e97d4d021f0` |
| Licence | GPL-3.0 (`LICENSE` in the repository root) |

```bash
git clone https://github.com/palsoftware/pastiera
git -C pastiera checkout 138b67161e6a8c14c6723088cc933e97d4d021f0
```

One caveat on provenance: the tag name matches the APK's version string, but
nothing here *proves* the upstream binary was built from that commit — it is not
a verified reproducible build. If you need certainty, build the APK yourself
from this commit and ship your own build, then update §2.

### Host the source yourself

GPLv3 §6(d) lets you satisfy the obligation by offering the source from the same
place as the binary, at no further charge. Pointing at upstream is permitted only
if you "maintain clear directions next to the object code saying where to find
the Corresponding Source" and it remains available for as long as you offer the
binary.

**Nightly builds get pruned.** If upstream deletes this nightly, a pointer to it
stops satisfying §6, and you are in breach without having changed anything. Host
your own copy of the source tree next to your image:

- Corresponding Source: `<YOUR URL FOR THE SOURCE ARCHIVE>`
- Kept available for as long as the image is offered, at no charge.

## 4. Build instructions

Corresponding Source includes "the scripts used to control compilation and
installation". Pastiera builds with its own Gradle wrapper:

| | |
|---|---|
| Gradle | 8.13 (via `./gradlew`) |
| JDK | 11 (`jvmTarget = "11"`) |
| Android Gradle Plugin | 8.11.0 |
| Kotlin | 2.0.21 |
| compileSdk / targetSdk | 36 |
| minSdk | 29 |

```bash
cd pastiera
./gradlew :app:assembleStableRelease     # stable variant
```

The nightly variant applies `applicationIdSuffix = ".nightly"` and derives its
version name from build parameters. Confirm the exact task and flags for the
build you are shipping from `.github/workflows/release.yml` in the repository,
and record them here: `<EXACT BUILD COMMAND USED>`

## 5. Installation Information (GPLv3 §6, User Product)

This is what a recipient needs to build a modified Pastiera and run it on a
device carrying this image. No authorization keys, signing secrets or vendor
unlock codes are withheld — no such restriction is imposed by this image.

### Route A — rebuild the image (the supported route)

1. **Unlock the bootloader.** Follow the device manufacturer's procedure. This
   is a prerequisite imposed by the device, not by this image.
2. Build a modified Pastiera per §4, producing `Pastiera.apk`.
3. Rebuild the image with your APK in place of the bundled one:

```bash
tools/inject-ime.sh \
  --image system.img \
  --apk /path/to/your/Pastiera.apk \
  --out system-modified.img \
  --name Pastiera \
  --ime-id <YOUR PACKAGE>/<YOUR IME SERVICE CLASS>
```

Read the correct `--ime-id` out of your own APK rather than guessing — a wrong
component leaves the keyboard silently inactive:

```bash
python3 tools/axml.py /path/to/your/Pastiera.apk
```

4. Flash the result to the device's system partition and reboot.

### Route B — install over the top

A self-built Pastiera is signed with **your** key, not upstream's, so Android
will refuse to treat it as an update to the bundled copy. Remove the bundled one
first — either take it out of the image with Route A, or, on a device with root,
delete `/system/app/Pastiera/` — then install yours normally:

```bash
adb install your-pastiera.apk
adb shell ime enable  <package>/<service>
adb shell ime set     <package>/<service>
```

### Nothing is locked down

The image sets no verified-boot restriction, signature pinning, or rollback
counter that would prevent a modified Pastiera from running. The only gate is
the device's own bootloader lock, which the owner controls.

## 6. Third-party components inside Pastiera

Pastiera is GPLv3 overall, and carries components under their own terms. Ship
its `THIRD_PARTY_NOTICES.md` unmodified alongside this file; in summary:

| Component | Licence |
|---|---|
| AOSP LatinIME (keyboard geometry and `.9.png` assets) — pinned revision `127336e9f29d69607eab55982324b210279ae8c5` | Apache-2.0 |
| OpenGameArt typing soundpack by *unicaegames* | CC0-1.0 |
| Unicode CLDR emoji search data | Unicode licence terms |

Licence texts are in `third_party/licenses/` in the Pastiera repository.

## 7. What this document does **not** make lawful

**This covers Pastiera only.** The image is overwhelmingly HyperOS, which is
Xiaomi proprietary software. Nothing here grants any right to redistribute it —
a GPL compliance document does not address, and cannot cure, the separate
question of redistributing Xiaomi's copyrighted code. Publishing a HyperOS image
is a copyright matter between you and Xiaomi, and the practical risk is a
takedown.

Two related points:

- **Aggregation.** Placing a GPLv3 APK beside other programs in a filesystem
  image is mere aggregation under GPLv3 §5. It does **not** place HyperOS under
  the GPL. The problem with redistributing HyperOS is Xiaomi's own copyright,
  not a GPL obligation.
- **This repository's tooling** (`inject-ime.sh`, `axml.py`, the generated init
  hook and setup script) is original work that merely installs Pastiera. It is
  not a derivative of it, and carries whatever licence you choose for this repo.

Flashing an image to a phone you own is not conveying, and triggers none of this.
Every obligation above begins the moment you hand the image to someone else.

## 8. The simplest way to comply: don't ship the APK

If you distribute the **tooling and instructions** rather than a pre-built image,
you convey no GPL work, and none of §§2–6 applies. Each user fetches Pastiera
themselves from `https://pastiera.eu/` and runs `inject-ime.sh` locally, which
takes about ten minutes.

This also sidesteps §7 entirely, since you would not be redistributing HyperOS
either. **For a public release this is the recommended route by a wide margin.**

## 9. Before you publish — checklist

- [ ] §2 matches the APK actually in the image (re-verify the SHA-256)
- [ ] §3 source archive hosted at a URL you control, and reachable
- [ ] §4 exact build command recorded
- [ ] `THIRD_PARTY_NOTICES.md` and `LICENSE` from Pastiera shipped alongside
- [ ] `<ANGLE BRACKET>` placeholders all replaced
- [ ] You have decided what to do about §7

## Appendix — written offer (GPLv3 §6(b))

Only needed if you ship physical media instead of a download. A §6(b) offer must
be valid for **three years**, and must be extended to any third party who
receives the image from your recipient.

> The image accompanying this notice includes Pastiera, licensed under the GNU
> General Public License version 3. For three years from the date you received
> this product, we will provide to anyone who asks, for a charge no more than our
> cost of physically performing the distribution, a complete machine-readable
> copy of the Corresponding Source for the version of Pastiera contained in it,
> together with the information required to install a modified version.
>
> Requests to: `<YOUR CONTACT ADDRESS>`
