import Foundation
import Network

public enum SyncError: Error { case closed, noBackup, badMessage, timedOut }

/// A resume-once guard so an `NWConnection` state handler (which can fire multiple states) never
/// resumes a continuation twice.
private final class OnceFlag: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()
    func fire() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
}

/// An async, framed-message wrapper over a single `NWConnection`. Sends/receives `SyncMessage`s using
/// `SyncFraming`. Not tied to the app — pure transport, so the whole transfer is testable over loopback.
public final class SyncConnection {
    private let conn: NWConnection
    private var inbound = Data()
    static let queue = DispatchQueue(label: "noop.localsync.conn")

    public init(_ conn: NWConnection) { self.conn = conn }

    /// Start the connection and resolve once TLS (incl. the PSK handshake) is ready, or throw on failure.
    /// A `timeout` guards against a stalled handshake so this can never hang forever.
    public func start(timeout: TimeInterval = 15) async throws {
        let once = OnceFlag()
        let conn = self.conn   // capture the Sendable NWConnection, not self, in the @Sendable closures
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:            if once.fire() { cont.resume() }
                case .failed(let e):    if once.fire() { cont.resume(throwing: e) }
                case .cancelled:        if once.fire() { cont.resume(throwing: SyncError.closed) }
                default: break
                }
            }
            conn.start(queue: Self.queue)
            Self.queue.asyncAfter(deadline: .now() + timeout) {
                if once.fire() { conn.cancel(); cont.resume(throwing: SyncError.timedOut) }
            }
        }
    }

    public func send(_ message: SyncMessage) async throws {
        let framed = SyncFraming.frame(message.encoded())
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: framed, completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    /// Receive the next complete framed `SyncMessage`, reading more bytes as needed.
    public func receive() async throws -> SyncMessage {
        while true {
            if let payload = SyncFraming.decode(&inbound) {
                guard let msg = SyncMessage.decode(payload) else { throw SyncError.badMessage }
                return msg
            }
            inbound.append(try await receiveChunk())
        }
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, err in
                if let err { cont.resume(throwing: err); return }
                if let data, !data.isEmpty { cont.resume(returning: data); return }
                if isComplete { cont.resume(throwing: SyncError.closed); return }
                cont.resume(returning: Data())
            }
        }
    }

    public func cancel() { conn.cancel() }
}
