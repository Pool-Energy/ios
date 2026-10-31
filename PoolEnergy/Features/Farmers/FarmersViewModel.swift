import Foundation
import Observation

@MainActor
@Observable
final class FarmersViewModel {
    private(set) var stats: Stats?
    private(set) var launchers: [Launcher] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: String?

    var search = "" {
        didSet { scheduleSearch() }
    }

    private var nextURL: String?
    private var searchTask: Task<Void, Never>?
    private var live: LiveSocket?
    private var lastLiveRefresh = Date.distantPast

    private let pageSize = 25

    var totalFarmers: Int {
        stats?.farmers ?? launchers.count
    }

    func load() async {
        isLoading = launchers.isEmpty
        error = nil
        defer { isLoading = false }

        do {
            async let statsTask: Stats = APIClient.shared.get("stats")
            async let pageTask: Page<Launcher> = APIClient.shared.page("launcher/", query: listQuery)
            let (stats, page) = try await (statsTask, pageTask)
            self.stats = stats
            self.launchers = page.results
            self.nextURL = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshQuietly() async {
        do {
            async let statsTask: Stats = APIClient.shared.get("stats")
            async let pageTask: Page<Launcher> = APIClient.shared.page("launcher/", query: listQuery)
            let (stats, page) = try await (statsTask, pageTask)
            self.stats = stats
            self.launchers = page.results
            self.nextURL = page.next
            self.error = nil
        } catch {
            // Keep the last good snapshot on background refresh failures.
        }
    }

    func loadMoreIfNeeded(current item: Launcher) async {
        guard let nextURL, !isLoadingMore else { return }
        guard launchers.suffix(5).contains(where: { $0.id == item.id }) else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page: Page<Launcher> = try await APIClient.shared.page(from: nextURL)
            launchers.append(contentsOf: page.results)
            self.nextURL = page.next
        } catch {
            self.nextURL = nil
        }
    }

    func startLive() {
        guard live == nil else { return }
        let socket = LiveSocket(channel: "farmers")
        live = socket
        socket.start()
        Task { [weak self] in
            for await _ in socket.stream {
                guard let self else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastLiveRefresh) > 8 else { continue }
                self.lastLiveRefresh = now
                await self.refreshQuietly()
            }
        }
    }

    func stopLive() {
        live?.stop()
        live = nil
    }

    private var searchQuery: [String: String] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? [:] : ["search": term]
    }

    private var listQuery: [String: String] {
        var query = [
            "is_pool_member": "true",
            "ordering": "-points_pplns",
            "limit": "\(pageSize)",
            "offset": "0",
        ]
        query.merge(searchQuery) { _, new in new }
        return query
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.load()
        }
    }
}
