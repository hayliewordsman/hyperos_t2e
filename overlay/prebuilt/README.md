# Facet Tier 2 overlays (prebuilt)

The two RRO overlays, built and signed, so the Tier 2 image can be produced
without installing an Android SDK.

| APK | Target | Resources |
|---|---|---|
| `FacetSystemUI.apk` | `com.android.systemui` | 11 — 5 dimens, 2 bools, 4 colors |
| `FacetFramework.apk` | `android` | 1 — `config_sf_slowBlur` |

Verify before use:

```bash
sha256sum -c SHA256SUMS
```

## Injecting them

See [building.md](../../docs/building.md#adding-facet-tier-2-with-no-source-build).
In short:

```bash
tools/inject-ime.sh --image <gsi>.img ... \
  --add-file overlay/prebuilt/FacetSystemUI.apk:product/overlay/FacetSystemUI.apk \
  --add-file overlay/prebuilt/FacetFramework.apk:product/overlay/FacetFramework.apk
```

## The signing key is not here, deliberately

These were signed with a throwaway key generated in a disposable environment.
**That key is gone**, and it is not committed — this repository is public, and a
private signing key does not belong in one.

Consequences worth understanding:

- **You cannot reproduce these byte-for-byte.** Rebuilding with `overlay/build.sh`
  produces functionally identical overlays with a different signature.
- **Generate and keep your own keystore** if you intend to ship updates, so
  successive builds share a signature:
  ```bash
  keytool -genkeypair -keystore facet.keystore -alias facet \
          -keyalg RSA -keysize 2048 -validity 10000
  ```
- For overlays on a trusted partition the signature matters less than for
  user-installed apps, since `/product/overlay` is trusted by location. That is
  the theory; it has not been tested on a device.

## Unverified

Whether these actually take effect. `android:isStatic` is deprecated on modern
Android, so they may need enabling explicitly:

```bash
adb shell cmd overlay list | grep -i facet
adb shell cmd overlay enable dev.titan2e.facet.systemui
adb shell cmd overlay enable dev.titan2e.facet.framework
```

Nothing in this repository has run on hardware.
