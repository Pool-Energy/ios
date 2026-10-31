import Foundation
import Observation

@MainActor
@Observable
final class FarmerViewModel {
    let launcherId: String

    private(set) var detail: LauncherDetail?
    private(set) var sizeSeries: [TimeseriesPoint] = []
    private(set) var partials: [Partial] = []
    private(set) var harvesters: [Harvester] = []
    private(set) var blocks: [Block] = []
    private(set) var payouts: [Payout] = []

    private(set) var isLoading = true
    private(set) var error: String?

    private var live: LiveSocket?
    private var lastLiveRefresh = Date.distantPast

    init(launcherId: String) {
        self.launcherId = launcherId
    }

    func load() async {
        isLoading = detail == nil
        error = nil
        defer { isLoading = false }

        do {
            async let detailTask: LauncherDetail = APIClient.shared.get("launcher/\(launcherId)/")
            async let sizeTask: [TimeseriesPoint] = APIClient.shared.get(
                "launcher_size/",
                query: ["launcher": launcherId, "days": "7"]
            )
            async let partialsTask: Page<Partial> = APIClient.shared.page(
                "partial/",
                query: ["launcher": launcherId, "limit": "50", "offset": "0"]
            )
            async let harvestersTask: Page<Harvester> = APIClient.shared.page(
                "harvester/",
                query: ["launcher": launcherId, "limit": "50", "offset": "0"]
            )
            async let blocksTask: Page<Block> = APIClient.shared.page(
                "block/",
                query: ["farmed_by": launcherId, "limit": "50", "offset": "0"]
            )
            async let payoutsTask: Page<Payout> = APIClient.shared.page(
                "payout/",
                query: ["launcher": launcherId, "limit": "50", "offset": "0"]
            )

            let (detail, size, partials, harvesters, blocks, payouts) =
                try await (detailTask, sizeTask, partialsTask, harvestersTask, blocksTask, payoutsTask)

            self.detail = detail
            self.sizeSeries = size.filter { ($0.field ?? "size") == "size" }
            self.partials = partials.results
            self.harvesters = harvesters.results
            self.blocks = blocks.results
            self.payouts = payouts.results
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startLive() {
        guard live == nil else { return }
        let socket = LiveSocket(channel: "farmer/\(launcherId)")
        live = socket
        socket.start()
        Task { [weak self] in
            for await _ in socket.stream {
                guard let self else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastLiveRefresh) > 10 else { continue }
                self.lastLiveRefresh = now
                await self.load()
            }
        }
    }

    func stopLive() {
        live?.stop()
        live = nil
    }
}
