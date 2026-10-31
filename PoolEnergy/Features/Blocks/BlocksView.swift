import SwiftUI

struct BlocksView: View {
    @State private var vm = BlocksViewModel()
    @Environment(Localization.self) private var l10n

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = vm.error, vm.blocks.isEmpty {
                        ErrorRetryView(message: error) {
                            Task { await vm.load() }
                        }
                    } else if vm.blocks.isEmpty, vm.isLoading {
                        LoadingView()
                    } else {
                        if let stats = vm.stats {
                            summary(stats)
                        }
                        list
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("MENUITEMS.BLOCKS.TEXT"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiveBadge(title: "LIVE")
                }
            }
            .refreshable { await vm.load() }
            .task {
                if vm.blocks.isEmpty { await vm.load() }
                vm.startLive()
            }
            .onDisappear { vm.stopLive() }
        }
    }

    private func summary(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(
                title: l10n.t("BLOCKS.TOTAL_BLOCKS_FOUND"),
                value: "\(stats.rewardsBlocks)",
                icon: "square.stack.3d.up.fill"
            )
            KPICard(
                title: l10n.t("BLOCKS.CURRENT_EFFORT"),
                value: Fmt.percent(stats.averageEffort ?? 0),
                icon: "gauge.with.dots.needle.67percent"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.ESTIMATE_TO_WIN"),
                value: Fmt.duration(minutes: Double(stats.estimateWin)),
                icon: "clock"
            )
            KPICard(
                title: l10n.t("BLOCKS.POOL_REWARD"),
                value: Fmt.xch(Double(stats.rewardsAmount)) + " XCH",
                icon: "xmark.circle"
            )
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: l10n.t("BLOCKS.TITLE_FOUND"), trailing: "\(vm.total)")
            ForEach(vm.blocks) { block in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("#\(block.farmedHeight)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        Text(Fmt.epoch(Double(block.timestamp)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Avatar(url: block.farmedBy?.pictureUrl, size: 22)
                        Text(block.farmedBy?.displayName ?? "—")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(Fmt.bytes(Double(block.poolSpace ?? 0)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 6) {
                        Chip(text: "\(l10n.t("BLOCKS.POOL_EFFORT")) \(Fmt.percent(Double(block.launcherEffort ?? 0), digits: 0))", color: .secondary)
                        if let luck = block.luck, luck >= 0 {
                            Chip(
                                text: "\(l10n.t("BLOCKS.LUCKY")) \(luck)%",
                                color: luck >= 100 ? Theme.brand : Theme.warning
                            )
                        }
                    }
                }
                .card()
                .onAppear {
                    Task { await vm.loadMoreIfNeeded(current: block) }
                }
            }
        }
    }
}
