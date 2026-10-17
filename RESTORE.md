# Restore: fidget-ball

- What: native macOS menu-bar app (Swift 6, AppKit/SwiftUI, SwiftPM). A ball hangs from the top of the screen. Public repo `UncleLYHME/fidget-ball`.
- Where it runs: nowhere as a service. It is a desktop app built from source on a Mac; no installed copy or clone was found on the Mini. Not deployed, no URL.
- Depends on: macOS 14+, Swift 6 toolchain (Xcode 16+ or matching Command Line Tools).
- Backups:
  - Code: GitHub only. Git mirror on BufferDaddy `/volume1/backups/git-mirrors` starts 2026-10-16 (tonight). The Mini's nightly `/volume1/backups/<date>/mini/projects.tar.gz` covers only `~/Projects`, which does not include this GitHub-only clone.
  - Config/env: none in the repo. Per-user app settings are stored by the app on the Mac that runs it (not backed up; they are only preferences).
  - Signing (optional): a Developer ID Application certificate and a `notarytool` keychain profile live in the Mac's keychain, not in git. Default build is ad-hoc signed and needs neither.
  - Data: none.

## Restore steps

```sh
gh repo clone UncleLYHME/fidget-ball ~/Projects/fidget-ball   # use another path if you do not want it under ~/Projects
cd ~/Projects/fidget-ball
swift build -c release --product FidgetBall
Scripts/package_app.sh          # writes dist/FidgetBall.app and dist/FidgetBall.zip (ad-hoc signed)
open dist/FidgetBall.app
```

Distributable build: `CODE_SIGN_IDENTITY="Developer ID Application: <name> (<TEAMID>)" NOTARY_KEYCHAIN_PROFILE=<profile> Scripts/package_app.sh` (recreate the keychain profile with `xcrun notarytool store-credentials`).

## Verify

```sh
swift build
codesign --verify --deep --strict --verbose=2 dist/FidgetBall.app
```

Then launch the app: a dot appears in the menu bar and the ball hangs from it. `Option+F` hides or shows the overlay.

## Gotchas

- Building inside iCloud/`~/Documents` can cause codesign errors from file-provider metadata. Use `swift build --scratch-path /tmp/fidget-ball-swift-build`.
- Without Developer ID notarization, Gatekeeper blocks the zip on other Macs.
