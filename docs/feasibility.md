# Porting HyperOS 3.0 (Xiaomi 17) to the Unihertz Titan 2 Elite — Feasibility Assessment

Status: **blocked, and infeasible as originally specified**
Date: 2026-09-17

## Summary

The request was: download HyperOS `3.0.335.0.XPCMIXM` (Xiaomi 17, Recovery ROM),
reverse engineer it, port it to the Unihertz Titan 2 Elite, and use Pastiera as a
physical-keyboard compatibility layer.

Three findings, in order of how much they change the plan:

1. A literal port is not achievable. The two devices use different SoC vendors.
   This is a platform bring-up, not a port.
2. Pastiera is not a compatibility layer. It is an ordinary Android IME app,
   installed as an APK. It does not need to be built into a ROM at all.
3. Neither source could be downloaded from this environment. Both hosts are
   blocked by the egress policy.

## 1. Why the port cannot work as specified

| | Xiaomi 17 (source) | Titan 2 Elite (target) |
|---|---|---|
| SoC | Snapdragon 8 Elite Gen 5 (Qualcomm, 3nm) | Dimensity 7400 (MediaTek, 4nm) |
| GPU | Adreno | ARM Mali-G615 MC2 |
| Boot chain | XBL / ABL | Preloader / LK |
| Modem | Qualcomm | MediaTek |

(The Titan 2 Elite **Pro** is Dimensity 8400 / Mali-G720 MC7 — same conclusion.)

A stock OEM ROM is not portable across this boundary, because almost everything
below the framework is compiled against the specific SoC:

- **Kernel.** The Xiaomi 17 `boot` image is built from Qualcomm's downstream tree
  with Qualcomm drivers. It cannot boot MediaTek silicon. There is no shim for this.
- **GPU.** Adreno userspace blobs have no meaning on a Mali GPU. The driver is a
  kernel module plus a matched userspace blob; they are not interchangeable.
- **The whole `vendor` partition.** Camera HAL targets Qualcomm's Spectra ISP;
  RIL targets a Qualcomm modem; audio, sensors, thermal, power, and fingerprint
  HALs are all SoC-specific.
- **Partition layout and bootloader.** Qualcomm uses `xbl`, `abl`, `tz`, `hyp`,
  `modem`; MediaTek uses `preloader`, `lk`, `md1img`. Different fastboot
  implementations, different flashing flow.

Reproducing that would mean writing a MediaTek BSP for HyperOS without Unihertz's
kernel sources or MediaTek's vendor blobs. That is not a task that ends in success.

## 2. The path that can actually work: a GSI

Project Treble splits `system` from `vendor`. That gives one realistic route:

> Run a HyperOS-derived **Generic System Image** on top of the Titan 2 Elite's
> **own** vendor partition and kernel.

The Titan 2 Elite is recent MediaTek hardware and should be Treble-compliant, so
it should accept a GSI. You keep Unihertz's `vendor` and `boot` — which is exactly
what makes the hardware work — and replace only `system` / `system_ext` / `product`.

What this gets you: the HyperOS framework, SystemUI, launcher, settings, and theming.

What it realistically costs — these break on essentially every HyperOS GSI, because
Xiaomi's framework is tightly coupled to Xiaomi's own vendor:

- Camera (Xiaomi's camera stack expects the Qualcomm HAL)
- Fingerprint
- VoLTE / VoWiFi
- Widevine L1 → likely drops to L3 (no HD streaming)

Prerequisites, in order:
1. An unlockable bootloader on the Titan 2 Elite. **Unverified** — this is new
   hardware (announced MWC 2026) and Unihertz's unlock policy for it needs checking
   before anything else. If the bootloader is locked, the project stops here.
2. A full stock firmware backup of the device.
3. A HyperOS GSI, either community-built or derived from a Xiaomi 17 dump.

Note the honest framing: this is not "HyperOS on the Titan 2 Elite." It is the
HyperOS *system layer* on Unihertz hardware, with known gaps.

## 3. Pastiera — corrected understanding

Pastiera (pastiera.eu, source at `github.com/palsoftware/pastiera`) is **an Android
input method (IME)** for phones with physical keyboards. From its own docs:

- Requires Android 10+ and a physical keyboard
- Installed as a normal APK (stable channel, or a nightly F-Droid repo)
- Ships device-specific assets for **Titan 2**, Q25, and BlackBerry Key2 —
  Titan 2 has been its main reference device
- Provides long-press mappings, modifier control, Nav Mode, SYM pages,
  clipboard history, suggestions, and layout configuration

So it is not a compat layer and not a ROM component. That is good news: it deletes a
whole workstream. You install it after flashing.

It does, however, land on a real problem. Unihertz implements part of its keyboard
behavior in its own system-side customizations, so flashing a GSI over `system`
throws that away and the keyboard degrades. Pastiera reimplements that behavior in
userspace, which is why it is the right tool here.

One favorable detail: low-level scancode→keycode mapping usually lives in
`/vendor/usr/keylayout/` and `/vendor/usr/idc/`. A system-only GSI flash leaves
`vendor` intact, so the raw key mapping should survive; Pastiera then supplies the
higher-level typing behavior. This needs confirming against a real device dump —
if any keylayout lives in `/system/usr/keylayout/`, it must be carried into the GSI.

## 4. Environment blocker

Neither source is reachable from this session; both were refused by the egress
proxy (HTTP 403 on CONNECT):

- `miuirom.org` — the ROM itself
- `pastiera.eu` — the Pastiera site and APK

Per the proxy documentation, policy denials are reported rather than worked around.
To proceed here, add both hosts to the environment's network egress allowlist.
`github.com` is reachable, which is how Pastiera's documentation was read.

Note also that a Recovery ROM for a current flagship is several GB, against roughly
30 GB of writable disk in this session — workable, but not by a wide margin.

## 5. Recommended next steps

1. **Confirm the bootloader can be unlocked.** Everything else is moot otherwise.
   Ask Unihertz directly for the Titan 2 Elite unlock procedure.
2. **Get a stock firmware backup** before flashing anything.
3. **Install Pastiera on the stock ROM first.** It is independent of the ROM work,
   it is the feature actually wanted, and it carries near-zero risk.
4. **Then, if still wanted, evaluate an existing HyperOS GSI** rather than building
   one from the Xiaomi 17 dump. Treat camera and fingerprint as likely losses.

Step 3 is worth separating out: if the goal is a better typing experience on the
Titan 2 Elite, Pastiera alone delivers it, with no bootloader unlock, no warranty
risk, and no broken camera.
