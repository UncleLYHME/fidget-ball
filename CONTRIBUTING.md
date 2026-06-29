# Contributing

Thanks for taking a look at Fidget Ball.

## Local Setup

Requirements:

- macOS 14 or newer
- Xcode 16 or newer, or matching Apple Command Line Tools
- Swift 6 toolchain

Run from source:

```bash
swift run FidgetBall
```

Build:

```bash
swift build
```

Package:

```bash
Scripts/package_app.sh
```

## Validation

For behavior changes, run the smallest useful check first:

```bash
swift build --scratch-path /tmp/fidget-ball-swift-build
```

For packaging changes, run:

```bash
Scripts/package_app.sh
```

Then verify the zip:

```bash
VERIFY_DIR=$(mktemp -d /tmp/fidgetball-verify.XXXXXX)
ditto -x -k dist/FidgetBall.zip "$VERIFY_DIR"
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/FidgetBall.app"
open "$VERIFY_DIR"
```

## Code Style

- Keep the app native: Swift, AppKit, SwiftPM.
- Prefer small focused files over large mixed-responsibility files.
- Keep user-facing behavior in the README when it changes.
- Keep `CHANGELOG.md` updated for user-facing changes.
- Avoid adding dependencies unless they clearly reduce complexity.
- Do not commit generated build outputs from `.build/`, `dist/`, or temporary image-generation folders.

## Pull Requests

Good pull requests include:

- A short description of the behavior change.
- Screenshots or screen recordings for visible UI changes.
- The validation command you ran.
- Notes about any macOS permission, signing, or login-item behavior that could affect review.

## Security

Please do not open public issues for security-sensitive reports. Use GitHub private vulnerability reporting if it is enabled for the repository.
