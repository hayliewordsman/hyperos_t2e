# BFU forensic resistance of the /e/OS GSI on a Titan 2 Elite

Last updated: 2026-09-17

**Before First Unlock** (BFU) is the state after a reboot where the device has
never been unlocked. File-Based Encryption keys for Credential Encrypted storage
are not yet in memory, so user data is encrypted at rest. It is by far the
strongest state a seized device can be in, and it is the state worth designing
for.

The short answer: **the encryption itself is sound, and almost everything
around it is weak.** BFU security here reduces to passphrase strength, with no
hardware backstop worth relying on.

## Measured on the actual image

These are read from `v4.3-a16-20260821-microG-gsi.img`, not inferred:

| Property | Value | Meaning |
|---|---|---|
| `ro.debuggable` | `1` | `adb root` available |
| **`ro.adb.secure`** | **`0`** | **ADB authentication disabled** |
| `persist.sys.usb.config` | `adb` | ADB enabled at boot |
| `ro.build.type` | `userdebug` | development build |
| `ro.build.tags` | `release-keys` | misleading — built by `eng.root` |

`ro.adb.secure=0` is the one that matters most. Normally a host must be
authorised by an on-device RSA prompt before ADB works. With this set to `0`,
that prompt is bypassed: **any USB host can open an ADB session**, and with
`ro.debuggable=1` that session can escalate to root.

This is a development posture, not a production one. It is not a bug in /e/OS —
GSIs are built this way so they can be debugged on arbitrary hardware — but it
is the opposite of what you want on a device you might lose.

Exactly how much of this is reachable *before* first unlock depends on when
`adbd` starts and what init does with it, which needs checking on the real
device. Treat it as a serious exposure until measured.

## Structural weaknesses you cannot fix

**The bootloader cannot be re-locked.** A GSI cannot be signed with a key the
Titan 2 Elite's bootloader trusts, so Verified Boot stays off permanently.
Anyone with physical access can flash a modified boot image. This is inherent to
the GSI route, not a configuration mistake.

**No secure element.** Pixels have a Titan M2 that enforces PIN attempt
rate-limiting in dedicated hardware. MediaTek relies on TEE-backed Gatekeeper,
which is meaningfully weaker. The practical effect is that brute-force
resistance rests on your passphrase rather than on hardware refusing to try.

**MediaTek BootROM and Download Agent are an active target.** The exploit market
here is live rather than historical: after MediaTek patched the "Carbonara"
vulnerability, a heap overflow in the DA2 USB download handler was found in 2025
that reaches code execution on patched V6 devices, with commercial tools
advertising support for recent Dimensity parts. Modern SoCs do require an
OEM-signed Download Agent, which raises the bar considerably. Whether the
Dimensity 7400 is currently affected is **unknown and worth treating as an open
question**, not a settled one.

## What actually still protects you

File-Based Encryption. In BFU the CE keys are not in memory and are derived from
your credential combined with a hardware-bound key. None of the weaknesses above
decrypt data on their own.

**So the passphrase is the lock.** With no secure element enforcing hardware
rate limits, a 4- or 6-digit PIN is not adequate against a well-resourced
attacker. A long alphanumeric passphrase is the single highest-value thing you
control here, and it matters more than every other item on this page combined.

## Hardening you can apply

Two properties close the worst of the above, and the injection tool writes them
into the image:

| Property | Ships as | Set to | Effect |
|---|---|---|---|
| `ro.adb.secure` | `0` | `1` | ADB requires the on-device authorisation prompt again |
| `ro.debuggable` | `1` | `0` | removes `adb root` |

The full command lives in **[building.md](building.md#producing-the-flashable-image)**
so there is only one copy to keep correct.

**Caveats.** The build is still `userdebug` underneath — `ro.build.type` is
unchanged, and components that check it directly rather than reading
`ro.debuggable` will still behave as a development build. This narrows the
exposure; it does not convert the image into a user build. It has not been
tested on hardware, so verify with `getprop` after flashing and confirm ADB
actually prompts before trusting it.

Deliberately left alone: `persist.sys.usb.config=adb`. Setting it to `none`
would disable ADB at boot entirely, but that removes the recovery path if the
first-boot IME hook fails, since `adb shell ime set` is the documented fallback.
Worth doing once the device is set up and known-good.

Also worth doing:

- **Power off rather than lock** when the device is at risk. BFU is dramatically
  stronger than After First Unlock, and powering down is what puts you there.
- **Disable ADB** in developer settings once set up.
- Note there is **no auto-reboot-to-BFU timer** here. GrapheneOS ships one;
  this does not.

## Honest comparison

Leaked Cellebrite support matrices from 2024, February 2025 and October 2025
show GrapheneOS on Pixel resisting extraction even in the *unlocked* AFU state,
while stock Pixel Android yields data in both BFU and AFU. Forensic vendors are
responding directly to it — Cellebrite's 2026 release advertises a "Safeguard
Mode" intended to stop seized devices returning to BFU.

/e/OS does not appear in those matrices at all, so there is no published data
either way. Absence of evidence is not evidence of resistance.

**If BFU forensic resistance is the actual goal, this device cannot deliver it.**
GrapheneOS achieves what it does through verified boot with user-held keys, a
secure element, and hardened platform internals — none of which survive the GSI
route on non-Pixel hardware. That is not a reason to abandon this project; it is
a reason to be clear that its goal is *de-Googling and privacy from
data collection*, which it does well, and not *resistance to physical forensic
attack*, which it does not.
