# Building and testing without hardware

## The shortcut worth knowing

**To iterate on SystemUI, do not build a GSI.** Build the *emulator* target
instead. A GSI exists to run on a real device; for UI work it adds an hour of
build time and a flashing step that tell you nothing extra.

```bash
source build/envsetup.sh
lunch sdk_phone64_x86_64-userdebug     # or aosp_cf_x86_64_phone for Cuttlefish
m -j$(nproc)
emulator -writable-system
```

Build the GSI only once the look is settled and you want it on the phone.

## If you do not have 250-400 GB

The full build is genuinely large, and running out of disk at 90% after several
hours is the worst outcome. Around **130 GB is not enough**: the source alone is
60-80 GB even with `-c --no-tags`, and `out/` for a full emulator build adds
80-120 GB.

Three ways round it, cheapest first:

1. **Validate the shaders instead of building the ROM.** The riskiest untested
   thing here is whether the AGSL compiles at all — everything else is verified.
   `tools/shader-check/` is a ~20 MB Android app that compiles both shaders and
   draws them, and runs on any Android 13+ emulator. That removes the most
   likely failure for the price of Android Studio.
2. **Build on an external drive.** A 1 TB USB SSD is cheap and sufficient. A
   spinning disk works but the build is I/O bound, so expect it to drag.
3. **Rent a cloud VM for an afternoon.** A machine with 500 GB and plenty of
   cores costs a few currency units for the hours a build takes, and is what
   many ROM developers actually do.

Option 1 does not replace a build — see the limits in that directory's README —
but it is the highest value per gigabyte available.

## Host requirements

| | |
|---|---|
| OS | Linux (Ubuntu 22.04+ is the well-trodden path) |
| Disk | **250–400 GB**, SSD strongly preferred |
| RAM | 16 GB minimum, 32 GB comfortable |
| CPU | more cores is linearly faster; expect 1–4 h for a first build |

None of this fits in the Claude environment, which is why nothing here has been
compiled.

## Sync the tree — /e/OS, not LineageOS

Build **/e/OS**, so the result keeps the microG privacy stack that was the reason
for choosing it. Building plain LineageOS would compile Facet but throw that away.

```bash
mkdir eos && cd eos
repo init -u https://gitlab.e.foundation/e/os/android.git -b a16 --git-lfs
repo sync -c -j8 --no-clone-bundle --no-tags      # ~100 GB, takes a while
```

`a16` is the manifest's default branch and is Android 16, matching the prebuilt
GSI this project adopted. Match the branch to the Android version the device
actually ships; see `base-selection.md` on why an older system image on a newer
vendor is the unsupported direction.

**Why the patches still apply.** /e/OS is built as a layer over LineageOS — its
manifest carries `lineage-23.0`, `lineage-23.1` and `lineage-23.2` branches
alongside its own. The Facet patches were generated against LineageOS
`lineage-23.0` `frameworks/base`, which is what /e/OS derives from, so they
should port. They are not guaranteed to: /e/OS may carry its own SystemUI
changes that move the context lines. Run `git apply --check` first and say so if
it fails, rather than forcing it.

## Apply the Facet patches

```bash
cd frameworks/base
git apply --check /path/to/titan2e-eos/patches/systemui/0001-facet-specular-edge.patch
git apply         /path/to/titan2e-eos/patches/systemui/0001-facet-specular-edge.patch
git apply --check /path/to/titan2e-eos/patches/systemui/0002-facet-rim-darkening.patch
git apply         /path/to/titan2e-eos/patches/systemui/0002-facet-rim-darkening.patch
cd ../..
```

Always run `--check` first. These were generated against `lineage-23.0` and have
never been compiled, so expect to fix something on the first build.

## Build

```bash
source build/envsetup.sh
lunch lineage_arm64_bvS-userdebug     # generic A/B arm64 target -- no device tree needed
                                      # (/e/OS keeps LineageOS target names)
m -j$(nproc) systemimage
```

Output lands in `out/target/product/*/system.img`.

## Emulating it

### Cuttlefish — the closest thing to real hardware

Google's virtual device, purpose-built for this. Needs Linux and **KVM**.

```bash
sudo apt install -y git devscripts config-package-dev debhelper-compat golang curl
git clone https://github.com/google/android-cuttlefish && cd android-cuttlefish
tools/buildutils/build_packages.sh
sudo dpkg -i ./cuttlefish-base_*.deb ./cuttlefish-user_*.deb
sudo usermod -aG kvm,cvdnetwork,render $USER    # then log out and back in

launch_cvd --gpu_mode=gfxstream                 # GPU acceleration matters here
```

`--gpu_mode=gfxstream` is the important flag. Under software rendering the glass
work will be unwatchably slow and will tell you nothing useful.

