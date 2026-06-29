---
summary: Timeline of notable changes in fidget-ball.
---

# Changelog

## 2026-06-29 — Main Display Lock

- Changed the fidget ball to stay on the main display instead of spanning or moving between monitors.
- Removed the menu action for moving the ball to another screen.
- Anchored the rope to a fixed top-right menu-bar position so it stays stable when focus changes between displays.
- Added a settings window with live, persisted physics, appearance, and shortcut controls.
- Added six ball skin choices and a configurable rope color.
- Added a global hide/show shortcut, defaulting to `Option+F`.
- Switched ball skins to bundled high-resolution image assets.
- Removed live status-item tracking so the rope no longer jumps when macOS relocates menu-bar extras.
- Changed the status-bar item to use a native AppKit status button with left-click reset and right-click menu behavior.
- Added a mouse-move monitor for faster rope hover cutting and pass-through updates.
- Restored `Move to Next Screen` for moving the single ball between displays.
- Added status-item frame sanity checks so an early or invalid menu-bar frame falls back to top-right placement.
- Replaced the ball skin bundle with generated matching basketball, tennis, football, disco, marble, and smiley assets.
- Added a native `Launch at Login` setting backed by macOS login item registration.
- Expanded settings with a scrollable tuning panel for advanced rope damping, floor friction, spin response, and grab padding.
- Added a generated macOS app icon and packaged it into the app bundle.
- Fixed the packaged app launch by including the SwiftPM resource bundle in the `.app`.
- Added open-source project docs, an MIT license, contributor guidance, security reporting notes, and repository ignore rules.
- Added a GitHub feature-request template, a pull request template, support notes, and a code of conduct.
- Fixed the settings window so it opens above the transparent desktop overlay.
- Changed the status-bar dot so left click resets the ball and right click opens the menu.
- Kept the ball visible and active while the Settings panel is open.
- Simplified the status menu by removing reset, reattach, cut, launch-at-login, and version items.
- Replaced the settings panel internals with SwiftUI hosted in a native AppKit window.
- Fixed settings placement so it opens on the fixed main display instead of following transient multi-display menu-bar focus.
- Changed dragging so the ball center follows the pointer exactly while pulling, without rope-clamp offset.
- Removed haptic feedback and related settings.

## 2026-06-25 — Initial Desktop Fidget

- Added a native macOS desktop fidget ball with rope physics, pull-to-detach behavior, bouncing, throwing, and live settings.
- Added click-to-pop behavior so a quick click launches the ball upward like a small toss.
- Improved physics with fixed-step integration, rope constraint solving, throw boost, floor friction, and explicit cut-rope controls.
- Added dynamic click-through behavior outside the ball and Dock-aware bounds using the screen's visible frame.
- Moved the rope anchor to the menu-bar strip so the ball hangs from the top of the screen.
- Replaced the menu-bar text label with a solid-circle status item.
- Kept click-to-pop attached to the rope so the ball does not unexpectedly become free-floating.
- Added hover-to-cut rope behavior when the pointer crosses the string.
- Added a short split-and-fade animation when the rope is cut.
- Removed the settings menu and tuning panel to keep the app focused on direct fidget controls.
- Added share packaging that signs the app bundle, creates a ditto zip, and supports Developer ID notarization when credentials are available.
- Removed pull-to-break behavior so the rope only detaches when cut.
- Made dragging respect the rope length while the pointer is pulling, so release feels like a taut swing instead of a bounce-back.
- Added elastic drag stretch so an attached ball can still be pulled naturally without breaking the rope.
- Added snap-back velocity on release and fixed reattach so it restores the menu-bar anchor after cutting.
- Reworked attached dragging with a soft elastic clamp, raw-pull snap strength, and non-teleporting reattach.
- Increased the attached rope stretch range so the ball can be pulled farther before snapping back.
- Softened rope stiffness and snap force so release feels less rigid.
- Made rope drawing respond to slack, pull tension, and swing velocity instead of using a fixed circular arc.
- Replaced fixed-length rope correction with spring-damper physics so the rope keeps moving dynamically after snap-back.
- Switched multi-monitor handling to a single global overlay so the ball can travel between connected displays.
- Added a menu action to move the single ball and rope anchor between monitors without creating duplicate balls.
- Changed monitor collisions to use each display's real visible frame, with shared edges left open so throws can cross displays without bouncing into off-screen gaps.
