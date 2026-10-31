import SwiftUI

struct ChiaView: View {
    @State private var vm = ChiaViewModel()
    @Environment(Localization.self) private var l10n
    @Environment(AppSettings.self) private var settings

    private let ranges = [1, 7, 30]

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
                        }
                        chartCard
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("MENUITEMS.CHIA.TEXT"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ranges, id: \.self) { range in
                            Button("\(range) \(l10n.t("COMMON.DAYS"))") {
                                vm.days = range
                                Task { await vm.loadSeries() }
                            }
                        }
                    } label: {
                        Label("\(vm.days) \(l10n.t("COMMON.DAYS"))", systemImage: "calendar")
                    }
                }
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
                title: l10n.t("POOL_STATUS.BLOCKCHAIN_HEIGHT"),
                value: Fmt.number(Double(stats.blockchainHeight), digits: 0),
                icon: "cube"
            )
            KPICard(
                title: l10n.t("POOL_STATS.NETSPACE_7D"),
                value: Fmt.bytes(Double(stats.blockchainSpace)),
                icon: "network"
            )
            KPICard(
                title: l10n.t("COMMON.MEMPOOL"),
                value: "\(stats.blockchainMempoolFullPct)%",
                subtitle: stats.blockchainDuststorm ? l10n.t("FARMERS.STATS.DUST_STORM") : nil,
                icon: "tray.full"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.XCH_PRICE"),
                value: price(stats),
                icon: "chart.line.uptrend.xyaxis"
            )
            KPICard(
                title: l10n.t("FARMERS.STATS.POOL_SPACE"),
                value: Fmt.bytes(Double(stats.poolSpace)),
                icon: "externaldrive"
            )
            KPICard(
                title: l10n.t("POOL_STATUS.POOL_SHARE"),
                value: share(stats),
                icon: "chart.pie"
            )
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: Binding(
                get: { vm.metric },
                set: { metric in
                    vm.metric = metric
                    Task { await vm.loadSeries() }
                }
            )) {
                Text("Netspace").tag(ChiaMetric.netspace)
                Text(l10n.t("COMMON.MEMPOOL")).tag(ChiaMetric.mempool)
                Text("XCH").tag(ChiaMetric.price)
            }
            .pickerStyle(.segmented)

            if vm.isLoadingSeries {
                LoadingView()
            } else {
                SeriesChart(points: chartPoints, format: format(for: vm.metric))
            }
        }
        .card()
    }

    private var chartPoints: [ChartPoint] {
        let filtered = vm.series.filter { point in
            switch vm.metric {
            case .netspace:
                return (point.field ?? "size") == "size"
            case .mempool:
                return (point.field ?? "full_pct") == "full_pct"
            case .price:
                return (point.field ?? settings.currency) == settings.currency
            }
        }
        // The netspace timeseries is stored in MiB by the pool server.
        let scaled = vm.metric == .netspace
            ? filtered.map { TimeseriesPoint(datetime: $0.datetime, value: $0.value * 1_048_576, field: $0.field) }
            : filtered
        return scaled.chartPoints()
    }

    private func format(for metric: ChiaMetric) -> (Double) -> String {
        switch metric {
        case .netspace:
            return { Fmt.bytes($0) }
        case .mempool:
            return { "\(Int($0))%" }
        case .price:
            return { String(format: "$%.2f", $0) }
        }
    }

    private func price(_ stats: Stats) -> String {
        guard let value = stats.xchCurrentPrice.value(for: settings.currency) else { return "—" }
        return String(format: "\(settings.currencySymbol)%.2f", value)
    }

    private func share(_ stats: Stats) -> String {
        guard stats.blockchainSpace > 0 else { return "—" }
        let share = Double(stats.poolSpace) / Double(stats.blockchainSpace) * 100
        return Fmt.percent(share, digits: 3)
    }
}
