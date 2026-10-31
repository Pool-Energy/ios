import SwiftUI
import Charts

struct FarmerView: View {
    let launcherId: String

    @State private var vm: FarmerViewModel
    @Environment(Localization.self) private var l10n
    @State private var tab: FarmerTab = .overview

    init(launcherId: String) {
        self.launcherId = launcherId
        _vm = State(initialValue: FarmerViewModel(launcherId: launcherId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = vm.error, vm.detail == nil {
                    ErrorRetryView(message: error) {
                        Task { await vm.load() }
                    }
                } else if vm.detail == nil, vm.isLoading {
                    LoadingView()
                } else if let detail = vm.detail {
                    header(detail)
                    stats(detail)
                    sizeChart
                    tabs(detail)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 96)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vm.detail?.displayName ?? l10n.t("BREADCRUMBS.FARMER"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task {
            if vm.detail == nil { await vm.load() }
            vm.startLive()
        }
        .onDisappear { vm.stopLive() }
    }

    // MARK: Header

    private func header(_ detail: LauncherDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Avatar(url: detail.pictureUrl, size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    Text(detail.launcherId)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Chip(
                            text: detail.isPoolMember
                                ? l10n.t("FARMER.STATS.ONLINE")
                                : l10n.t("FARMER.STATS.OFFLINE"),
                            color: detail.isPoolMember ? Theme.brand : .secondary
                        )
                        if let difficulty = detail.customDifficulty, !difficulty.isEmpty {
                            Chip(text: difficulty, color: .secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("FARMER.STATS.ESTIMATED_SIZE"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Fmt.bytes(Double(detail.estimatedSize)))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(l10n.t("FARMER.STATS.UTILIZATION_SPACE"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Fmt.percent(detail.share * 100, digits: 2))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .card()
    }

    // MARK: Stats

    private func stats(_ detail: LauncherDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(
                title: l10n.t("FARMER.TABS.JOINED_AT"),
                value: Fmt.date(detail.joinedAt),
                icon: "calendar"
            )
            KPICard(
                title: l10n.t("FARMER.TABS.POINTS_24H"),
                value: detail.partials.map { Fmt.number(Double($0.points), digits: 0) } ?? "—",
                icon: "pencil"
            )
            KPICard(
                title: l10n.t("FARMER.TABS.DIFFICULTY"),
                value: "\(detail.difficulty)",
                icon: "shield.lefthalf.filled"
            )
            KPICard(
                title: l10n.t("FARMER.TABS.ESTIMATE_TO_WIN"),
                value: Fmt.duration(minutes: Double(detail.currentEtw ?? 0)),
                icon: "clock"
            )
            KPICard(
                title: l10n.t("FARMER.TABS.CURRENT_EFFORT"),
                value: Fmt.percent(detail.currentEffort ?? 0),
                icon: "gauge.with.dots.needle.67percent"
            )
            KPICard(
                title: l10n.t("COMMON.BLOCKS"),
                value: "\(detail.blocks?.total ?? 0)",
                icon: "square.stack.3d.up.fill"
            )
        }
    }

    // MARK: Chart

    private var sizeChart: some View {
        ChartCard(title: l10n.t("FARMER.STATS.ESTIMATED_SIZE")) {
            if sizePoints.isEmpty {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_DATA"))
            } else {
                Chart(sizePoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Size", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brand.opacity(0.35), Theme.brand.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Size", point.value)
                    )
                    .foregroundStyle(Theme.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let raw = value.as(Double.self) {
                                Text(Fmt.bytes(raw))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private struct ChartPoint: Identifiable {
        let id: Date
        let date: Date
        let value: Double
    }

    private var sizePoints: [ChartPoint] {
        vm.sizeSeries.compactMap { point in
            guard let date = point.date else { return nil }
            return ChartPoint(id: date, date: date, value: point.value)
        }
    }

    // MARK: Tabs

    private func tabs(_ detail: LauncherDetail) -> some View {
        VStack(spacing: 16) {
            Picker("", selection: $tab) {
                ForEach(FarmerTab.allCases) { item in
                    Text(label(for: item)).tag(item)
                }
            }
            .pickerStyle(.segmented)

            switch tab {
            case .overview: overview(detail)
            case .partials: partialsList
            case .harvesters: harvestersList
            case .blocks: blocksList
            case .rewards: rewardsList
            }
        }
    }

    private func label(for tab: FarmerTab) -> String {
        switch tab {
        case .overview: return l10n.t("FARMER.TABS.OVERVIEW")
        case .partials: return l10n.t("FARMER.TABS.PARTIALS")
        case .harvesters: return l10n.t("FARMER.TABS.HARVESTERS")
        case .blocks: return l10n.t("FARMER.TABS.BLOCKS")
        case .rewards: return l10n.t("FARMER.TABS.REWARDS")
        }
    }

    private func overview(_ detail: LauncherDetail) -> some View {
        VStack(spacing: 12) {
            if let partials = detail.partials {
                VStack(spacing: 10) {
                    InfoRow(label: l10n.t("FARMER.TABS.PARTIALS_24H"), value: "\(partials.total)", monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.SUCCESSFUL_PARTIALS"), value: "\(partials.successful)", monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.FAILED_PARTIALS"), value: "\(partials.failed)", monospaced: true)
                    InfoRow(
                        label: l10n.t("FARMER.TABS.PERFORMANCE"),
                        value: Fmt.percent(partials.performance ?? 0),
                        monospaced: true
                    )
                    InfoRow(label: l10n.t("FARMER.TABS.HARVESTER"), value: "\(partials.harvesters)", monospaced: true)
                }
                .card()
            }

            if let rewards = detail.rewards {
                VStack(spacing: 10) {
                    InfoRow(label: l10n.t("FARMER.TABS.LAST_24_HOURS"), value: xch(rewards.last24h), monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.LAST_7_DAYS"), value: xch(rewards.last7d), monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.LAST_30_DAYS"), value: xch(rewards.last30d), monospaced: true)
                }
                .card()
            }

            if let fee = detail.fee {
                VStack(spacing: 10) {
                    InfoRow(
                        label: l10n.t("FARMERS.STATS.CURRENT_FEE"),
                        value: Fmt.percent((fee.finalFee ?? fee.pool ?? 0) * 100),
                        monospaced: true
                    )
                    if let pool = fee.pool {
                        InfoRow(label: "PPLNS", value: Fmt.percent(pool * 100), monospaced: true)
                    }
                    if let days = fee.stayLengthDays {
                        InfoRow(label: l10n.t("FARMER.TABS.JOINED_AT"), value: "\(days) " + l10n.t("COMMON.DAYS"), monospaced: true)
                    }
                }
                .card()
            }

            if let payout = detail.payout {
                VStack(spacing: 10) {
                    InfoRow(label: l10n.t("FARMER.TABS.TOTAL_PAID"), value: Fmt.xch(payout.totalPaid ?? 0) + " XCH", monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.TOTAL_UNPAID"), value: Fmt.xch(payout.totalUnpaid ?? 0) + " XCH", monospaced: true)
                    InfoRow(label: l10n.t("FARMER.TABS.TOTAL_TRANSACTIONS"), value: "\(payout.totalTransactions ?? 0)", monospaced: true)
                }
                .card()
            }
        }
    }

    private var partialsList: some View {
        VStack(spacing: 10) {
            if vm.partials.isEmpty {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_PARTIAL"))
            } else {
                ForEach(vm.partials.prefix(30)) { partial in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Fmt.epoch(Double(partial.timestamp)))
                                .font(.subheadline.weight(.medium))
                            Text("\(l10n.t("COMMON.DIFFICULTY")) \(partial.difficulty) · \(partial.plotSize.map { "k\($0)" } ?? "—")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Chip(
                                text: partial.error == nil
                                    ? l10n.t("FARMER.TABS.SUCCESS")
                                    : (partial.error ?? "—"),
                                color: partial.error == nil ? Theme.brand : Theme.danger
                            )
                            if let taken = partial.timeTaken {
                                Text(String(format: "%.2f s", taken))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    if partial.id != vm.partials.prefix(30).last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private var harvestersList: some View {
        VStack(spacing: 12) {
            if vm.harvesters.isEmpty {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_HARVESTER"))
            } else {
                ForEach(vm.harvesters) { harvester in
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(Theme.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(harvester.name ?? Fmt.shortHash(harvester.harvester))
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(Fmt.shortHash(harvester.harvester, prefix: 10, suffix: 6))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Chip(text: harvester.version ?? "—", color: .secondary)
                    }
                    if harvester.id != vm.harvesters.last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private var blocksList: some View {
        VStack(spacing: 12) {
            if vm.blocks.isEmpty {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_BLOCK"))
            } else {
                ForEach(vm.blocks.prefix(30)) { block in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(block.farmedHeight)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text(Fmt.epoch(Double(block.timestamp)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Fmt.bytes(Double(block.poolSpace ?? 0)))
                                .font(.subheadline)
                                .monospacedDigit()
                            Text("\(l10n.t("BLOCKS.POOL_EFFORT")) \(Fmt.percent(Double(block.launcherEffort ?? 0), digits: 0))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if block.id != vm.blocks.prefix(30).last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private var rewardsList: some View {
        VStack(spacing: 12) {
            if vm.payouts.isEmpty {
                EmptyStateView(text: l10n.t("FARMER.TABS.NO_PAYOUT"))
            } else {
                ForEach(vm.payouts.prefix(30)) { payout in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Fmt.dateTime(payout.datetime))
                                .font(.subheadline.weight(.medium))
                            Text("\(payout.blocks.count) " + l10n.t("COMMON.BLOCKS"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Fmt.xch(Double(payout.amount)) + " XCH")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text("\(l10n.t("COMMON.FEE")) \(Fmt.xch(Double(payout.fee)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    if payout.id != vm.payouts.prefix(30).last?.id { Divider() }
                }
            }
        }
        .card()
    }

    private func xch(_ mojos: Int64?) -> String {
        guard let mojos, mojos > 0 else { return "—" }
        return Fmt.xch(Double(mojos)) + " XCH"
    }
}

enum FarmerTab: String, CaseIterable, Identifiable {
    case overview, partials, harvesters, blocks, rewards
    var id: String { rawValue }
}
