import Foundation

/// Minimal WebSocket client for the pool live feeds.
///
/// The dashboard reloads its data when an event arrives, so the stream only
/// yields a signal: no payload decoding needed on the iOS side for now.
final class LiveSocket {
    let channel: String
    let stream: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation
    private let session = URLSession(configuration: .default)
    private var listenTask: Task<Void, Never>?

    init(channel: String, host: URL = URL(string: "wss://pool.energy")!) {
        self.channel = channel
        var captured: AsyncStream<Void>.Continuation!
        self.stream = AsyncStream { captured = $0 }
        self.continuation = captured
        self.host = host
    }

    private let host: URL

    private var url: URL? {
        var components = URLComponents(url: host, resolvingAgainstBaseURL: false)
        components?.scheme = "wss"
        components?.path = "/ws/\(channel)/"
        return components?.url
    }

    func start() {
        guard listenTask == nil, let url else { return }
        listenTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let socket = self.session.webSocketTask(with: url)
                socket.resume()
                do {
                    while !Task.isCancelled {
                        _ = try await socket.receive()
                        self.continuation.yield(())
                    }
                } catch {
                    // Connection closed or network lost: retry shortly.
                }
                socket.cancel(with: .goingAway, reason: nil)
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        continuation.finish()
    }

    deinit {
        listenTask?.cancel()
        continuation.finish()
    }
}
