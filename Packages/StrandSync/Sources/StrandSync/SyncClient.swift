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
    /// TLS handshake (a wrong PSK or an unreachable peer fails after it rather than waiting forever).
    public func pull(from endpoint: NWEndpoint, timeout: TimeInterval = 15) async throws -> URL {
        let params = SyncTLS.parameters(psk: psk, peerToPeer: peerToPeer)
        let conn = SyncConnection(NWConnection(to: endpoint, using: params))
        defer { conn.cancel() }
        try await conn.start(timeout: timeout)
        try await conn.send(.pullRequest)

        var out = Data()
        loop: while true {
            switch try await conn.receive() {
            case .backupChunk(let chunk): out.append(chunk)
            case .done: break loop
            default: continue               // ignore messages that aren't part of the history pull
            }
        }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("noopsync-\(UUID().uuidString).noopbak")
        try out.write(to: tmp)
        return tmp
    }
}
