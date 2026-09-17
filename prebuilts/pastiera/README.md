# Pastiera (prebuilt)

An **unmodified** upstream build of Pastiera, archived here because the nightly
it came from will eventually be pruned from the project's F-Droid repo and this
repo pins a verified, reproducible image build to it.

| | |
|---|---|
| File | `pastiera-nightly-0.86-nightly.20260820.222455.apk` |
| SHA-256 | `be36f7c3e0a28df56b1a2d112c017d999d65790031d99b171e34d2a01d9643e2` |
| Size | 45,576,726 bytes |
| Version | `0.86-nightly.20260820.222455` |
| applicationId | `it.palsoftware.pastiera.nightly` |
| Obtained from | `https://pastiera.eu/fdroid/nightly/repo/` |

Verify before use:

```bash
sha256sum -c SHA256SUMS
```

## Licence — GPL-3.0

Pastiera is free software under the **GNU General Public License, version 3**.
Upstream: <https://github.com/palsoftware/pastiera>

This repository is public, so committing this binary **conveys** it under GPLv3
§6, which obliges the distributor to make the Corresponding Source available.

| | |
|---|---|
| Source repository | `https://github.com/hayliewordsman/pastiera` (mirror under our control) |
| Upstream | `https://github.com/palsoftware/pastiera` |
| Commit | `138b67161e6a8c14c6723088cc933e97d4d021f0` |
| Upstream tag | `nightly/v0.86-nightly.20260820.222455` |

```bash
git clone https://github.com/hayliewordsman/pastiera
git -C pastiera checkout 138b67161e6a8c14c6723088cc933e97d4d021f0
```

Verified: the commit is present in the mirror and is an ancestor of its `main`,
so it is reachable and the source is preserved independently of upstream.

**Read [`../../docs/DISTRIBUTION-COMPLIANCE.md`](../../docs/DISTRIBUTION-COMPLIANCE.md)** for the
full obligation, including the Installation Information a User Product requires.

### Source-pointer durability — done, with one soft spot

The mirror exists and carries the commit, so §6(d) no longer depends on upstream.

One caveat: GitHub's fork dialog ticks **"Copy the default branch only"** by
default, so the mirror carries `main` and **no tags** (upstream has 44). The
commit survives only because it is an ancestor of `main`. That is sufficient, but
it would be lost if `main` were ever rewritten or force-pushed.

Optional hardening, entirely through the GitHub web UI:

1. Open the mirror -> **Releases** -> **Draft a new release**
2. **Choose a tag** -> type `nightly/v0.86-nightly.20260820.222455` -> *Create new tag on publish*
3. Set **Target** to the commit `138b67161e6a8c14c6723088cc933e97d4d021f0`
4. Publish

That pins the commit permanently, independently of the branch.

### Note

The APK is byte-identical to upstream and carries upstream's signature. It has
**not** been rebuilt, repacked or resigned. The version string matches the tag,
but this is not a verified reproducible build, so it is not proof the binary was
compiled from that commit — see the provenance caveat in the compliance document.

Pastiera's own `THIRD_PARTY_NOTICES.md` (AOSP LatinIME under Apache-2.0, CC0
sound samples, Unicode CLDR data) should accompany any redistribution.
