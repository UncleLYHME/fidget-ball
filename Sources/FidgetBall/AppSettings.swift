import AppKit
import Carbon

enum BallSkin: String, CaseIterable {
    case smiley
    case marble
    case basketball
    case tennis
    case football
    case disco

    var title: String {
        switch self {
        case .smiley: "Smiley"
        case .marble: "Marble"
        case .basketball: "Basketball"
        case .tennis: "Tennis"
        case .football: "Football"
        case .disco: "Disco"
        }
    }

    var assetName: String {
        switch self {
        case .smiley: "smile-face-ball"
        case .marble: "marble-ball"
        case .basketball: "basketball-ball"
        case .tennis: "tennis-ball"
        case .football: "football-ball"
        case .disco: "disco-ball"
        }
    }
}

struct AppSettings {
    var gravity: CGFloat = 1500
    var ropeStiffness: CGFloat = 0.42
    var airDrag: CGFloat = 0.018
    var ballRadius: CGFloat = 34
    var ballWeight: CGFloat = 1.0
    var bounceDamping: CGFloat = 0.72
    var ropeLengthBase: CGFloat = 230
    var ropeDragStretch: CGFloat = 1.15
    var throwBoost: CGFloat = 1.0
    var floorFriction: CGFloat = 0.08
    var spinResponse: CGFloat = 1.0
    var ropeDamping: CGFloat = 0.24
    var hitPadding: CGFloat = 16
    var ballSkin: BallSkin = .smiley
    var ropeColor = NSColor(calibratedRed: 0.87, green: 0.72, blue: 0.35, alpha: 0.78)
    var hotKeyCode: UInt32 = 3
    var hotKeyModifiers: UInt32 = UInt32(optionKey)
    var launchAtLogin = false

    static let changedNotification = Notification.Name("FidgetBallSettingsChanged")

    var physicsSettings: FidgetSettings {
        FidgetSettings(
            gravity: gravity,
            ropeStiffness: ropeStiffness,
            airDrag: airDrag,
            ballRadius: ballRadius,
            ballWeight: ballWeight,
            bounceDamping: bounceDamping,
            ropeLengthBase: ropeLengthBase,
            ropeDragStretch: ropeDragStretch,
            throwBoost: throwBoost,
            floorFriction: floorFriction,
            spinResponse: spinResponse,
            ropeDamping: ropeDamping
        )
    }

    static func load() -> AppSettings {
        let defaults = UserDefaults.standard
        var settings = AppSettings()
        settings.gravity = defaults.cgFloat("gravity", settings.gravity)
        settings.ropeStiffness = defaults.cgFloat("ropeStiffness", settings.ropeStiffness)
        settings.airDrag = defaults.cgFloat("airDrag", settings.airDrag)
        settings.ballRadius = defaults.cgFloat("ballRadius", settings.ballRadius)
        settings.ballWeight = defaults.cgFloat("ballWeight", settings.ballWeight)
        settings.bounceDamping = defaults.cgFloat("bounceDamping", settings.bounceDamping)
        settings.ropeLengthBase = defaults.cgFloat("ropeLengthBase", settings.ropeLengthBase)
        settings.ropeDragStretch = defaults.cgFloat("ropeDragStretch", settings.ropeDragStretch)
        settings.throwBoost = defaults.cgFloat("throwBoost", settings.throwBoost)
        settings.floorFriction = defaults.cgFloat("floorFriction", settings.floorFriction)
        settings.spinResponse = defaults.cgFloat("spinResponse", settings.spinResponse)
        settings.ropeDamping = defaults.cgFloat("ropeDamping", settings.ropeDamping)
        settings.hitPadding = defaults.cgFloat("hitPadding", settings.hitPadding)
        if let rawSkin = defaults.string(forKey: "ballSkin"), let skin = BallSkin(rawValue: rawSkin) {
            settings.ballSkin = skin
        }
        settings.ropeColor = defaults.color("ropeColor") ?? settings.ropeColor
        let storedKeyCode = defaults.integer(forKey: "hotKeyCode")
        if storedKeyCode > 0 {
            settings.hotKeyCode = UInt32(storedKeyCode)
        }
        let storedModifiers = defaults.integer(forKey: "hotKeyModifiers")
        if storedModifiers > 0 {
            settings.hotKeyModifiers = UInt32(storedModifiers)
        }
        settings.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? LaunchAtLoginController.isEnabled
        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Double(gravity), forKey: "gravity")
        defaults.set(Double(ropeStiffness), forKey: "ropeStiffness")
        defaults.set(Double(airDrag), forKey: "airDrag")
        defaults.set(Double(ballRadius), forKey: "ballRadius")
        defaults.set(Double(ballWeight), forKey: "ballWeight")
        defaults.set(Double(bounceDamping), forKey: "bounceDamping")
        defaults.set(Double(ropeLengthBase), forKey: "ropeLengthBase")
        defaults.set(Double(ropeDragStretch), forKey: "ropeDragStretch")
        defaults.set(Double(throwBoost), forKey: "throwBoost")
        defaults.set(Double(floorFriction), forKey: "floorFriction")
        defaults.set(Double(spinResponse), forKey: "spinResponse")
        defaults.set(Double(ropeDamping), forKey: "ropeDamping")
        defaults.set(Double(hitPadding), forKey: "hitPadding")
        defaults.set(ballSkin.rawValue, forKey: "ballSkin")
        defaults.setColor(ropeColor, forKey: "ropeColor")
        defaults.set(Int(hotKeyCode), forKey: "hotKeyCode")
        defaults.set(Int(hotKeyModifiers), forKey: "hotKeyModifiers")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        NotificationCenter.default.post(name: AppSettings.changedNotification, object: nil)
    }
}

private extension UserDefaults {
    func cgFloat(_ key: String, _ fallback: CGFloat) -> CGFloat {
        object(forKey: key) == nil ? fallback : CGFloat(double(forKey: key))
    }

    func color(_ key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    func setColor(_ color: NSColor, forKey key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) else { return }
        set(data, forKey: key)
    }
}
