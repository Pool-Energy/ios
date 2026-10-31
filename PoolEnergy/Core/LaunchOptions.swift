import Foundation

/// Launch arguments used by the screenshot/UI-test tooling, e.g.
/// `simctl launch booted energy.pool.app -startTab blocks -startFarmer <id>`.
enum LaunchOptions {
    static var startTab: String {
        UserDefaults.standard.string(forKey: "startTab") ?? "farmers"
    }

    static var startFarmer: String? {
        UserDefaults.standard.string(forKey: "startFarmer")
    }
}
