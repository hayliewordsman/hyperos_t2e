#!/usr/bin/env bash
# Inject Pastiera into a GSI system image and make it the default IME.
#
#   inject-pastiera.sh --image system.img --apk Pastiera.apk --out system-pastiera.img
#
# Handles Android sparse and raw images. Supports both filesystems GSIs ship:
#   ext4  - modified in place with debugfs (no mount, no e2fsdroid needed)
#   erofs - unpacked and repacked, relabelled from plat_file_contexts
#
# SELinux labels are applied to every injected file; without them the IME will
# not load on an enforcing build.

set -euo pipefail

IME_PKG="it.palsoftware.pastiera"
IME_CLASS="it.palsoftware.pastiera.inputmethod.PhysicalKeyboardInputMethodService"
IME_ID="${IME_PKG}/${IME_CLASS}"
DEFAULT_LABEL="u:object_r:system_file:s0"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[*] $*"; }

IMAGE= APK= OUT= KEEP_TREE=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --apk)   APK="$2";   shift 2 ;;
    --out)   OUT="$2";   shift 2 ;;
    --keep-tree) KEEP_TREE="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "$IMAGE" && -n "$APK" && -n "$OUT" ]] || die "need --image, --apk and --out"
[[ -f "$IMAGE" ]] || die "no such image: $IMAGE"
[[ -f "$APK"   ]] || die "no such apk: $APK"

WORK="$(mktemp -d)"
cleanup() { [[ -n "$KEEP_TREE" ]] || rm -rf "$WORK"; }
trap cleanup EXIT

# --- payload ----------------------------------------------------------------
# The three files injected into the image, staged on disk first.
STAGE="$WORK/stage"; mkdir -p "$STAGE"
cp "$APK" "$STAGE/Pastiera.apk"

cat > "$STAGE/pastiera-setup-ime.sh" <<EOF
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

cat > "$STAGE/pastiera-ime.rc" <<EOF
# Set Pastiera as the default input method once the framework is up.
service pastiera_ime /system/bin/sh /system/bin/pastiera-setup-ime.sh
    user root
    group root system
    disabled
    oneshot

on property:sys.boot_completed=1
    start pastiera_ime
EOF

# device path : staged file : mode
# Modes include the S_IFREG bits (0100000). debugfs "sif mode" writes i_mode
# verbatim, so a bare 0644 clears the file-type nibble and e2fsck then deletes
# the inode as corrupt.
PAYLOAD=(
  "app/Pastiera/Pastiera.apk:$STAGE/Pastiera.apk:0100644"
  "bin/pastiera-setup-ime.sh:$STAGE/pastiera-setup-ime.sh:0100755"
  "etc/init/pastiera-ime.rc:$STAGE/pastiera-ime.rc:0100644"
)

# --- 1. sparse -> raw -------------------------------------------------------
magic4() { od -An -tx4 -N4 -j"${2:-0}" "$1" | tr -d ' \n'; }

if [[ "$(magic4 "$IMAGE")" == "ed26ff3a" ]]; then
  command -v simg2img >/dev/null || die "sparse image needs simg2img"
  log "sparse image detected, converting to raw"
  simg2img "$IMAGE" "$OUT"
else
  log "raw image"
  cp --reflink=auto "$IMAGE" "$OUT"
fi

# --- 2. identify filesystem -------------------------------------------------
# EROFS superblock magic sits at 1024; ext4's 0xEF53 at 0x438. od -tx4 prints
# the little-endian word, so EROFS reads back as e0f5e1e2.
FS=
[[ "$(magic4 "$OUT" 1024)" == "e0f5e1e2" ]] && FS=erofs
if [[ -z "$FS" ]] && od -An -tx2 -N2 -j$((0x438)) "$OUT" | tr -d ' \n' | grep -q '^ef53$'; then
  FS=ext4
fi
[[ -n "$FS" ]] || die "unrecognised filesystem (not EROFS or ext4)"
log "filesystem: $FS"

# Resolve the SELinux label for a device path from a file_contexts file,
# most-specific match wins. Falls back to system_file.
resolve_label() {
  local devpath="$1" fc="$2"
  [[ -f "$fc" ]] || { echo "$DEFAULT_LABEL"; return; }
  python3 - "$devpath" "$fc" "$DEFAULT_LABEL" <<'PY'
import re,sys
path,fc,fallback=sys.argv[1],sys.argv[2],sys.argv[3]
best=None
for line in open(fc,encoding='utf-8',errors='replace'):
    line=line.strip()
    if not line or line.startswith('#'): continue
    parts=line.split()
    if len(parts)<2: continue
    pat,ctx=parts[0],parts[-1]
    try:
        if re.fullmatch(pat,path):
            # longest literal prefix = most specific
            score=len(re.match(r'[^\[\(\.\*\+\?]*',pat).group(0))
            if best is None or score>best[0]: best=(score,ctx)
    except re.error:
        continue
print(best[1] if best else fallback)
PY
}

