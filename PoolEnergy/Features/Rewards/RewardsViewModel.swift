import Foundation
import Observation

@MainActor
@Observable
final class RewardsViewModel {
    private(set) var payouts: [Payout] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var total = 0
    private(set) var error: String?
    private(set) var addresses: [PayoutAddress] = []
    private(set) var isLoadingAddresses = false

    private var nextURL: String?
    private var live: LiveSocket?
    private var lastRefresh = Date.distantPast
    private let pageSize = 30

    var loadedAmount: Double {
        payouts.reduce(0) { $0 + Double($1.amount) }
    }

    var loadedFees: Double {
        payouts.reduce(0) { $0 + Double($1.fee) }
    }

    func load() async {
        isLoading = payouts.isEmpty
        error = nil
        defer { isLoading = false }

        do {
            let page: Page<Payout> = try await APIClient.shared.page(
                "payout/",
                query: ["limit": "\(pageSize)", "offset": "0"]
            )
            payouts = page.results
            total = page.count
            nextURL = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current payout: Payout) async {
        guard let nextURL, !isLoadingMore else { return }
        guard payouts.suffix(5).contains(where: { $0.id == payout.id }) else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page: Page<Payout> = try await APIClient.shared.page(from: nextURL)
            payouts.append(contentsOf: page.results)
            self.nextURL = page.next
        } catch {
            self.nextURL = nil
        }
    }

    func loadAddresses(for payout: Payout) async {
        isLoadingAddresses = true
        defer { isLoadingAddresses = false }
        addresses = []
        do {
            let page: Page<PayoutAddress> = try await APIClient.shared.page(
                "payoutaddress/",
                query: ["payout": "\(payout.id)", "limit": "100", "offset": "0"]
            )
            addresses = page.results
        } catch {
            addresses = []
        }
    }

    func startLive() {
        guard live == nil else { return }
        let socket = LiveSocket(channel: "rewards")
        live = socket
        socket.start()
        Task { [weak self] in
            for await _ in socket.stream {
                guard let self else { return }
                guard Date().timeIntervalSince(self.lastRefresh) > 8 else { continue }
                self.lastRefresh = Date()
                await self.load()
            }
        }
    }

    func stopLive() {
        live?.stop()
        live = nil
    }
}
