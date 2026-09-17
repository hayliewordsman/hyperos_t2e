#!/usr/bin/env bash
# Confirm the AGSL in this harness still matches the AGSL in the patches.
# If they drift, the harness validates something you are not shipping.
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 - <<'PY'
import re, pathlib, sys

def agsl_from(text):
    """Pull the UNIFORMS+MAIN pair out of a Kotlin RuntimeShader subclass."""
    u = re.search(r'(?:UNIFORMS|EDGE_SHADER|RIM_SHADER)[^"]*"""(.*?)"""', text, re.S)
    return u

def blocks(text):
    out = []
    for name in ('UNIFORMS', 'MAIN'):
        for m in re.finditer(name + r'\s*=\s*"""(.*?)"""', text, re.S):
            out.append(m.group(1))
    return out

def norm(s):
    return re.sub(r'\s+', ' ', s).strip()

patch_src = {}
for key, pf in (("edge", "0001-facet-specular-edge.patch"),
                ("rim",  "0002-facet-rim-darkening.patch")):
    t = pathlib.Path("patches/systemui")/pf
    added = "\n".join(l[1:] for l in t.read_text().splitlines()
                      if l.startswith('+') and not l.startswith('+++'))
    patch_src[key] = norm("".join(blocks(added)))

h = pathlib.Path("tools/shader-check/app/src/main/java/dev/titan2e/shadercheck/MainActivity.kt").read_text()
harness = {}
for key, const in (("edge", "EDGE_SHADER"), ("rim", "RIM_SHADER")):
    m = re.search(const + r'\s*=\s*"""(.*?)"""', h, re.S)
    harness[key] = norm(m.group(1)) if m else None

bad = 0
for k in ("edge", "rim"):
    ok = patch_src[k] and harness[k] and patch_src[k] == harness[k]
    print(f"  {k:5} {'in sync' if ok else 'DRIFTED'}")
    if not ok:
        bad += 1
sys.exit(1 if bad else 0)
PY
