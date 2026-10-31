import Foundation
import Observation

@MainActor
@Observable
final class BlocksViewModel {
    private(set) var stats: Stats?
    private(set) var blocks: [Block] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private var nextURL: String?
    private var live: LiveSocket?
    private var lastRefresh = Date.distantPast

    private let pageSize = 30

    func load() async {
        isLoading = blocks.isEmpty
        error = nil
        defer { isLoading = false }

        do {
            async let statsTask: Stats = APIClient.shared.get("stats")
            async let blocksTask: Page<Block> = APIClient.shared.page(
                "block/",
                query: ["limit": "\(pageSize)", "offset": "0"]
            )
            let (stats, page) = try await (statsTask, blocksTask)
            self.stats = stats
            self.blocks = page.results
            self.nextURL = page.next
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current block: Block) async {
        guard let nextURL, blocks.suffix(5).contains(where: { $0.id == block.id }) else { return }
        do {
            let page: Page<Block> = try await APIClient.shared.page(from: nextURL)
            blocks.append(contentsOf: page.results)
            self.nextURL = page.next
        } catch {
            self.nextURL = nil
        }
    }

    func startLive() {
        guard live == nil else { return }
        let socket = LiveSocket(channel: "blocks")
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
