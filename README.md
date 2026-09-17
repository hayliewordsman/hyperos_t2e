# hyperos_t2e

Investigating HyperOS on the **Unihertz Titan 2 Elite**, with [Pastiera](https://pastiera.eu)
for physical-keyboard typing.

## Current status

Read **[docs/feasibility.md](docs/feasibility.md)** first. Short version:

- **Porting the Xiaomi 17 HyperOS ROM to this device is not achievable.** The Xiaomi 17
  is Qualcomm (Snapdragon 8 Elite Gen 5, Adreno); the Titan 2 Elite is MediaTek
  (Dimensity 7400, Mali). Kernel, GPU stack, modem, HALs, and boot chain are all
  SoC-specific, so this is a platform bring-up rather than a port.
- **A GSI is the only route that can work** — the HyperOS system layer over Unihertz's
  own vendor and kernel. Camera, fingerprint, VoLTE and Widevine L1 are the expected
  casualties.
- **Pastiera is an IME app, not a compatibility layer.** It installs as an APK and
  needs no ROM work. It already treats the Titan 2 as a reference device.

## Blockers

| Blocker | Needed to unblock |
|---|---|
| `miuirom.org` and `pastiera.eu` refused by egress policy (403) | Add both to the environment's network allowlist |
| Titan 2 Elite bootloader unlock is unverified | Confirm the procedure with Unihertz — nothing else matters until this is known |

## If the goal is better typing

Install Pastiera on the stock ROM. It delivers the physical-keyboard improvements on
its own, with no unlock, no warranty risk, and no broken camera.
