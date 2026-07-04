import Foundation
import Network
import CryptoKit

/// The mirror side (runs on the Mac). Given an endpoint (from Bonjour discovery in production, or a
/// direct host:port in tests), it opens a TLS-PSK connection, sends `.pullRequest`, and writes the
/// received `.noopbak` chunks to a temp file, returning its URL. Restoring that file into the DB is the
/// caller's job (via the app's `DataBackup.restore`), keeping this app-agnostic and testable.
public final class SyncClient {
    private let psk: SymmetricKey
    private let identity: String
    private let peerToPeer: Bool

    public init(psk: SymmetricKey, identity: String, peerToPeer: Bool = true) {
        self.psk = psk
        self.identity = identity
        self.peerToPeer = peerToPeer
    }

    /// Pull the peer's latest backup to a temp `.noopbak` file and return its URL. `timeout` bounds the
    /// TLS handshake; `idleTimeout` and `transferTimeout` bound the stream after the request is sent.
    public func pull(from endpoint: NWEndpoint,
                     timeout: TimeInterval = 15,
                     transferTimeout: TimeInterval = 120,
                     idleTimeout: TimeInterval = 30,
                     maxBytes: Int = 512 * 1024 * 1024) async throws -> URL {
        let params = SyncTLS.parameters(psk: psk, peerToPeer: peerToPeer)
        let conn = SyncConnection(NWConnection(to: endpoint, using: params))
        defer { conn.cancel() }
        try await conn.start(timeout: timeout)
        try await conn.send(.pullRequest)

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("noopsync-\(UUID().uuidString).noopbak")
        guard FileManager.default.createFile(atPath: tmp.path, contents: nil) else { throw SyncError.closed }

        do {
            let handle = try FileHandle(forWritingTo: tmp)
            defer { try? handle.close() }
            let started = Date()
            var received = 0
            var hasher = SHA256()
            var expectedDigest: Data?

            loop: while true {
                let elapsed = Date().timeIntervalSince(started)
                let remaining = transferTimeout - elapsed
                guard remaining > 0 else { throw SyncError.timedOut }
                let nextTimeout = max(0.1, min(idleTimeout, remaining))
                switch try await conn.receive(timeout: nextTimeout) {
                case .backupChunk(let chunk):
                    received += chunk.count
                    guard received <= maxBytes else { throw SyncError.transferTooLarge }
                    hasher.update(data: chunk)
                    try handle.write(contentsOf: chunk)
                case .backupDigest(let digest):
                    expectedDigest = digest
                case .done:
                    break loop
                default:
                    continue               // ignore messages that aren't part of the history pull
                }
            }

            if let expectedDigest, Data(hasher.finalize()) != expectedDigest {
                throw SyncError.checksumMismatch
            }
            return tmp
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw error
        }
    }
}
