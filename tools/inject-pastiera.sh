#!/usr/bin/env bash
# Inject Pastiera into a GSI system image and make it the default IME.
#
#   inject-pastiera.sh --image system.img --apk Pastiera.apk --out system-pastiera.img
#
# Handles Android sparse and raw images, EROFS filesystems (what Android 14+
# GSIs ship). SELinux labels are reapplied from the image's own
# plat_file_contexts, so injected files get policy-correct contexts.

set -euo pipefail

IME_PKG="it.palsoftware.pastiera"
IME_CLASS="it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService"
IME_ID="${IME_PKG}/${IME_CLASS}"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[*] $*"; }

IMAGE= APK= OUT= KEEP_TREE=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --apk)   APK="$2";   shift 2 ;;
    --out)   OUT="$2";   shift 2 ;;
    --keep-tree) KEEP_TREE="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "$IMAGE" && -n "$APK" && -n "$OUT" ]] || die "need --image, --apk and --out"
[[ -f "$IMAGE" ]] || die "no such image: $IMAGE"
[[ -f "$APK"   ]] || die "no such apk: $APK"

for t in simg2img fsck.erofs mkfs.erofs; do
  command -v "$t" >/dev/null || die "missing tool: $t (apt-get install erofs-utils android-sdk-libsparse-utils)"
done

WORK="$(mktemp -d)"
cleanup() { [[ -n "$KEEP_TREE" ]] || rm -rf "$WORK"; }
trap cleanup EXIT

# --- 1. sparse -> raw -------------------------------------------------------
magic4() { od -An -tx4 -N4 -j"${2:-0}" "$1" | tr -d ' \n'; }

RAW="$IMAGE"
if [[ "$(magic4 "$IMAGE")" == "ed26ff3a" ]]; then
  log "sparse image detected, converting to raw"
  RAW="$WORK/raw.img"
  simg2img "$IMAGE" "$RAW"
else
  log "raw image"
fi

# --- 2. identify filesystem -------------------------------------------------
# EROFS superblock magic lives at offset 1024; ext4's is 0x53EF at 0x438.
FS=
[[ "$(magic4 "$RAW" 1024)" == "e0f5e1e2" ]] && FS=erofs
if [[ -z "$FS" ]]; then
  if od -An -tx2 -N2 -j$((0x438)) "$RAW" | tr -d ' \n' | grep -q '^ef53$'; then FS=ext4; fi
fi
[[ -n "$FS" ]] || die "unrecognised filesystem (not EROFS or ext4)"
log "filesystem: $FS"
[[ "$FS" == "erofs" ]] || die "only EROFS repacking is supported; this image is $FS.
ext4 repacking needs e2fsdroid to restore SELinux labels, which is not available here."

# --- 3. extract -------------------------------------------------------------
TREE="${KEEP_TREE:-$WORK/tree}"
mkdir -p "$TREE"
log "extracting to $TREE"
fsck.erofs --extract="$TREE" --preserve --overwrite --force "$RAW" >/dev/null

# A GSI may be rooted at / or at /system depending on how it was built.
# PREFIX is the path the *packed tree root* corresponds to on the device, so an
# image that already contains system/ is rooted at /, not at /system.
if   [[ -d "$TREE/system/etc" ]]; then ROOT="$TREE/system"; PREFIX=/
elif [[ -d "$TREE/etc" ]];        then ROOT="$TREE";        PREFIX=/system
else die "cannot locate system root inside image"; fi
log "system root: $ROOT (tree root maps to $PREFIX)"

# --- 4. inject --------------------------------------------------------------
log "installing $IME_PKG as a system app"
install -d -m 0755 "$ROOT/app/Pastiera"
install -m 0644 "$APK" "$ROOT/app/Pastiera/Pastiera.apk"

log "adding first-boot default-IME hook"
install -d -m 0755 "$ROOT/bin" "$ROOT/etc/init"
cat > "$ROOT/bin/pastiera-setup-ime.sh" <<EOF
#!/system/bin/sh
# Select Pastiera as the input method on first boot. Runs once.
IME="${IME_ID}"
STAMP=/data/misc/pastiera/.default-ime-applied
[ -f "\$STAMP" ] && exit 0

# Wait for package manager to have scanned the system app.
i=0
while [ \$i -lt 60 ]; do
    pm path "${IME_PKG}" >/dev/null 2>&1 && break
    i=\$((i+1)); sleep 2
done
pm path "${IME_PKG}" >/dev/null 2>&1 || exit 1

settings put secure enabled_input_methods "\$IME"
settings put secure default_input_method  "\$IME"
# Physical-keyboard devices otherwise hide the IME entirely.
settings put secure show_ime_with_hard_keyboard 1

mkdir -p /data/misc/pastiera && touch "\$STAMP"
EOF
chmod 0755 "$ROOT/bin/pastiera-setup-ime.sh"

cat > "$ROOT/etc/init/pastiera-ime.rc" <<EOF
# Set Pastiera as the default input method once the framework is up.
service pastiera_ime /system/bin/sh /system/bin/pastiera-setup-ime.sh
    user root
    group root system
    disabled
    oneshot

on property:sys.boot_completed=1
    start pastiera_ime
EOF
chmod 0644 "$ROOT/etc/init/pastiera-ime.rc"

# --- 5. repack --------------------------------------------------------------
# Relabel from the image's own policy so injected files match what SELinux
# expects for /system/app, /system/bin and /system/etc.
FC="$ROOT/etc/selinux/plat_file_contexts"
FC_ARG=()
if [[ -f "$FC" ]]; then
  log "relabelling from $(basename "$FC")"
  FC_ARG=(--file-contexts="$FC")
else
  echo "warning: plat_file_contexts not found; SELinux labels will not be reapplied" >&2
fi

log "repacking -> $OUT"
mkfs.erofs -zlz4hc "${FC_ARG[@]}" --mount-point="$PREFIX" \
           --force-uid=0 --force-gid=0 "$OUT" "$TREE" >/dev/null

log "done: $OUT ($(du -h "$OUT" | cut -f1))"
echo
echo "If the first-boot hook does not take effect (SELinux may block it on an"
echo "enforcing GSI), set it manually over adb — this always works:"
echo "  adb shell ime enable $IME_ID"
echo "  adb shell ime set    $IME_ID"
