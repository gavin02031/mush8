# Switch2iOS — experimental native iOS porting research

First target: **Super Mario Odyssey**. Built as an independent experiment inside the Mush8 fork. **Candela is untouched.**

## Current status

- Native SwiftUI iOS dashboard, file header inspector, and self-contained XcodeGen project.
- GitHub Actions job to build an **unsigned preview IPA** of that dashboard on a macOS runner.
- Windows PowerShell script to inspect **locally held, user-supplied** game dumps using Mush8's `nxfs`.
- **No playable Odyssey port exists in this branch.** The preview IPA includes no Nintendo game code, keys, ROM data, or executable patches.
- The native app cannot convert arbitrary Switch games to iOS entirely on-device: Apple executable signing/linking happens outside the app.

## Building the dashboard

To build the native app using GitHub Actions, open Actions → **Switch2iOS unsigned iOS preview**, then download the `Switch2iOS-preview-UNSIGNED` artifact from a successful run. The IPA must be signed through a compatible personal sideloading process before it can run on a phone.

For local macOS builds with Xcode and XcodeGen:

```sh
cd switch2ios/ios
xcodegen generate
xcodebuild -project Switch2iOS.xcodeproj -scheme Switch2iOS -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

This preview is a developer dashboard, **not** a game installer, emulator, or working Odyssey IPA.

## Inspect your own Odyssey NSP dump on Windows

Install Rust and PowerShell 7. From the repository root:

```powershell
pwsh -File .\switch2ios\tools\inspect-odyssey.ps1 -Base "C:\Games\own-base.nsp" -Keys "C:\Keys\prod.keys" -Update "C:\Games\own-update.nsp"
```

Omit `-Update` if there is no update. This builds `nxfs`, prints container metadata, and extracts ExeFS/control files to `switch2ios/local-work/odyssey` for **local** analysis only. The tool creates a SHA256 module manifest. Never check these dumps or keys into GitHub, attach them to issues, or upload them to public build systems. It has not yet been validated against your personal dump.

## Next native execution milestones

1. Confirm Odyssey game version, ExeFS module list and SDK/module IDs.
2. Generalize Mush8's fixed `["main", "subsdk0", "sdk"]` module layout in `nxhost/build.rs`, loader and iOS build.
3. Replace hardcoded Mario Kart title IDs, update filenames, and shader pipeline inventory with per-game profiles.
4. Identify new Horizon services and NVN entry points needed by Odyssey. Expand service implementations and shader translation, rather than silently relying on stubs.
5. Run instrumented macOS native-guest smoke tests, then attempt an **Odyssey-specific** iOS executable build with locally supplied game files under compliant private conditions.
6. Profile memory, thermal behavior, and input on real iPhone hardware. Avoid promising 60 fps.

The existing Mush8 game implementation and its licensing/copyright notices remain intact. Changes are research scaffolding until game-specific compatibility is demonstrated.
