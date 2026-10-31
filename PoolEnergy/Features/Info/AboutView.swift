import SwiftUI

struct AboutView: View {
    @Environment(Localization.self) private var l10n
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private struct AboutLink: Identifiable {
        let id: String
        let title: String
        let url: String
        let icon: String
    }

    private var links: [AboutLink] {
        [
            AboutLink(id: "web", title: "pool.energy", url: "https://pool.energy", icon: "globe"),
            AboutLink(id: "join", title: l10n.t("TOPBAR.JOIN_POOL"), url: "https://pool.energy/join", icon: "plus.circle"),
            AboutLink(id: "api", title: l10n.t("MENUITEMS.API.TEXT"), url: "https://pool.energy/api/doc/", icon: "doc.text"),
            AboutLink(id: "discord", title: l10n.t("MENUITEMS.CONTACT.LIST.DISCORD"), url: "https://discord.gg/arZDWsY5xZ", icon: "bubble.left.and.bubble.right"),
            AboutLink(id: "telegram", title: l10n.t("MENUITEMS.CONTACT.LIST.TELEGRAM"), url: "https://t.me/chiapoolenergy", icon: "paperplane"),
            AboutLink(id: "github", title: l10n.t("MENUITEMS.CONTACT.LIST.GITHUB"), url: "https://github.com/Pool-Energy", icon: "chevron.left.forwardslash.chevron.right"),
        ]
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Theme.brand)
                        Text("Pool.Energy")
                            .font(.title2.weight(.bold))
                        Text("Chia farming pool")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section(l10n.t("TOPBAR.LANGUAGE_ALT")) {
                    Picker("", selection: languageBinding) {
                        ForEach(Localization.supported, id: \.self) { code in
                            Text(languageName(code)).tag(code)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(l10n.t("FARMERS.STATS.XCH_PRICE")) {
                    Picker("", selection: $settings.currency) {
                        Text("USD").tag("usd")
                        Text("EUR").tag("eur")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ForEach(links) { link in
                        if let url = URL(string: link.url) {
                            Link(destination: url) {
                                Label(link.title, systemImage: link.icon)
                            }
                        }
                    }
                }

                Section {
                    Text("Unofficial native client for the Pool.Energy public API. Data is provided by pool.energy and refreshed live over WebSockets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(l10n.t("MENUITEMS.INFO.TEXT"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("COMMON.CLOSE")) { dismiss() }
                }
            }
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { l10n.language },
            set: { l10n.language = $0 }
        )
    }

    private func languageName(_ code: String) -> String {
        Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized ?? code.uppercased()
    }
}
