import SwiftUI

struct PoolView: View {
    @State private var vm = PoolViewModel()
    @Environment(Localization.self) private var l10n
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
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
                            statsGrid(stats)
                            charts
                            wallets(stats)
                            nodes(stats)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("MENUITEMS.POOL.TEXT"))
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
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .refreshable { await vm.load() }
            .task {
                if vm.stats == nil { await vm.load() }
                vm.startLive()
            }
            .onDisappear { vm.stopLive() }
        }
    }

    private func statsGrid(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(
                title: l10n.t("FARMER.TABS.EST_TIME_PER_BLOCK"),
                value: Fmt.duration(minutes: Double(stats.estimateWin)),
                icon: "clock"
            )
            KPICard(
                title: l10n.t("BLOCKS.CURRENT_EFFORT"),
                value: Fmt.percent(stats.averageEffort ?? 0),
                icon: "gauge.with.dots.needle.67percent"
            )
            KPICard(
                title: l10n.t("BLOCKS.TOTAL_BLOCKS_FOUND"),
                value: "\(stats.rewardsBlocks)",
                icon: "square.stack.3d.up.fill"
            )
            KPICard(
                title: l10n.t("REWARDS.TOTAL_DISTRIBUTED"),
                value: Fmt.xch(Double(stats.rewardsAmount)) + " XCH",
                icon: "arrow.down.circle"
            )
        }
    }

    private var charts: some View {
        VStack(spacing: 16) {
            ChartCard(title: l10n.t("POOL_STATS.POOL_SPACE_7D")) {
                SeriesChart(
                    points: vm.poolSizeSeries
                        .filter { ($0.field ?? "global") == "global" }
                        .chartPoints(),
                    height: 170
                )
            }
            ChartCard(title: l10n.t("COMMON.MEMPOOL")) {
                SeriesChart(
                    points: vm.mempoolSeries
                        .filter { ($0.field ?? "full_pct") == "full_pct" }
                        .chartPoints(),
                    format: { "\(Int($0))%" },
                    height: 170
                )
            }
        }
    }

    private func wallets(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: l10n.t("POOL_STATUS.POOL_WALLETS"))
            ForEach(stats.poolWallets) { wallet in
                HStack(spacing: 10) {
                    Image(systemName: "creditcard")
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wallet.name.capitalized)
                            .font(.subheadline.weight(.medium))
                        Text(Fmt.xch(Double(wallet.amount)) + " XCH")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Chip(
                        text: wallet.synced ? l10n.t("COMMON.SYNCED") : l10n.t("COMMON.SYNCING"),
                        color: wallet.synced ? Theme.brand : Theme.warning
                    )
                }
                if wallet.id != stats.poolWallets.last?.id { Divider() }
            }
        }
        .card()
    }

    private func nodes(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: l10n.t("POOL_STATUS.POOL_NODES"))
            ForEach(stats.poolNodes) { node in
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Theme.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name.capitalized + (node.primary == true ? " · primary" : ""))
                            .font(.subheadline.weight(.medium))
                        Text([node.location, node.version].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Chip(
                        text: node.synced == true ? l10n.t("POOL_STATUS.OK") : l10n.t("POOL_STATUS.DEGRADED"),
                        color: node.synced == true ? Theme.brand : Theme.warning
                    )
                }
                if node.id != stats.poolNodes.last?.id { Divider() }
            }
        }
        .card()
    }
}
