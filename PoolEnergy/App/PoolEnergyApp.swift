import SwiftUI

@main
struct PoolEnergyApp: App {
    @State private var localization = Localization()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(localization)
                .environment(settings)
                .tint(Theme.brand)
        }
    }
}
