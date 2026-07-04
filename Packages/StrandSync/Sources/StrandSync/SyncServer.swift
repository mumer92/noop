import Foundation
import Network
import CryptoKit

/// The source side (runs on the iPhone). Advertises a Bonjour `_noopsync._tcp` service secured with
/// TLS-PSK and, when an authenticated peer sends `.pullRequest`, streams the current `.noopbak` as
/// `.backupChunk`s followed by `.done`. The backup is produced by an injected closure so this stays
/// app-agnostic and testable.
public final class SyncServer {
    private let params: NWParameters
    private let useBonjour: Bool
    private let advert: () -> SyncAdvert
    private let makeBackup: () async -> URL?
    private var listener: NWListener?

    /// The bound port once the listener is ready (used by loopback tests / direct connections).
    public private(set) var port: UInt16?

    public init(psk: SymmetricKey, identity: String, useBonjour: Bool = true, peerToPeer: Bool = true,
                advert: @escaping () -> SyncAdvert, makeBackup: @escaping () async -> URL?) {
        self.params = SyncTLS.parameters(psk: psk, peerToPeer: peerToPeer)
        self.useBonjour = useBonjour
        self.advert = advert
        self.makeBackup = makeBackup
    }

    public func start() throws {
        let listener = try NWListener(using: params)
        if useBonjour {
            listener.service = NWListener.Service(
                type: "_noopsync._tcp",
                txtRecord: NWTXTRecord(advert().txtDictionary()))
        }
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            Task { await self.serve(conn) }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state { self?.port = listener.port?.rawValue }
        }
        listener.start(queue: SyncConnection.queue)
        self.listener = listener
    }

    private func serve(_ nwconn: NWConnection) async {
        let conn = SyncConnection(nwconn)
        defer { conn.cancel() }
        do {
            try await conn.start()
            guard case .pullRequest = try await conn.receive() else { return }
            guard let url = await makeBackup() else { return }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let chunkSize = 256 * 1024
            var hasher = SHA256()
            while true {
                let chunk = try handle.read(upToCount: chunkSize) ?? Data()
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
                try await conn.send(.backupChunk(chunk))
            }
            try await conn.send(.backupDigest(Data(hasher.finalize())))
            try await conn.send(.done)
        } catch { /* peer dropped / handshake failed — nothing served */ }
    }

    public func stop() { listener?.cancel(); listener = nil; port = nil }
}
