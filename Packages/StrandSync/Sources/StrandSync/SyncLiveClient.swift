import Foundation
import Network
import CryptoKit

/// The live channel subscriber (Mac). Holds a persistent TLS-PSK connection to the paired iPhone,
/// sends `.subscribeLive`, and forwards each decoded `LiveSnapshot` / `historyChanged` via callbacks.
/// Reports link up/down so the app can revert to "not connected" when the stream ends.
public final class SyncLiveClient: @unchecked Sendable {
    private let params: NWParameters
    private let onSnapshot: @Sendable (LiveSnapshot) -> Void
    private let onHistoryChanged: @Sendable (UInt64) -> Void
    private let onConnectionChange: @Sendable (Bool) -> Void
    private let onSettings: @Sendable (SyncSettings) -> Void
    private var conn: SyncConnection?
    private var task: Task<Void, Never>?

    public init(psk: SymmetricKey, peerToPeer: Bool = false,
                onSnapshot: @escaping @Sendable (LiveSnapshot) -> Void,
                onHistoryChanged: @escaping @Sendable (UInt64) -> Void = { _ in },
                onConnectionChange: @escaping @Sendable (Bool) -> Void = { _ in },
                onSettings: @escaping @Sendable (SyncSettings) -> Void = { _ in }) {
        self.params = SyncTLS.parameters(psk: psk, peerToPeer: peerToPeer)
        self.onSnapshot = onSnapshot
        self.onHistoryChanged = onHistoryChanged
        self.onConnectionChange = onConnectionChange
        self.onSettings = onSettings
    }

    public func connect(to endpoint: NWEndpoint) {
        disconnect()
        let c = SyncConnection(NWConnection(to: endpoint, using: params))
        conn = c
        task = Task { [onSnapshot, onHistoryChanged, onConnectionChange, onSettings] in
            do {
                try await c.start()
                try await c.send(.subscribeLive)
                onConnectionChange(true)
                while !Task.isCancelled {
                    switch try await c.receive() {
                    case .liveSnapshot(let data): if let s = LiveSnapshot(data: data) { onSnapshot(s) }
                    case .historyChanged(let rev): onHistoryChanged(rev)
                    case .settings(let data): if let s = SyncSettings(data: data) { onSettings(s) }
                    default: break
                    }
                }
            } catch { /* link dropped */ }
            onConnectionChange(false)
        }
    }

    /// Send a command up to the iPhone over the live connection (Mac → iPhone → band).
    public func sendCommand(_ cmd: SyncCommand) {
        guard let c = conn else { return }
        Task { try? await c.send(.command(cmd.encoded())) }
    }

    public func disconnect() {
        task?.cancel(); task = nil
        conn?.cancel(); conn = nil
    }
}
