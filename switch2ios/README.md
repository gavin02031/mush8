# Switch2iOS — experimental native iOS porting research

First target: **Super Mario Odyssey**. Independent experimental app inside the Mush8 fork. **Candela is untouched.**

## iPhone preview (v2)

- SwiftUI iOS native dashboard with **local NSP/PFS0 file table inspection**: entry counts, NCA count and bytes, ticket/certificate presence, and title ID when available from the ticket filename.
- When the title ID family matches Odyssey, identifies the title, and categorizes base/update/add-on using the content suffix.
- Generates a small **shareable JSON compatibility research report**. It does not include the game file, keys, internal asset data, or file paths.
- Uses bounded reads of just the first ~8 MiB of container directory metadata, never the full game payload.
- Game version, NCA decryption, internal SDK, gameplay, and port feasibility **are not determined by this report**.
- No playable native Odyssey port exists here. The preview IPA has no game code.

## Build iPhone preview IPA

On GitHub Actions, run **Switch2iOS unsigned iOS preview** or download the latest successful artifact from your branch. Its ZIP contains `Switch2iOS-preview-UNSIGNED.ipa`, which needs signing before personal installation. A hosted macOS runner supplies Xcode; **no PC or Mac is required to use the already-built app on the phone**.

For macOS builds with Xcode and XcodeGen:

```sh
cd switch2ios/ios
xcodegen generate
xcodebuild -project Switch2iOS.xcodeproj -scheme Switch2iOS -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Windows offline executable research (later)

Install Rust and PowerShell 7. From the repository root:

```powershell
pwsh -File .\switch2ios\tools\inspect-odyssey.ps1 -Base "C:\Games\own-base.nsp" -Keys "C:\Keys\prod.keys" -Update "C:\Games\own-update.nsp"
```

Omit `-Update` if none. This locally extracts ExeFS/control info and creates `exefs-manifest.json` including NSO module IDs and hashes. **Never upload game data or keys to public GitHub.** This script has not yet been verified against your dump.

## Native Odyssey port milestones

1. Confirm Odyssey's actual internal build/version, executable modules, and SDK ID, beyond simple NSP container metadata.
2. Generalize Mush8's fixed `["main", "subsdk0", "sdk"]` module linker, loader and iOS build.
3. Replace MK8-specific title IDs, update filenames, and shader pipeline inventory with per-game profiles.
4. Identify additional Horizon services and NVN entry points Odyssey needs. Implement compatibility instead of silently assuming stub behavior works.
5. Run a native macOS smoke test before attempting an Odyssey-specific iOS build.
6. Profile device memory, thermals, performance and native touch controls.

The existing Mush8 implementation and its copyright/license notices remain intact. Source scaffolding and unsigned builds are not proof of a working Odyssey port.
