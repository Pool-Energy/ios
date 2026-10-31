import Foundation
import Observation

@Observable
final class AppSettings {
    var currency: String {
        didSet { UserDefaults.standard.set(currency, forKey: Self.currencyKey) }
    }

    private static let currencyKey = "app.currency"

    init() {
        currency = UserDefaults.standard.string(forKey: Self.currencyKey) ?? "usd"
    }

    var currencySymbol: String {
        currency == "eur" ? "€" : "$"
    }
}
