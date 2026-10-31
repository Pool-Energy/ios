import SwiftUI

struct FarmersView: View {
    @State private var vm = FarmersViewModel()
    @Environment(Localization.self) private var l10n
    @Environment(AppSettings.self) private var settings
    @State private var showAbout = false
    @State private var path: [String] = LaunchOptions.startFarmer.map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = vm.error, vm.stats == nil {
                        ErrorRetryView(message: error) {
                            Task { await vm.load() }
                        }
                    } else if vm.stats == nil, vm.isLoading {
                        LoadingView()
                    } else {
                        if let stats = vm.stats {
                            statsSection(stats)
                            if stats.blockchainDuststorm {
                                dustStorm(stats)
                            }
                        }
                        leaderboard
                        farmersList
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("MENUITEMS.FARMERS.TEXT"))
            .searchable(
                text: $vm.search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(l10n.t("FARMERS.LIST.SEARCH_PLACEHOLDER"))
            )
            .refreshable { await vm.load() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiveBadge(title: "LIVE")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .navigationDestination(for: String.self) { launcherId in
                FarmerView(launcherId: launcherId)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .task {
                if vm.stats == nil { await vm.load() }
                vm.startLive()
            }
            .onDisappear { vm.stopLive() }
        }
    }

    // MARK: Sections

    private func statsSection(_ stats: Stats) -> some View {
        let currentEffort = currentEffort(stats)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(
                title: l10n.t("FARMERS.STATS.POOL_SPACE"),
                value: Fmt.bytes(Double(stats.poolSpace)),
                icon: "externaldrive.fill"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.ACTIVE_TOTAL_FARMERS"),
                value: "\(stats.farmersActive) / \(stats.farmers)",
                icon: "person.3.fill"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.EFFORT"),
                value: "\(Fmt.percent(currentEffort, digits: 0)) / \(Fmt.percent(stats.averageEffort ?? 0, digits: 0))",
                icon: "gauge.with.dots.needle.67percent"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.ESTIMATE_TO_WIN"),
                value: Fmt.duration(minutes: Double(stats.estimateWin)),
                icon: "clock.fill"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.CURRENT_FEE"),
                value: Fmt.percent(stats.fee * 100),
                icon: "percent"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.XCH_PRICE"),
                value: price(stats),
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    private func dustStorm(_ stats: Stats) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            Text(l10n.t("FARMERS.STATS.DUST_STORM"))
                .font(.subheadline.weight(.semibold))
            Text("\(stats.blockchainMempoolFullPct)%")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .card(padding: 12)
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: l10n.t("FARMERS.LEADERBOARD.TITLE"))
            ForEach(Array(vm.launchers.prefix(3).enumerated()), id: \.element.id) { index, launcher in
                NavigationLink(value: launcher.launcherId) {
                    LeaderboardRow(rank: index + 1, launcher: launcher)
                }
                .buttonStyle(.plain)
                if index < 2 {
                    Divider()
                }
            }
        }
        .card()
    }

    private var farmersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                text: l10n.t("FARMERS.LIST.TITLE"),
                trailing: "\(vm.totalFarmers)"
            )
            ForEach(vm.launchers) { launcher in
                NavigationLink(value: launcher.launcherId) {
                    FarmerRow(launcher: launcher)
                }
                .buttonStyle(.plain)
                .onAppear {
                    Task { await vm.loadMoreIfNeeded(current: launcher) }
                }
                if launcher.id != vm.launchers.last?.id {
                    Divider()
                }
            }
            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            if vm.launchers.isEmpty, !vm.isLoading {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_PARTIAL"))
            }
        }
        .card()
    }

    private func currentEffort(_ stats: Stats) -> Double {
        guard stats.estimateWin > 0, let since = stats.timeSinceLastWin else { return 0 }
        return max(0, (Double(since) / (Double(stats.estimateWin) * 60)) * 100)
    }

    private func price(_ stats: Stats) -> String {
        guard let value = stats.xchCurrentPrice.value(for: settings.currency) else { return "—" }
        return String(format: "\(settings.currencySymbol)%.2f", value)
    }
}

// MARK: - Rows

private struct FarmerRow: View {
    let launcher: Launcher

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: launcher.pictureUrl, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(launcher.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !launcher.isPoolMember {
                        Chip(text: "OFF", color: .secondary)
                    }
                }
                Text(Fmt.shortHash(launcher.launcherId))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label(Fmt.number(Double(launcher.pointsPplns), digits: 0), systemImage: "pencil")
                    Label(Fmt.bytes(Double(launcher.estimatedSize)), systemImage: "externaldrive")
                    Label("\(launcher.difficulty)", systemImage: "shield.lefthalf.filled")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let launcher: Launcher

    private var medal: String {
        switch rank {
        case 1: return "1"
        case 2: return "2"
        default: return "3"
        }
    }

    private var medalColor: Color {
        switch rank {
        case 1: return Theme.brand
        case 2: return .secondary
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(medal)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(medalColor))
            Avatar(url: launcher.pictureUrl, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(launcher.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(Fmt.bytes(Double(launcher.estimatedSize)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Fmt.number(Double(launcher.pointsPplns), digits: 0) + " pts")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}
