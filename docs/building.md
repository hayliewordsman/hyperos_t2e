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

## Host requirements

| | |
|---|---|
| OS | Linux (Ubuntu 22.04+ is the well-trodden path) |
| Disk | **250–400 GB**, SSD strongly preferred |
| RAM | 16 GB minimum, 32 GB comfortable |
| CPU | more cores is linearly faster; expect 1–4 h for a first build |

None of this fits in the Claude environment, which is why nothing here has been
compiled.

## Sync the tree

```bash
mkdir lineage && cd lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-23.0 --git-lfs
repo sync -c -j8 --no-clone-bundle --no-tags      # ~100 GB, takes a while
```

Match the branch to the Android version the device actually ships; see
`base-selection.md` on why an older system image on a newer vendor is the
unsupported direction.

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

## Getting it onto the phone, eventually

The image built above can be fed straight to the injection tool, which adds the
keyboard and sets the blur property inside the image:

```bash
tools/inject-ime.sh \
  --image out/target/product/*/system.img \
  --apk prebuilts/pastiera/pastiera-nightly-*.apk \
  --out system-facet.img \
  --name Pastiera \
  --ime-id it.palsoftware.pastiera.nightly/it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService \
  --set-prop ro.surface_flinger.supports_background_blur=1
```

Then follow `day-one.md` — in particular, take the stock backup **before**
flashing anything, because no public Titan 2 Elite firmware exists to restore.
