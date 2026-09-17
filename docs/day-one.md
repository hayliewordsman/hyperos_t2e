# Day one, when the device arrives

Read this before connecting anything. It exists because the session that produced
this repo is long gone by the time the hardware shows up.

## The one irreversible mistake

**There is no publicly available Titan 2 Elite firmware.** This was searched
thoroughly — see the firmware section in `gsi-port.md`. Unihertz ships updates
over the air only, the community archives cover the *standard* Titan 2 (a
different SoC), and the one site claiming to host Elite firmware has no file
behind it.

So: **if you overwrite the stock partitions without a backup, there may be no way
back.** No download to re-flash, no stock image to restore. On a device this new,
with no TWRP, no LineageOS tree and no community dumps, a bad flash could leave
you with an expensive brick and no recovery path.

Everything below follows from that.

## Order of operations

1. **Use the phone as a phone for a week.** Confirm it works: camera, fingerprint,
   VoLTE, mobile data, HD streaming. You need to know what *working* looks like
   before you change anything, or you will not be able to tell what you broke.

2. **Run the collector, unmodified, on the stock ROM.**
   ```bash
   tools/collect-device-info.sh
   ```
   Needs `adb` on your computer and USB debugging on the phone; no root required
   for most of it. This is untested against hardware — send the output *including
   any errors* and it can be fixed. This snapshot is the donor for all later
   camera / fingerprint / VoLTE / Widevine work, and cannot be recreated once the
   device is modified.

3. **Take a full partition backup**, ideally before unlocking the bootloader,
   since unlocking wipes user data. On MediaTek, `mtkclient` can dump flash
   without root. Store it somewhere you will still have in a year. This is the
   only stock image that will exist.

4. **Install Pastiera as a normal app on the stock ROM.** Fetch it from
   `https://pastiera.eu/`, install, enable in keyboard settings. No unlock, no
   flashing, no risk.

   Then stop and evaluate. If this gives you the symbols, keypad scrolling and
   emoji you wanted, the GSI project is optional — and everything below costs you
   camera, fingerprint, VoLTE and Widevine L1 to gain a different launcher.

5. **Only then** consider the GSI, having read the base-choice discussion in
   `gsi-port.md`.

## Things that will have gone stale

- **The Pastiera build.** The image was built with
  `0.86-nightly.20260820.222455`. Nightlies get pruned from the F-Droid repo, so
  that exact APK may no longer be fetchable. Use whatever is current, and read
  its component out of the APK rather than assuming:
  ```bash
  python3 tools/axml.py <new>.apk
  ```
  The nightly's applicationId and its IME class live in *different* namespaces —
  guessing gets you a keyboard that silently never activates.

- **The GSI.** Fetch a current iodéOS GSI from
  `https://gitlab.iode.tech/ota/release/-/tree/master/gsi`. The tool does not
  care which GSI you use, only that it is arm64 and matches your A/B layout.

- **Both URLs**, which may have moved. The reproduction recipe in `gsi-port.md`
  has the exact paths that worked.

## What was never verified

Everything in this repo was validated against images, not hardware. Specifically
unverified: that the chosen GSI boots at all on Dimensity 7400 vendor, that the
first-boot IME hook survives SELinux enforcement, and that Pastiera behaves
correctly on Titan 2 **Elite** keys — its device assets name the Titan 2, and
0.85's notes mention "Titan 2 Elite QWERTY", but nobody has run it on one.

Treat the first boot as an experiment, not a deployment.
