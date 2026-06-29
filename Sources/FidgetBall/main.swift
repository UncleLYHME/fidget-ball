import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var overlayWindow: PassthroughWindow?
    private var overlayView: FidgetOverlayView?
    private var settings = AppSettings.load()
    private var settingsWindowController: SettingsWindowController?
    private var hotKeyController: GlobalHotKeyController?
    private var overlayVisible = true
    private var statusMenu: NSMenu?
    private var homeScreenIndex = 0
    private var showHideMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        closeDuplicateInstances()
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()
        settingsWindowController = SettingsWindowController(settings: settings) { [weak self] settings in
            self?.apply(settings)
        }
        settingsWindowController?.onClose = { [weak self] in
            self?.restoreOverlayAfterSettings()
        }
        hotKeyController = GlobalHotKeyController { [weak self] in
            self?.toggleOverlay()
        }
        hotKeyController?.update(settings: settings)
        syncLaunchAtLogin()
        rebuildOverlays()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func rebuildOverlays() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
        createGlobalOverlay()
        overlayWindow?.setIsVisible(overlayVisible)
    }

    private func createGlobalOverlay() {
        let screens = orderedScreens()
        guard !screens.isEmpty else { return }
        homeScreenIndex = min(homeScreenIndex, screens.count - 1)
        let screen = screens[homeScreenIndex]
        let screenFrame = screen.frame
        let homeFrame = screen.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        let homeVisibleFrame = screen.visibleFrame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        let physicsBounds = homeVisibleFrame
        let playableScreens = [homeVisibleFrame]
        let menuBarAnchor = menuBarAnchor(
            for: homeFrame,
            visibleFrame: homeVisibleFrame
        )
        let window = PassthroughWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.acceptsMouseMovedEvents = true

        let view = FidgetOverlayView(
            frame: NSRect(origin: .zero, size: screenFrame.size),
            physicsBounds: physicsBounds,
            playableScreens: playableScreens,
            menuBarAnchor: menuBarAnchor,
            settings: settings
        )
        view.onDetach = { NSSound(named: "Tink")?.play() }
        window.contentView = view
        window.fidgetView = view
        window.orderFrontRegardless()

        overlayWindow = window
        overlayView = view
    }

    private func menuBarAnchor(for screenFrame: NSRect, visibleFrame: NSRect) -> NSPoint {
        let rightInset: CGFloat = 88
        let topInset: CGFloat = 12
        return NSPoint(
            x: max(visibleFrame.minX + 90, visibleFrame.maxX - rightInset),
            y: screenFrame.maxY - topInset
        )
    }

    private var isUsingMainScreen: Bool {
        let screens = orderedScreens()
        guard screens.indices.contains(homeScreenIndex), let main = fixedMainScreen() else { return true }
        return screens[homeScreenIndex] == main
    }

    private func orderedScreens() -> [NSScreen] {
        let mainScreen = fixedMainScreen()
        return NSScreen.screens.sorted { left, right in
            if left == mainScreen {
                return true
            }
            if right == mainScreen {
                return false
            }
            if left.frame.minX == right.frame.minX {
                return left.frame.maxY > right.frame.maxY
            }
            return left.frame.minX < right.frame.minX
        }
    }

    private func fixedMainScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
    }

    private func syncRopeAnchorWithStatusItem(force: Bool = false) {
        guard let anchor = currentMenuBarAnchor() else { return }
        overlayView?.moveAnchor(to: anchor)
    }

    private func closeDuplicateInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.bundleIdentifier == bundleIdentifier && app.processIdentifier != currentPID
            }
            .forEach { $0.terminate() }
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 28)

        let menu = NSMenu()
        menu.delegate = self
        let showHide = NSMenuItem(title: "Hide Ball", action: #selector(toggleOverlay), keyEquivalent: "f")
        menu.addItem(showHide)
        showHideMenuItem = showHide
        menu.addItem(NSMenuItem(title: "Move to Next Screen", action: #selector(moveToNextScreen), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        statusMenu = menu
        statusItem = item
        configureStatusButton()
    }

    @objc private func resetBall() {
        overlayView?.resetBall()
    }

    private func configureStatusButton() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusDotImage()
        button.imagePosition = .imageOnly
        button.toolTip = "Fidget Ball"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func makeStatusDotImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.labelColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            resetBall()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            openStatusMenu()
        } else {
            resetBall()
        }
    }

    private func openStatusMenu() {
        syncRopeAnchorWithStatusItem(force: true)
        updateMenuState()
        guard let statusItem, let statusMenu else { return }
        statusItem.popUpMenu(statusMenu)
    }

    @objc private func reattachRope() {
        overlayView?.reattachRope()
    }

    @objc private func cutRope() {
        overlayView?.cutRope()
    }

    @objc private func openSettings() {
        overlayWindow?.level = .normal
        if overlayVisible {
            overlayWindow?.orderFrontRegardless()
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindowController?.show(settings: settings)
    }

    private func restoreOverlayAfterSettings() {
        NSApp.setActivationPolicy(.accessory)
        if overlayVisible {
            overlayWindow?.level = .statusBar
            overlayWindow?.orderFrontRegardless()
        }
    }

    @objc private func toggleOverlay() {
        overlayVisible.toggle()
        overlayWindow?.setIsVisible(overlayVisible)
        updateMenuState()
    }

    @objc private func moveToNextScreen() {
        let screens = orderedScreens()
        guard screens.count > 1 else {
            resetBall()
            return
        }
        homeScreenIndex = (homeScreenIndex + 1) % screens.count
        rebuildOverlays()
        syncRopeAnchorWithStatusItem(force: true)
    }

    private func apply(_ settings: AppSettings) {
        self.settings = settings
        let requestedLaunchAtLogin = settings.launchAtLogin
        syncLaunchAtLogin()
        if self.settings.launchAtLogin != requestedLaunchAtLogin {
            self.settings.save()
            settingsWindowController?.show(settings: self.settings)
        }
        overlayView?.updateSettings(self.settings)
        hotKeyController?.update(settings: self.settings)
        updateMenuState()
    }

    @objc private func toggleLaunchAtLogin() {
        settings.launchAtLogin.toggle()
        syncLaunchAtLogin()
        settings.save()
        updateMenuState()
    }

    private func syncLaunchAtLogin() {
        do {
            try LaunchAtLoginController.setEnabled(settings.launchAtLogin)
        } catch {
            settings.launchAtLogin = LaunchAtLoginController.isEnabled
            NSLog("FidgetBall launch-at-login update failed: \(error.localizedDescription)")
        }
    }

    private func updateMenuState() {
        showHideMenuItem?.title = overlayVisible ? "Hide Ball" : "Show Ball"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        syncRopeAnchorWithStatusItem(force: true)
        updateMenuState()
    }

    private func currentMenuBarAnchor() -> NSPoint? {
        let screens = orderedScreens()
        guard screens.indices.contains(homeScreenIndex) else { return nil }
        let screen = screens[homeScreenIndex]
        let screenFrame = screen.frame
        let homeFrame = screen.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        let homeVisibleFrame = screen.visibleFrame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        return menuBarAnchor(for: homeFrame, visibleFrame: homeVisibleFrame)
    }

    @objc private func screenConfigurationChanged() {
        rebuildOverlays()
        syncRopeAnchorWithStatusItem(force: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
