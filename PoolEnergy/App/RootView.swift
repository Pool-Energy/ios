import SwiftUI

struct RootView: View {
    @Environment(Localization.self) private var l10n
    @State private var selection = LaunchOptions.startTab

    var body: some View {
        TabView(selection: $selection) {
            FarmersView()
                .tabItem { Label(l10n.t("MENUITEMS.FARMERS.TEXT"), systemImage: "person.3.fill") }
                .tag("farmers")

            BlocksView()
                .tabItem { Label(l10n.t("MENUITEMS.BLOCKS.TEXT"), systemImage: "square.stack.3d.up.fill") }
                .tag("blocks")

            RewardsView()
                .tabItem { Label(l10n.t("MENUITEMS.REWARDS.TEXT"), systemImage: "wallet.pass.fill") }
                .tag("rewards")

            ChiaView()
                .tabItem { Label(l10n.t("MENUITEMS.CHIA.TEXT"), systemImage: "leaf.fill") }
                .tag("chia")

            PoolView()
                .tabItem { Label(l10n.t("MENUITEMS.POOL.TEXT"), systemImage: "server.rack") }
                .tag("pool")
        }
    }
}

#Preview {
    RootView()
        .environment(Localization())
        .environment(AppSettings())
}
