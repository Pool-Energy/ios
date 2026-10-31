import SwiftUI

struct RewardsView: View {
    @State private var vm = RewardsViewModel()
    @Environment(Localization.self) private var l10n
    @State private var selected: Payout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = vm.error, vm.payouts.isEmpty {
                        ErrorRetryView(message: error) {
                            Task { await vm.load() }
                        }
                    } else if vm.payouts.isEmpty, vm.isLoading {
                        LoadingView()
                    } else {
                        summary
                        list
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("MENUITEMS.REWARDS.TEXT"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiveBadge(title: "LIVE")
                }
            }
            .refreshable { await vm.load() }
            .task {
                if vm.payouts.isEmpty { await vm.load() }
                vm.startLive()
            }
            .onDisappear { vm.stopLive() }
            .sheet(item: $selected) { payout in
                PayoutDetailView(payout: payout, viewModel: vm)
            }
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            KPICard(
                title: l10n.t("REWARDS.TOTAL_DISTRIBUTED"),
                value: Fmt.xch(vm.loadedAmount) + " XCH",
                subtitle: "\(vm.payouts.count) \(l10n.t("COMMON.BLOCKS"))",
                icon: "arrow.down.circle"
            )
            KPICard(
                title: l10n.t("REWARDS.TOTAL_FEE"),
                value: Fmt.xch(vm.loadedFees) + " XCH",
                icon: "percent"
            )
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: l10n.t("REWARDS.TITLE"), trailing: "\(vm.payouts.count)")
            ForEach(vm.payouts) { payout in
                Button {
                    selected = payout
                    Task { await vm.loadAddresses(for: payout) }
                } label: {
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
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onAppear {
                    Task { await vm.loadMoreIfNeeded(current: payout) }
                }
                if payout.id != vm.payouts.last?.id { Divider() }
            }
        }
        .card()
    }
}

struct PayoutDetailView: View {
    let payout: Payout
    let viewModel: RewardsViewModel
    @Environment(Localization.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        InfoRow(label: l10n.t("COMMON.DATETIME"), value: Fmt.dateTime(payout.datetime))
                        InfoRow(label: l10n.t("COMMON.AMOUNT"), value: Fmt.xch(Double(payout.amount)) + " XCH", monospaced: true)
                        InfoRow(label: l10n.t("COMMON.FEE"), value: Fmt.xch(Double(payout.fee)) + " XCH", monospaced: true)
                        InfoRow(label: l10n.t("COMMON.BLOCKS"), value: "\(payout.blocks.count)", monospaced: true)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: l10n.t("COMMON.ADDRESS"))
                        if viewModel.isLoadingAddresses {
                            LoadingView()
                        } else if viewModel.addresses.isEmpty {
                            EmptyStateView(text: l10n.t("FARMER.TABS.NO_PAYOUT"))
                        } else {
                            ForEach(viewModel.addresses) { address in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(address.launcher?.displayName ?? Fmt.shortHash(address.puzzleHash, prefix: 10, suffix: 6))
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Text(Fmt.shortHash(address.puzzleHash, prefix: 12, suffix: 8))
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(Fmt.xch(Double(address.amount)) + " XCH")
                                            .font(.subheadline.weight(.semibold))
                                            .monospacedDigit()
                                        Text(address.transaction?.confirmedBlockIndex == nil
                                             ? l10n.t("COMMON.PENDING")
                                             : l10n.t("COMMON.CONFIRMED"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if address.id != viewModel.addresses.last?.id { Divider() }
                            }
                        }
                    }
                    .card()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(l10n.t("FARMER.TABS.REWARDS"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t("COMMON.CLOSE")) { dismiss() }
                }
            }
        }
    }
}
