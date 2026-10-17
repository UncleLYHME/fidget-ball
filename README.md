# Fidget Ball

Fidget Ball is a small native macOS menu-bar app that hangs a playful ball from the top of your screen. Drag it, throw it, cut the rope, switch skins, tune the physics, or hide it when you need a clean desktop.

It is built with Swift, AppKit, SwiftUI, and Swift Package Manager. There is no web view, no analytics, and no background service beyond the optional macOS login item registration.

## Features

- Minimal menu-bar status item with hide/show, screen move, settings, and quit actions.
- Transparent desktop overlay that passes clicks through unless the pointer is interacting with the ball or rope.
- Rope physics with gravity, damping, stretch, bounce, throw velocity, and spin.
- One ball on one display at a time, with `Move to Next Screen` for multi-monitor setups.
- Rope anchor follows the real status-bar dot on the main display.
- Built-in ball skins: smiley, marble, basketball, tennis, football, and disco.
- Custom rope color, global hide/show shortcut, and launch-at-login support.
- Packaged `.app` and shareable `.zip` build script.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer, or matching Apple Command Line Tools
- Swift 6 toolchain

Check your local Swift toolchain:

```bash
swift --version
```

## Run From Source

Clone the repo, then run:

```bash
swift run FidgetBall
```

The app appears as a small dot in the menu bar. Click it to reset the ball, or right-click it to open the menu.

## Build

Debug build:

```bash
swift build
```

Release build:

```bash
swift build -c release --product FidgetBall
```

If you see strict codesign errors while building inside `~/Documents`, it may be macOS file-provider metadata. A clean scratch build avoids that local metadata:

```bash
swift build --scratch-path /tmp/fidget-ball-swift-build
```

## Package The App

Create `dist/FidgetBall.app` and `dist/FidgetBall.zip`:

```bash
Scripts/package_app.sh
```

Share `dist/FidgetBall.zip`, not the raw `.app` directory. The script uses `ditto --norsrc` so resource metadata is stripped from the zip.

For a distributable build that opens normally on other Macs, sign and notarize with your Developer ID certificate:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="notary-profile" \
Scripts/package_app.sh
```

Without Developer ID notarization, Gatekeeper may block the app on other Macs even when local codesigning succeeds.

## Verify A Package

```bash
VERIFY_DIR=$(mktemp -d /tmp/fidgetball-verify.XXXXXX)
ditto -x -k dist/FidgetBall.zip "$VERIFY_DIR"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/FidgetBall.app"
open "$VERIFY_DIR"
```

## Controls

- Click the menu-bar dot to reset the ball.
- Right-click the menu-bar dot to open the app menu.
- Drag the ball to stretch and swing the rope.
- Release while dragging to throw.
- Hover across the rope to cut it.
- Double-click the ball to reattach the rope.
- Click the menu-bar dot to reset and reattach the ball.
- Click the ball for a quick upward pop.
- Press `Option+F` to hide or show the overlay.
- Use `Move to Next Screen` from the menu to move the ball to another display.
- Use `Settings...` from the menu to tune the app.

## Settings

Open `Settings...` from the menu-bar menu.

General:

- Launch at Login

Physics:

- Gravity
- Rope length
- Max rope length
- Rope stiffness
- Air drag
- Ball weight
- Bounce damping
- Throw speed

Appearance:

- Ball size
- Ball image
- Rope color

Controls:

- Hide/show shortcut recorder

Advanced:

- Rope damping
- Floor friction
- Spin response
- Grab padding

Settings are stored in macOS `UserDefaults` under the app bundle identifier.

## How It Works

The app starts as an accessory app with `LSUIElement` so it lives in the menu bar instead of the Dock.

High-level flow:

- [main.swift](Sources/FidgetBall/main.swift) owns app startup, status menu setup, overlay window placement, screen changes, and launch-at-login wiring.
- [FidgetOverlayView.swift](Sources/FidgetBall/FidgetOverlayView.swift) draws the rope and ball, tracks pointer interaction, and keeps the overlay click-through outside interactive areas.
- [Physics.swift](Sources/FidgetBall/Physics.swift) contains the rope and ball simulation.
- [AppSettings.swift](Sources/FidgetBall/AppSettings.swift) defines persisted settings and maps UI values into physics settings.
- [SettingsWindowController.swift](Sources/FidgetBall/SettingsWindowController.swift) builds the SwiftUI settings panel in a native AppKit window.
- [BallSkinDrawing.swift](Sources/FidgetBall/BallSkinDrawing.swift) loads bundled skin PNGs and falls back to procedural drawing if needed.
- [GlobalHotKeyController.swift](Sources/FidgetBall/GlobalHotKeyController.swift) registers the global hide/show shortcut through Carbon hot keys.
- [LaunchAtLoginController.swift](Sources/FidgetBall/LaunchAtLoginController.swift) uses `SMAppService` for login item registration.

The overlay is a borderless transparent panel at status-bar level. It joins all Spaces, ignores mouse events by default, and only accepts interaction when the pointer is over the ball or rope. The rope anchor uses a fixed top-right menu-bar position on the selected display so it does not jump when macOS moves status items between active displays.

SwiftPM resources are packaged into `fidget-ball_FidgetBall.bundle`. The packaging script must copy that bundle into `FidgetBall.app/Contents/Resources/`, otherwise `Bundle.module` will fail at launch.

## Assets

Project assets live under `Sources/FidgetBall/Resources/`.

- `AppIcon.icns` and `AppIcon.png` are the macOS app icon.
- `BallSkins/*.png` are the bundled ball skins.

Generated source images and temporary conversion helpers are development artifacts and should not be required to run the app.

## Troubleshooting

`Fatal error: unable to find bundle named fidget-ball_FidgetBall`

The app was packaged without the SwiftPM resource bundle. Run:

```bash
Scripts/package_app.sh
```

`resource fork, Finder information, or similar detritus not allowed`

macOS attached extended attributes to the app bundle. The package script clears common metadata and the zip is created with `ditto --norsrc`. Prefer sharing `dist/FidgetBall.zip`.

The app opens but no Dock icon appears

That is expected. Fidget Ball is a menu-bar accessory app. Look for the dot in the menu bar.

Launch at Login does not stick in a development run

macOS login item registration is most reliable from a packaged `.app`. Build with `Scripts/package_app.sh`, move the app into `/Applications`, then enable `Launch at Login`.

## Contributing

Feature requests and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, validation, and style expectations.

For security-sensitive reports, see [SECURITY.md](SECURITY.md).
For community expectations and support channels, see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [SUPPORT.md](SUPPORT.md).

## License

Fidget Ball is available under the MIT License. See [LICENSE](LICENSE).

Unless noted otherwise, the source code and bundled project assets are covered by the same license.

This project is independent and is not affiliated with any other fidget or menu-bar app.

Rebuild after a wiped drive: see [RESTORE.md](RESTORE.md).
