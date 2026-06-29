import AppKit
import Carbon
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var settings: AppSettings
    private let onChange: (AppSettings) -> Void
    var onClose: (() -> Void)?

    init(settings: AppSettings, onChange: @escaping (AppSettings) -> Void) {
        self.settings = settings
        self.onChange = onChange
        let window = RecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Fidget Ball Settings"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.level = .floating
        window.centerOnMainScreen()
        super.init(window: window)
        window.delegate = self
        reloadContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(settings: AppSettings) {
        self.settings = settings
        reloadContent()
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        (window as? RecordingWindow)?.centerOnMainScreenIfNeeded()
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func reloadContent() {
        window?.contentViewController = NSHostingController(rootView: SettingsView(
            settings: settings,
            onChange: { [weak self] settings in
                self?.settings = settings
                settings.save()
                self?.onChange(settings)
            },
            onReset: { [weak self] in
                let defaults = AppSettings()
                defaults.save()
                self?.settings = defaults
                self?.onChange(defaults)
                self?.reloadContent()
            },
            onRecordHotKey: { [weak self] eventHandler in
                (self?.window as? RecordingWindow)?.onKeyDown = eventHandler
            },
            onHotKeyCaptured: { [weak self] settings in
                self?.settings = settings
                settings.save()
                self?.onChange(settings)
                self?.reloadContent()
            }
        ))
    }
}

private struct SettingsView: View {
    let settings: AppSettings
    let onChange: (AppSettings) -> Void
    let onReset: () -> Void
    let onRecordHotKey: (@escaping (NSEvent) -> Void) -> Void
    let onHotKeyCaptured: (AppSettings) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("General") {
                    NativeCheckbox(title: "Launch at Login", value: settings.launchAtLogin) {
                        update(\.launchAtLogin, $0)
                    }
                }
                section("Physics") {
                    slider("Gravity", \.gravity, 300...3200)
                    slider("Rope length", \.ropeLengthBase, 80...520)
                    slider("Max rope length", \.ropeDragStretch, 0.1...2.4)
                    slider("Rope stiffness", \.ropeStiffness, 0.05...1.4)
                    slider("Air drag", \.airDrag, 0...0.16)
                    slider("Ball weight", \.ballWeight, 0.3...2.8)
                    slider("Bounce damping", \.bounceDamping, 0.15...0.96)
                    slider("Throw speed", \.throwBoost, 0.2...2.4)
                }
                section("Appearance") {
                    slider("Ball size", \.ballRadius, 18...72)
                    NativePopup(title: "Ball image", selected: settings.ballSkin, options: BallSkin.allCases) {
                        update(\.ballSkin, $0)
                    }
                    NativeColorWell(title: "Rope color", color: settings.ropeColor) {
                        update(\.ropeColor, $0)
                    }
                }
                section("Controls") {
                    NativeButton(title: hotKeyTitle) {
                        onRecordHotKey(captureHotKey)
                    }
                }
                section("Advanced") {
                    slider("Rope damping", \.ropeDamping, 0...0.9)
                    slider("Floor friction", \.floorFriction, 0...0.6)
                    slider("Spin response", \.spinResponse, 0...2.5)
                    slider("Grab padding", \.hitPadding, 0...40)
                }
                NativeButton(title: "Reset to Defaults", action: onReset)
            }
            .padding(22)
        }
        .frame(width: 520, height: 680)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func slider(_ title: String, _ keyPath: WritableKeyPath<AppSettings, CGFloat>, _ range: ClosedRange<CGFloat>) -> some View {
        NativeSlider(title: title, value: settings[keyPath: keyPath], range: range) {
            update(keyPath, $0)
        }
    }

    private func update<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>, _ value: Value) {
        var next = settings
        next[keyPath: keyPath] = value
        onChange(next)
    }

    private var hotKeyTitle: String {
        var parts: [String] = []
        if settings.hotKeyModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        if settings.hotKeyModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if settings.hotKeyModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if settings.hotKeyModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        parts.append(settings.hotKeyCode == 3 ? "F" : "Key \(settings.hotKeyCode)")
        return parts.joined(separator: "+")
    }

    private func captureHotKey(_ event: NSEvent) {
        if event.keyCode == 53 {
            onRecordHotKey { _ in }
            return
        }
        let flags = carbonFlags(from: event.modifierFlags)
        guard flags != 0 else { return }
        var next = settings
        next.hotKeyCode = UInt32(event.keyCode)
        next.hotKeyModifiers = flags
        onRecordHotKey { _ in }
        onHotKeyCaptured(next)
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private struct NativeSlider: NSViewRepresentable {
    let title: String
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 135).isActive = true
        let slider = NSSlider(value: Double(value), minValue: Double(range.lowerBound), maxValue: Double(range.upperBound), target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        let valueLabel = NSTextField(labelWithString: formatted(value))
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        context.coordinator.valueLabel = valueLabel
        let row = NSStackView(views: [label, slider, valueLabel])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    func updateNSView(_ row: NSStackView, context: Context) {
        guard let slider = row.arrangedSubviews.compactMap({ $0 as? NSSlider }).first else { return }
        if !slider.isHighlighted {
            slider.doubleValue = Double(value)
            context.coordinator.valueLabel?.stringValue = formatted(value)
        }
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, formatter: formatted)
    }

    private func formatted(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? "\(Int(rounded))" : "\(rounded)"
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (CGFloat) -> Void
        let formatter: (CGFloat) -> String
        weak var valueLabel: NSTextField?

        init(onChange: @escaping (CGFloat) -> Void, formatter: @escaping (CGFloat) -> String) {
            self.onChange = onChange
            self.formatter = formatter
        }

        @objc func changed(_ sender: NSSlider) {
            let value = CGFloat(sender.doubleValue)
            valueLabel?.stringValue = formatter(value)
            onChange(value)
        }
    }
}

