Symbian packaging and device verification
========================================

Prerequisites
- Symbian Qt SDK installed (Qt 4.7.x toolchain). Default path assumed by scripts: C:\Symbian\QtSDK
- Symbian SDK root (examples): C:\Symbian\QtSDK\Symbian\SDKs\SymbianSR1Qt474 or your Belle SDK path
- Device: Nokia C7 on Symbian Belle FP2 (Qt runtime installed on device)

Build (device)
1. Build the binaries:
   pwsh scripts/build-symbian.ps1 -Config Release -Arch armv6
2. Output is staged into build-symbian\armv6-release.

Package (.sis)
1. Verify Podin_template.pkg has the package UID and version you want.
   - The default UID is in the self-signed test range (0xExxxxxxx).
2. Create the SIS:
   pwsh scripts/package-symbian.ps1 -Config Release -Arch armv6
3. Output:
   - build-symbian\armv6-release\Podin_selfsigned.sis
   - build-symbian\armv6-release\Podin_local.pkg (generated)

Install on device
- Copy the .sis to the phone (USB mass storage or Nokia Suite) and install it.
- On device, allow installing from unknown sources (Application manager settings) and disable online cert check if prompted.

Troubleshooting notes
- If Podin.rsc or Podin_reg.rsc is missing, rebuild and confirm the Symbian SDK path is correct.
- If network requests fail with a capability error, add NetworkServices to the Symbian capabilities in Podin.pro and rebuild.
- If the app fails to launch due to missing Qt libraries, install the Qt runtime for Symbian Belle.

Manual test checklist (Milestone 7)
- Search by term returns results.
- Open podcast detail screen and load episodes.
- Play an episode; audio output is audible.
- Pause and resume playback.
- Seek within an episode and confirm position updates.
- Switch between list/detail/player screens while playing.
- Offline: open subscriptions with networking disabled (cached list visible).
- Error states: no network, invalid Podcast Index key (error shown, app stays responsive).
