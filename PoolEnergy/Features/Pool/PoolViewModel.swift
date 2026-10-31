import Foundation
import Observation

@MainActor
@Observable
final class PoolViewModel {
    private(set) var stats: Stats?
    private(set) var poolSizeSeries: [TimeseriesPoint] = []
    private(set) var mempoolSeries: [TimeseriesPoint] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private var live: LiveSocket?
    private var lastRefresh = Date.distantPast

    func load() async {
        isLoading = stats == nil
        error = nil
        defer { isLoading = false }

        do {
            async let statsTask: Stats = APIClient.shared.get("stats")
            async let sizeTask: [TimeseriesPoint] = APIClient.shared.get("pool_size/", query: ["days": "7"])
            async let mempoolTask: [TimeseriesPoint] = APIClient.shared.get("stats/mempool/", query: ["days": "7"])
            let (stats, size, mempool) = try await (statsTask, sizeTask, mempoolTask)
            self.stats = stats
            self.poolSizeSeries = size
            self.mempoolSeries = mempool
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startLive() {
        guard live == nil else { return }
        let socket = LiveSocket(channel: "pool_status")
        live = socket
        socket.start()
        Task { [weak self] in
            for await _ in socket.stream {
                guard let self else { return }
                guard Date().timeIntervalSince(self.lastRefresh) > 15 else { continue }
                self.lastRefresh = Date()
                do {
                    self.stats = try await APIClient.shared.get("stats")
                } catch {
                    // Keep the last snapshot.
                }
            }
        }
    }

    func stopLive() {
        live?.stop()
        live = nil
    }
}