private struct NativeCheckbox: NSViewRepresentable {
    let title: String
    let value: Bool
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSButton {
        NSButton(checkboxWithTitle: title, target: context.coordinator, action: #selector(Coordinator.changed(_:)))
    }

    func updateNSView(_ button: NSButton, context: Context) {
        button.state = value ? .on : .off
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (Bool) -> Void

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        @objc func changed(_ sender: NSButton) {
            onChange(sender.state == .on)
        }
    }
}

private struct NativePopup: NSViewRepresentable {
    let title: String
    let selected: BallSkin
    let options: [BallSkin]
    let onChange: (BallSkin) -> Void

    func makeNSView(context: Context) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 135).isActive = true
        let popup = NSPopUpButton()
        options.forEach { popup.addItem(withTitle: $0.title) }
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.changed(_:))
        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    func updateNSView(_ row: NSStackView, context: Context) {
        let popup = row.arrangedSubviews.compactMap { $0 as? NSPopUpButton }.first
        popup?.selectItem(withTitle: selected.title)
        context.coordinator.options = options
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(options: options, onChange: onChange)
    }

    @MainActor
    final class Coordinator: NSObject {
        var options: [BallSkin]
        var onChange: (BallSkin) -> Void

        init(options: [BallSkin], onChange: @escaping (BallSkin) -> Void) {
            self.options = options
            self.onChange = onChange
        }

        @objc func changed(_ sender: NSPopUpButton) {
            guard let title = sender.titleOfSelectedItem,
                  let skin = options.first(where: { $0.title == title }) else { return }
            onChange(skin)
        }
    }
}

private struct NativeColorWell: NSViewRepresentable {
    let title: String
    let color: NSColor
    let onChange: (NSColor) -> Void

    func makeNSView(context: Context) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 135).isActive = true
        let well = NSColorWell()
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        let row = NSStackView(views: [label, well])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    func updateNSView(_ row: NSStackView, context: Context) {
        row.arrangedSubviews.compactMap { $0 as? NSColorWell }.first?.color = color
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (NSColor) -> Void

        init(onChange: @escaping (NSColor) -> Void) {
            self.onChange = onChange
        }

        @objc func changed(_ sender: NSColorWell) {
            onChange(sender.color)
        }
    }
}

private struct NativeButton: NSViewRepresentable {
    let title: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.invoke))
        button.bezelStyle = .rounded
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        button.title = title
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func invoke() {
            action()
        }
    }
}

private final class RecordingWindow: NSWindow {
    var onKeyDown: ((NSEvent) -> Void)?
    private var hasCentered = false

    func centerOnMainScreenIfNeeded() {
        guard !hasCentered else { return }
        centerOnMainScreen()
        hasCentered = true
    }

    override func keyDown(with event: NSEvent) {
        if let onKeyDown {
            onKeyDown(event)
        } else {
            super.keyDown(with: event)
        }
    }
}

private extension NSWindow {
    func centerOnMainScreen() {
        let mainScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let visibleFrame = mainScreen?.visibleFrame else {
            center()
            return
        }
        let origin = NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        )
        setFrameOrigin(origin)
    }
}
