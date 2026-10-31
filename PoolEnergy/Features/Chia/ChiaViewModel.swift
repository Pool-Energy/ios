import Foundation
import Observation

enum ChiaMetric: String, CaseIterable, Identifiable {
    case netspace, mempool, price

    var id: String { rawValue }

    var path: String {
        switch self {
        case .netspace: return "stats/netspace/"
        case .mempool: return "stats/mempool/"
        case .price: return "stats/xchprice/"
        }
    }
}

@MainActor
@Observable
final class ChiaViewModel {
    private(set) var stats: Stats?
    private(set) var series: [TimeseriesPoint] = []
    private(set) var isLoading = false
    private(set) var isLoadingSeries = false
    private(set) var error: String?

    var metric: ChiaMetric = .netspace
    var days: Int = 7

    private var live: LiveSocket?
    private var lastRefresh = Date.distantPast

    func load() async {
        isLoading = stats == nil
        error = nil
        defer { isLoading = false }

        do {
            async let statsTask: Stats = APIClient.shared.get("stats")
            async let seriesTask: [TimeseriesPoint] = APIClient.shared.get(
                metric.path,
                query: ["days": "\(days)"]
            )
            let (stats, series) = try await (statsTask, seriesTask)
            self.stats = stats
            self.series = series
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSeries() async {
        isLoadingSeries = true
        defer { isLoadingSeries = false }
        do {
            let points: [TimeseriesPoint] = try await APIClient.shared.get(
                metric.path,
                query: ["days": "\(days)"]
            )
            series = points
        } catch {
            series = []
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
