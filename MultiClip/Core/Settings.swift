import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    var historySize: Int {
        didSet { UserDefaults.standard.set(historySize, forKey: "historySize") }
    }

    /// Auto-clear interval in seconds. 0 = never.
    var autoClearInterval: TimeInterval {
        didSet { UserDefaults.standard.set(autoClearInterval, forKey: "autoClearInterval") }
    }

    var pasteSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(pasteSoundEnabled, forKey: "pasteSoundEnabled") }
    }

    var launchAtLogin: Bool {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults
        defaults.register(defaults: [
            "historySize": 25,
            "autoClearInterval": 86400.0, // 24 hours
            "pasteSoundEnabled": true,
        ])

        self.historySize = defaults.integer(forKey: "historySize")
        self.autoClearInterval = defaults.double(forKey: "autoClearInterval")
        self.pasteSoundEnabled = defaults.bool(forKey: "pasteSoundEnabled")
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // Predefined intervals for the picker
    static let autoClearOptions: [(String, TimeInterval)] = [
        ("1 hour", 3600),
        ("6 hours", 21600),
        ("12 hours", 43200),
        ("24 hours", 86400),
        ("Never", 0),
    ]
}
