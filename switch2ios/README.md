# Switch2iOS — native iPhone porting research

First target: Super Mario Odyssey (Title ID 0100000000010000). The app is **not playable yet**. Candela and Mush8's Mario Kart implementation remain unchanged.

## Current code

- Native SwiftUI Switch2iOS dashboard with local NSP/PFS0 directory inspection and JSON sharing (no game payload).
- Game profiles under switch2ios/profiles/ for Odyssey and the Mush8 Mario Kart reference game.
- New platform-neutral Python preflight: switch2ios/tools/native_preflight.py; scans private extracted ExeFS/NSO headers and emits metadata without game assets or keys.
- Optional offline instruction-rewrite probe using Mush8 nxpatch, with the rewritten binaries stored locally only.
- Repaired Windows PowerShell wrapper (previous version was malformed).
- GitHub Actions runs synthetic preflight unit tests and creates an unsigned developer-preview IPA of the SwiftUI dashboard. This is **not an Odyssey runtime IPA**.

## Where to put your game files

Do **not** put ROMs, extracted executable files, prod.keys or firmware in GitHub. Even private repos and CI artifacts can expose them. A private Google Drive location can be used for your own backup but do not link any keys or game code into a public GitHub build. Keep game files on your own device or in a private machine you control.

The current iPhone app only scans the non-encrypted NSP file table. Running a native Odyssey executable requires offline extraction and rewriting and game-specific compatibility work. The ROM being present on the iPhone does **not** mean the app can link arbitrary Switch code on-device.

## When a computer or suitable private build machine is available

Install Rust, Python 3 and PowerShell 7. From the repository root with your own dumped NSP and keys:

    pwsh -File .\switch2ios\tools\inspect-odyssey.ps1 -Base "C:\Games\odyssey.nsp" -Keys "C:\Private\prod.keys"

Optionally add an update NSP with -Update. Add -Rewrite to attempt local ARM64 rewriting via nxpatch, **not to build a working game**. All extracted and patched code remains beneath switch2ios/local-work/odyssey, which is ignored by Git.

If you already have a privately extracted ExeFS directory, you can run the Python scan without keys or Rust:

    python switch2ios/tools/native_preflight.py --exefs /private/path/ExeFS --report /private/path/native-preflight.json

**Only share the resulting JSON after reviewing it.** No game code, paths or keys are in that report.

Run the synthetic tests locally with:

    python -m unittest discover -s switch2ios/tests -p 'test_*.py' -v

## Native port blockers still to solve

1. Determine Odyssey's real NSO build IDs and module layout, and run a first offline rewrite against those modules.
2. Adapt Mush8's fixed module linker and loader to game profiles without altering Mario Kart defaults.
3. Handle Odyssey's NVN SDK version, additional Horizon services, graphics/shader translation, resources and memory map.
4. Attempt a Mac native-guest boot with diagnostic logs, then a separate signed iOS runtime build.
5. Validate Odyssey on actual target iPhone hardware before making performance claims.

No Nintendo game content or console keys are distributed with the project.
