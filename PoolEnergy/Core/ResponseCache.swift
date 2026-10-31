import Foundation

/// Deduplicates identical GET requests and keeps short-lived responses so the
/// app does not burn the public API's anonymous rate limit when several screens
/// (or a live refresh) ask for the same resource at once.
actor ResponseCache {
    static let shared = ResponseCache()

    private var storage: [URL: (date: Date, data: Data)] = [:]
    private var inflight: [URL: Task<Data, Error>] = [:]

    func data(for url: URL, ttl: TimeInterval, load: @escaping () async throws -> Data) async throws -> Data {
        if let entry = storage[url], Date().timeIntervalSince(entry.date) < ttl {
            return entry.data
        }

        if let task = inflight[url] {
            return try await task.value
        }

        let task = Task { try await load() }
        inflight[url] = task
        defer { inflight[url] = nil }

        let data = try await task.value
        storage[url] = (Date(), data)
        return data
    }

    func invalidate() {
        storage.removeAll()
    }
}
