#!/usr/bin/env bash
# Collect everything needed to plan camera / fingerprint / VoLTE / Widevine work
# on a Titan 2 Elite, straight from the device over adb.
#
#   tools/collect-device-info.sh [outdir]
#
# Most of this needs no root: /system and /vendor are world-readable on Android
# for the files that matter. Anything requiring root is attempted and skipped
# cleanly if unavailable.

set -uo pipefail
OUT="${1:-device-dump-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"/{props,vintf,telephony,media,biometrics,camera,packages,apks}

command -v adb >/dev/null || { echo "error: adb not found (install android-tools/platform-tools)"; exit 1; }

echo "[*] waiting for device..."
adb wait-for-device || exit 1
adb shell true >/dev/null 2>&1 || { echo "error: device not responding to adb shell"; exit 1; }

have_root=no
adb shell 'su -c id' 2>/dev/null | grep -q 'uid=0' && have_root=yes
echo "[*] root available: $have_root"

sh()  { adb shell "$@" 2>/dev/null; }
cap() { local f="$1"; shift; echo "  -> $f"; sh "$@" > "$OUT/$f" 2>/dev/null; }

echo "[*] properties"
cap props/getprop.txt            'getprop'
cap props/system-build.prop.txt  'cat /system/build.prop'
cap props/vendor-build.prop.txt  'cat /vendor/build.prop'

echo "[*] VINTF / HAL manifests   <- the most important part"
cap vintf/vendor-manifest.xml    'cat /vendor/etc/vintf/manifest.xml'
cap vintf/system-manifest.xml    'cat /system/etc/vintf/manifest.xml'
cap vintf/vendor-dir.txt         'ls -laR /vendor/etc/vintf'
cap vintf/hal-services.txt       'ls -la /vendor/bin/hw /vendor/lib64/hw'
cap vintf/running-hals.txt       'ps -A -o NAME | grep -iE "hardware|hal|@"'

echo "[*] telephony / IMS (VoLTE)"
cap telephony/ims-apks.txt       'find /system /vendor /product /system_ext -iname "*ims*" -maxdepth 6'
cap telephony/mtk-framework.txt  'ls -la /system/framework /system_ext/framework /vendor/framework'
cap telephony/carrier.txt        'ls -la /vendor/etc/carrier /product/etc/CarrierConfig 2>/dev/null'
cap telephony/registry.txt       'dumpsys telephony.registry'
cap telephony/subscription.txt   'dumpsys isub'

echo "[*] Widevine / DRM"
cap media/drm.txt                'dumpsys media.drm'
cap media/drm-libs.txt           'ls -la /vendor/lib64/mediadrm /vendor/lib/mediadrm'
cap media/drm-hal.txt            'ls -la /vendor/bin/hw | grep -i drm'

echo "[*] fingerprint / biometrics"
cap biometrics/fingerprint.txt   'dumpsys fingerprint'
cap biometrics/hal.txt           'ls -la /vendor/bin/hw | grep -iE "fingerprint|biometric"'
cap biometrics/features.txt      'pm list features'

echo "[*] camera"
cap camera/dumpsys.txt           'dumpsys media.camera'
cap camera/hal.txt               'ls -la /vendor/bin/hw | grep -i camera'
cap camera/configs.txt           'ls -la /vendor/etc/camera'

echo "[*] packages and partitions"
cap packages/system-apks.txt     'pm list packages -s -f'
cap packages/partitions.txt      'ls -la /dev/block/by-name'
cap packages/mounts.txt          'cat /proc/mounts'

echo "[*] pulling IMS APKs and telephony jars (the VoLTE donors)"
for p in $(sh 'find /system /system_ext /vendor /product -iname "*ims*.apk" -o -iname "*ims*.jar" -o -iname "*mediatek*telephony*.jar" 2>/dev/null' | tr -d '\r'); do
  [ -n "$p" ] || continue
  echo "  -> $p"
  adb pull "$p" "$OUT/apks/$(echo "${p#/}" | tr '/' '_')" >/dev/null 2>&1
done

if [ "$have_root" = yes ]; then
  echo "[*] root present: capturing full partition list and SELinux policy"
  cap vintf/vendor-tree.txt 'su -c "ls -laR /vendor/etc"'
  cap props/selinux.txt     'su -c "getenforce"'
fi

tar czf "$OUT.tar.gz" "$OUT" 2>/dev/null
echo
echo "[*] done -> $OUT.tar.gz  ($(du -h "$OUT.tar.gz" 2>/dev/null | cut -f1))"
echo "    The single most useful file is vintf/vendor-manifest.xml — it names the"
echo "    real HAL versions and settles the fingerprint AIDL-vs-HIDL question."
