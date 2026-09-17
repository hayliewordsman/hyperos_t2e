# Facet shader check

A ~20 MB Android app that compiles the Facet AGSL shaders and draws them, so
the riskiest untested part of this project can be validated **without a 300 GB
Android source tree**.

## Why this exists

`RuntimeShader` compiles its source in the constructor and throws on a syntax or
type error. So merely constructing both shaders proves the AGSL is valid — which
is otherwise only discovered part-way through a full ROM build.

The shaders' *math* was verified by rendering it (`docs/preview/`). Their syntax
now passes Skia's SkSL compiler offline, which covers most of the risk; this app
confirms it against Android's own AGSL implementation.

## Two levels of check

**Offline, no SDK or device** — Skia's SkSL compiler will reject most of what
Android would:

```bash
pip install skia-python        # needs libegl1 libgl1 on Linux
python3 tools/shader-check/validate-sksl.py
```

Both shaders **currently pass** this. SkSL and AGSL are close but not identical,
and the Skia build here is not the one in any given Android release, so treat a
pass as strong evidence rather than proof.

**On device** — the app below, which runs the real Android AGSL compiler. This
is the one that settles it.

## Running it

1. Open this directory in Android Studio.
2. Run on any **Android 13+** device or emulator (AGSL needs API 33).

The screen reports `COMPILED` or `FAILED` for each shader, with the compiler's
error message if it failed, then draws them: the edge highlight over a striped
backdrop on top, the rim darkening sampling that backdrop below.

Stripes are deliberate — they make the rim effect obvious, where a smooth
backdrop would hide it.

## Keeping it honest

The AGSL here is copied verbatim from `patches/systemui/`. If the patches change
and this does not, the harness validates something you are not shipping:

```bash
tools/shader-check/verify-sync.sh
```

## What it does not tell you

- whether the patches **compile against SystemUI** (Java/Kotlin interop, imports)
- whether `RenderEffect.createChainEffect` composes as intended
- whether blur is available at all, which is a device property

Those still need a real build. This only removes AGSL syntax from the list of
unknowns — but that was the item most likely to fail first.
