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
| Source repository | `https://github.com/palsoftware/pastiera` |
| Tag | `nightly/v0.86-nightly.20260820.222455` |
| Commit | `138b67161e6a8c14c6723088cc933e97d4d021f0` |

```bash
git clone https://github.com/palsoftware/pastiera
git -C pastiera checkout 138b67161e6a8c14c6723088cc933e97d4d021f0
```

**Read [`../../docs/DISTRIBUTION-COMPLIANCE.md`](../../docs/DISTRIBUTION-COMPLIANCE.md)** for the
full obligation, including the Installation Information a User Product requires.

### Make the source pointer durable

Pointing at upstream satisfies §6(d) only while the source stays available there.
The cheapest durable fix is to **fork `palsoftware/pastiera` on GitHub** — a fork
is a permanent mirror under your own account, costs nothing, and keeps the commit
above reachable even if upstream moves or disappears. Then update the source
repository row here to point at your fork.

### Note

The APK is byte-identical to upstream and carries upstream's signature. It has
**not** been rebuilt, repacked or resigned. The version string matches the tag,
but this is not a verified reproducible build, so it is not proof the binary was
compiled from that commit — see the provenance caveat in the compliance document.

Pastiera's own `THIRD_PARTY_NOTICES.md` (AOSP LatinIME under Apache-2.0, CC0
sound samples, Unicode CLDR data) should accompany any redistribution.
