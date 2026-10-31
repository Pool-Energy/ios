import Foundation
import Observation

@Observable
final class Localization {
    static let supported = ["en", "fr", "de", "es", "nl", "tr", "zh"]

    var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "app.language"
    private var tables: [String: [String: Any]] = [:]

    init() {
        var loaded: [String: [String: Any]] = [:]
        for code in Self.supported {
            guard
                let url = Bundle.main.url(forResource: code, withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            loaded[code] = json
        }
        tables = loaded

        if let stored = UserDefaults.standard.string(forKey: Self.storageKey), Self.supported.contains(stored) {
            language = stored
        } else {
            let preferred = Locale.preferredLanguages.first?
                .split(separator: "-").first
                .map(String.init)
                .map { $0.lowercased() } ?? "en"
            language = Self.supported.contains(preferred) ? preferred : "en"
        }
    }

    /// Resolves a namespaced key (`FARMERS.STATS.POOL_SPACE`) against the
    /// current language, falling back to English and then to the key itself.
    func t(_ key: String) -> String {
        lookup(key, in: language) ?? lookup(key, in: "en") ?? key
    }

    func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    private func lookup(_ key: String, in code: String) -> String? {
        guard var node = tables[code] as [String: Any]? else { return nil }
        let parts = key.split(separator: ".").map(String.init)
        for part in parts.dropLast() {
            guard let next = node[part] as? [String: Any] else { return nil }
            node = next
        }
        guard let last = parts.last else { return nil }
        return node[last] as? String
    }
}
