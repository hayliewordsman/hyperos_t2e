#!/usr/bin/env python3
"""Compile the Facet shaders offline with Skia's SkSL compiler.

AGSL is Android's binding of Skia runtime effects, so Skia will reject most of
what Android would reject -- without an SDK, an emulator or a device.

    pip install skia-python          # needs libegl1 libgl1 on Linux
    python3 tools/shader-check/validate-sksl.py

Caveat: SkSL and AGSL are close but not identical, and the Skia version here is
not the one in any given Android build. A pass is strong evidence, not proof.
Run the on-device harness in this directory to confirm.
"""
import pathlib
import re
import sys

PATCHES = {
    "FacetEdgeShader": "0001-facet-specular-edge.patch",
    "FacetRimShader": "0002-facet-rim-darkening.patch",
}


def agsl_from_patch(path):
    """Extract UNIFORMS + MAIN from the added lines of a patch."""
    added = "\n".join(
        l[1:] for l in path.read_text().splitlines()
        if l.startswith("+") and not l.startswith("+++")
    )
    parts = []
    for block in ("UNIFORMS", "MAIN"):
        m = re.search(block + r'\s*=\s*"""(.*?)"""', added, re.S)
        if not m:
            return None
        parts.append(m.group(1))
    return "".join(parts)


def compile_sksl(src):
    import skia
    for fn in ("MakeForShader", "Make"):
        f = getattr(skia.RuntimeEffect, fn, None)
        if not f:
            continue
        try:
            r = f(src)
        except Exception as e:
            return f"{type(e).__name__}: {e}"
        if isinstance(r, tuple):
            eff, err = (r + (None,))[:2]
            return err or None if not eff else None
        return None
    return "no usable RuntimeEffect entry point in skia-python"


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    failed = 0
    for name, pf in PATCHES.items():
        src = agsl_from_patch(root / "patches" / "systemui" / pf)
        if src is None:
            print(f"  {name}: could not extract AGSL from {pf}")
            failed += 1
            continue
        err = compile_sksl(src)
        if err:
            print(f"  {name}: FAILED")
            for line in str(err).strip().splitlines():
                print(f"    {line}")
            failed += 1
        else:
            print(f"  {name}: compiles")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