### The honest limit

**The emulator may not prove the blur.** The whole design depends on
`ro.surface_flinger.supports_background_blur=1`, and whether a virtual GPU
honours cross-window blur at usable frame rates is not guaranteed. You can
verify that the patches compile, that the shader produces the intended geometry,
and that nothing crashes. Whether it *feels* like glass at 120 Hz on Mali-G615 is
a question only the device answers.

Set the property in the emulator too, or the blur path never runs:

```bash
adb root && adb remount
adb shell setprop ro.surface_flinger.supports_background_blur 1
adb shell stop && adb shell start
```

## Producing the flashable image

This is the canonical invocation. It adds the keyboard, enables blur, and
applies the ADB hardening from `security-posture.md` in one pass. Other
documents reference this section rather than repeating the flags, so there is
one copy to keep correct.

```bash
tools/inject-ime.sh \
  --image  out/target/product/*/system.img \
  --apk    prebuilts/pastiera/pastiera-nightly-0.86-nightly.20260820.222455.apk \
  --out    system-facet-hardened.img \
  --name   Pastiera \
  --ime-id it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService \
  --set-prop ro.surface_flinger.supports_background_blur=1 \
  --set-prop ro.adb.secure=1 \
  --set-prop ro.debuggable=0
```

The same command works on a downloaded /e/OS GSI; only `--image` changes.

### Adding Facet Tier 2, with no source build

The RRO overlays are APKs, so they inject like any other file. This produces a
complete Tier 2 image from the **prebuilt** /e/OS GSI:

```bash
overlay/build.sh                       # needs ANDROID_JAR, KEYSTORE, KEYSTORE_PASS

tools/inject-ime.sh \
  --image  v4.3-a16-20260821-microG-gsi.img \
  --apk    prebuilts/pastiera/pastiera-nightly-0.86-nightly.20260820.222455.apk \
  --out    eos-facet-tier2.img \
  --name   Pastiera \
  --ime-id it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService \
  --add-file overlay/out/FacetSystemUI.apk:product/overlay/FacetSystemUI.apk \
  --add-file overlay/out/FacetFramework.apk:product/overlay/FacetFramework.apk \
  --set-prop ro.surface_flinger.supports_background_blur=1 \
  --set-prop ro.adb.secure=1 \
  --set-prop ro.debuggable=0
```

This has been run. Five files inject and verify, both overlays come back
byte-identical with their 11 and 1 resources intact, all three properties appear
exactly once, `e2fsck` is clean. Nine seconds.

**It gets the resource half of Facet only** — blur radii, tint, the enabling
flags. The edge highlight and rim darkening are shaders in SystemUI source and
need the full build below.

**Enablement is unverified.** `android:isStatic` is deprecated on modern Android,
so an overlay in `/product/overlay` may need enabling explicitly:

```bash
adb shell cmd overlay list | grep -i facet
adb shell cmd overlay enable dev.titan2e.facet.systemui
adb shell cmd overlay enable dev.titan2e.facet.framework
```

The overlays are also signed with a self-generated key rather than the platform
key. Being on a trusted partition should be enough, but that has not been tested
on a device.

| Flag | Why |
|---|---|
| `ro.surface_flinger.supports_background_blur=1` | Without it SurfaceFlinger does no cross-window blur and the glass design collapses to flat translucency |
| `ro.adb.secure=1` | The GSI ships this as `0`, which disables ADB authorisation entirely — any USB host can connect |
| `ro.debuggable=0` | The GSI ships `1`, which allows `adb root` |

Read `--ime-id` out of whichever APK you are shipping rather than copying it:
`python3 tools/axml.py <apk>`. Pastiera's nightly keeps its IME class in the
non-nightly namespace, so the short form silently resolves to nothing.

### Verified on the /e/OS Android 16 image

Each property appears **exactly once** afterwards. `ro.adb.secure` and
`ro.debuggable` already existed, so they are replaced in place rather than
appended — a duplicate line would leave Android resolving between two
conflicting values. The file grew 214 → 215 lines: two replacements, one
addition. `build.prop` keeps its original mode and SELinux label, the APK comes
back byte-identical, and `e2fsck` is clean.

### Confirm on the device

```bash
adb shell getprop ro.adb.secure ro.debuggable \
                  ro.surface_flinger.supports_background_blur
```

Then try connecting from an unauthorised host. **If ADB attaches without
prompting, the hardening did not take effect** and the exposure is still open.

None of this has been tested on hardware.

## Getting it onto the phone, eventually

Follow `day-one.md` — in particular, take the stock backup **before** flashing
anything, because no public Titan 2 Elite firmware exists to restore.
