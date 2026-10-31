import Foundation

/// Serialises outgoing requests.
///
/// The Pool.Energy edge rejects concurrent requests from the same client with a
/// `429` (a single parallel burst is enough to trigger it), so the app funnels
/// every call through this gate instead of firing `async let` bursts.
actor RequestGate {
    static let shared = RequestGate()

    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isBusy {
            isBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            isBusy = false
        }
    }
}
