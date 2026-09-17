#!/usr/bin/env bash
# Build the Facet RRO overlays. Needs the Android SDK (aapt2, apksigner) and a
# signing key; cannot run in the Claude environment, where dl.google.com is blocked.
set -euo pipefail
: "${ANDROID_JAR:?set ANDROID_JAR to a platform android.jar, e.g. \$ANDROID_HOME/platforms/android-35/android.jar}"
: "${KEYSTORE:?set KEYSTORE to a signing keystore}"
: "${KEYSTORE_PASS:?set KEYSTORE_PASS to the keystore password}"
OUT="${OUT:-$(pwd)/out}"; mkdir -p "$OUT"
cd "$(dirname "$0")"

for ov in FacetSystemUI FacetFramework; do
  echo "[*] $ov"
  aapt2 compile --dir "$ov/res" -o "$OUT/$ov-res.zip"
  aapt2 link -I "$ANDROID_JAR" \
        --manifest "$ov/AndroidManifest.xml" \
        -o "$OUT/$ov-unsigned.apk" "$OUT/$ov-res.zip"
  # Pass the password explicitly: apksigner otherwise blocks reading stdin,
  # which fails in any non-interactive context.
  apksigner sign --ks "$KEYSTORE" \
      --ks-pass "pass:$KEYSTORE_PASS" --key-pass "pass:$KEYSTORE_PASS" \
      --out "$OUT/$ov.apk" "$OUT/$ov-unsigned.apk"
  echo "    -> $OUT/$ov.apk"
done
echo "Inject into /system/product/overlay/ with the same labelling inject-ime.sh uses."
