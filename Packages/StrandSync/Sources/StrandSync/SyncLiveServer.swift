import Foundation
import Network
import CryptoKit

/// The live channel source (iPhone). Advertises `_noopsync-live._tcp`; when a paired peer sends
/// `.subscribeLive`, it streams a `LiveSnapshot` every `interval` seconds (and a `.historyChanged`
/// whenever the DB revision changes) until the connection drops. Snapshot + revision are injected so
/// this stays app-agnostic and loopback-testable.
public final class SyncLiveServer: @unchecked Sendable {
    private let params: NWParameters
    private let useBonjour: Bool
    private let interval: TimeInterval
    private let snapshot: @Sendable () -> LiveSnapshot
    private let revision: @Sendable () -> UInt64
    private let onCommand: @Sendable (SyncCommand) -> Void
    private let settings: @Sendable () -> Data?
    private var listener: NWListener?
    private let lock = NSLock()
    private var active: [SyncConnection] = []
    private var stopped = false

    public private(set) var port: UInt16?

    public init(psk: SymmetricKey, useBonjour: Bool = true, peerToPeer: Bool = false,
                interval: TimeInterval = 1.0,
                snapshot: @escaping @Sendable () -> LiveSnapshot,
                revision: @escaping @Sendable () -> UInt64 = { 0 },
                onCommand: @escaping @Sendable (SyncCommand) -> Void = { _ in },
                settings: @escaping @Sendable () -> Data? = { nil }) {
        self.params = SyncTLS.parameters(psk: psk, peerToPeer: peerToPeer)
        self.useBonjour = useBonjour
        self.interval = interval
        self.snapshot = snapshot
        self.revision = revision
        self.onCommand = onCommand
        self.settings = settings
    }

    public func start() throws {
        let listener = try NWListener(using: params)
        if useBonjour {
            listener.service = NWListener.Service(type: "_noopsync-live._tcp")
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
        let alreadyStopped = addActive(conn)
        if alreadyStopped { conn.cancel(); return }
        defer {
            conn.cancel()
            removeActive(conn)
        }
        do {
            try await conn.start()
            guard case .subscribeLive = try await conn.receive() else { return }
            // Concurrently: stream snapshots down, and receive commands up. When either side ends
            // (the connection dropped), cancel the other and return.
            let snapshot = self.snapshot, revision = self.revision, onCommand = self.onCommand
            let settings = self.settings, interval = self.interval
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    var lastRev = UInt64.max
                    var lastSettings: Data? = nil
                    while true {
                        try await conn.send(.liveSnapshot(snapshot().encoded()))
                        let rev = revision()
                        if rev != lastRev { try await conn.send(.historyChanged(rev)); lastRev = rev }
                        if let s = settings(), s != lastSettings { try await conn.send(.settings(s)); lastSettings = s }
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                }
                group.addTask {
                    while true {
                        if case .command(let data) = try await conn.receive(), let cmd = SyncCommand(data: data) {
                            onCommand(cmd)
                        }
                    }
                }
                try await group.next()       // returns/throws when the first task ends (link dropped)
                group.cancelAll()
            }
        } catch { /* peer dropped */ }
    }

    private func addActive(_ conn: SyncConnection) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let alreadyStopped = stopped
        if !alreadyStopped { active.append(conn) }
        return alreadyStopped
    }

    private func removeActive(_ conn: SyncConnection) {
        lock.lock()
        defer { lock.unlock() }
        active.removeAll { $0 === conn }
    }

    public func stop() {
        lock.lock(); stopped = true; let conns = active; active = []; lock.unlock()
        conns.forEach { $0.cancel() }
        listener?.cancel(); listener = nil; port = nil
    }
}