##############################################################################
# ext4: modify in place with debugfs
##############################################################################
if [[ "$FS" == ext4 ]]; then
  command -v debugfs >/dev/null || die "ext4 needs debugfs (e2fsprogs)"

  # A GSI's system.img is usually rooted at the partition itself (/app, /bin),
  # but some are nested under /system.
  if debugfs -R "ls -l /system/etc" "$OUT" 2>/dev/null | grep -q .; then
    PREFIX="/system"; log "image is nested under /system"
  else
    PREFIX=""; log "image is rooted at the system partition"
  fi

  FC="$WORK/plat_file_contexts"
  if debugfs -R "dump ${PREFIX}/etc/selinux/plat_file_contexts $FC" "$OUT" 2>/dev/null && [[ -s "$FC" ]]; then
    log "read plat_file_contexts ($(wc -l < "$FC") rules)"
  else
    echo "warning: plat_file_contexts not found; using $DEFAULT_LABEL" >&2
    : > "$FC"
  fi

  # Grow the filesystem if there is not enough free space for the payload.
  need=0; for e in "${PAYLOAD[@]}"; do IFS=: read -r _ src _ <<<"$e"; need=$((need+$(stat -c%s "$src"))); done
  bs=$(dumpe2fs -h "$OUT" 2>/dev/null | awk -F: '/^Block size/{gsub(/ /,"",$2);print $2}')
  free=$(dumpe2fs -h "$OUT" 2>/dev/null | awk -F: '/^Free blocks/{gsub(/ /,"",$2);print $2}')
  freeb=$(( ${free:-0} * ${bs:-4096} ))
  log "payload $((need/1024)) KiB, free $((freeb/1024/1024)) MiB"
  if (( freeb < need + 8*1024*1024 )); then
    grow=$(( need + 32*1024*1024 ))
    log "growing image by $((grow/1024/1024)) MiB"
    truncate -s "+$grow" "$OUT"
    e2fsck -fy "$OUT" >/dev/null 2>&1 || true
    resize2fs "$OUT" >/dev/null 2>&1 || die "resize2fs failed"
  fi

  CMDS="$WORK/debugfs.cmds"; : > "$CMDS"
  for e in "${PAYLOAD[@]}"; do
    IFS=: read -r rel src mode <<<"$e"
    dst="${PREFIX}/${rel}"
    devpath="/system/${rel}"                      # path as SELinux sees it
    label="$(resolve_label "$devpath" "$FC")"
    dir="$(dirname "$dst")"
    # create parent directories that are missing
    acc=""; IFS='/' read -ra segs <<<"${dir#/}"
    for s in "${segs[@]}"; do
      acc="$acc/$s"
      debugfs -R "ls -l $acc" "$OUT" 2>/dev/null | grep -q . || echo "mkdir $acc" >> "$CMDS"
    done
    {
      echo "rm $dst"                              # ignored if absent
      echo "write $src $dst"
      echo "sif $dst mode $mode"
      echo "sif $dst uid 0"
      echo "sif $dst gid 0"
      echo "ea_set $dst security.selinux \"${label}\\000\""
    } >> "$CMDS"
    log "  $devpath  mode ${mode: -4}  $label"
  done

  debugfs -w -f "$CMDS" "$OUT" >"$WORK/debugfs.log" 2>&1 || true
  e2fsck -fy "$OUT" >"$WORK/fsck.log" 2>&1 || true
  if grep -q 'FILE SYSTEM WAS MODIFIED' "$WORK/fsck.log"; then
    # fsck repairing anything here means we wrote something malformed.
    echo "warning: e2fsck had to repair the image after injection" >&2
    grep -vE '^(e2fsck|Pass |/|$)' "$WORK/fsck.log" | head -5 >&2 || true
  fi

  # Verify: debugfs reports success even when a command failed, so check.
  for e in "${PAYLOAD[@]}"; do
    IFS=: read -r rel src mode <<<"$e"
    dst="${PREFIX}/${rel}"
    debugfs -R "stat $dst" "$OUT" 2>/dev/null | grep -q 'Type: regular' \
      || die "injection failed: $dst is missing or not a regular file
see $WORK/debugfs.log (rerun with --keep-tree to retain it)"
    debugfs -R "ea_list $dst" "$OUT" 2>/dev/null | grep -q security.selinux \
      || die "injection failed: $dst has no SELinux label"
  done
  log "verified: 3 files present, labelled, filesystem clean"

##############################################################################
# erofs: unpack, inject, repack
##############################################################################
else
  for t in fsck.erofs mkfs.erofs; do
    command -v "$t" >/dev/null || die "missing tool: $t (apt-get install erofs-utils)"
  done
  RAW="$WORK/raw.img"; mv "$OUT" "$RAW"
  TREE="${KEEP_TREE:-$WORK/tree}"; mkdir -p "$TREE"
  log "extracting to $TREE"
  fsck.erofs --extract="$TREE" --preserve --overwrite --force "$RAW" >/dev/null

  # PREFIX is the device path the packed tree root maps to, so an image that
  # already contains system/ is rooted at /, not at /system.
  if   [[ -d "$TREE/system/etc" ]]; then ROOT="$TREE/system"; PREFIX=/
  elif [[ -d "$TREE/etc" ]];        then ROOT="$TREE";        PREFIX=/system
  else die "cannot locate system root inside image"; fi
  log "system root: $ROOT (tree root maps to $PREFIX)"

  for e in "${PAYLOAD[@]}"; do
    IFS=: read -r rel src mode <<<"$e"
    install -d -m 0755 "$ROOT/$(dirname "$rel")"
    install -m "${mode: -4}" "$src" "$ROOT/$rel"
    log "  /system/$rel  mode ${mode: -4}"
  done

  FC="$ROOT/etc/selinux/plat_file_contexts"
  FC_ARG=()
  if [[ -f "$FC" ]]; then
    log "relabelling from plat_file_contexts"
    FC_ARG=(--file-contexts="$FC")
  else
    echo "warning: plat_file_contexts not found; SELinux labels not reapplied" >&2
  fi
  log "repacking"
  mkfs.erofs -zlz4hc "${FC_ARG[@]}" --mount-point="$PREFIX" \
             --force-uid=0 --force-gid=0 "$OUT" "$TREE" >/dev/null
fi

log "done: $OUT ($(du -h "$OUT" | cut -f1))"
cat <<EOF

If the first-boot hook does not take effect (an enforcing build may deny init
invoking settings), set it manually over adb — this always works:
  adb shell ime enable $IME_ID
  adb shell ime set    $IME_ID
EOF
