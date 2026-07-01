import Foundation
import Network
import CryptoKit
import Combine
import StrandSync
import WhoopStore

/// Thread-safe holder for the latest `LiveSnapshot` the iOS live server streams. The server reads it
/// from a background queue; the coordinator refreshes it on the main actor whenever `LiveState` changes.
private final class SnapshotHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var value = LiveSnapshot()
    func set(_ s: LiveSnapshot) { lock.lock(); value = s; lock.unlock() }
    func get() -> LiveSnapshot { lock.lock(); defer { lock.unlock() }; return value }
}

/// Thread-safe holder for the latest encoded `SyncSettings` the iOS live server streams (change-driven).
private final class DataHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?
    func set(_ d: Data?) { lock.lock(); value = d; lock.unlock() }
    func get() -> Data? { lock.lock(); defer { lock.unlock() }; return value }
}

/// The app-side brain for local-network sync. Two channels over one pairing:
/// - **History** (iOS serves a `.noopbak`; macOS pulls + restores) — the whole-DB mirror.
/// - **Live** (iOS streams `LiveSnapshot`; macOS applies to its `LiveState`) — live HR + "via iPhone".
/// One-way (iPhone → Mac), opt-in, LAN-only, active once paired.
@MainActor
final class SyncCoordinator: ObservableObject {
    enum State: Equatable {
        case off, waitingForPair, listening, discovering, syncing, upToDate, needsRestart, error(String)
    }

    @Published private(set) var state: State = .off
    @Published private(set) var lastSync: Date?
    @Published private(set) var pairedLabel: String?

    private let repo: Repository
    private let live: LiveState
    /// Set by `AppModel` (iOS): dispatches a command received from a paired Mac to the strap.
    var commandHandler: ((SyncCommand) -> Void)?
    /// Profile + settings mirror closures, set by `AppModel`. iOS: `settingsProvider` returns the current
    /// encoded `SyncSettings`. macOS: `settingsApplier` applies a relayed payload; `settingsRestore` reverts
    /// to the Mac's own settings on unpair.
    var settingsProvider: (() -> Data?)?
    var settingsApplier: ((SyncSettings) -> Void)?
    var settingsRestore: (() -> Void)?
    private let settingsHolder = DataHolder()
    private let enabledKey = "localsync.enabled"
    private let lastHashKey = "localsync.lastHash"

    // iOS
    private var server: SyncServer?
    private var liveServer: SyncLiveServer?
    private let snapHolder = SnapshotHolder()
    private var cancellables = Set<AnyCancellable>()
    /// Refreshes the outgoing live snapshot on a reliable main-actor cadence (RunLoop.main Combine
    /// scheduling was dropping updates, freezing the snapshot before HR started flowing).
    private var snapshotTask: Task<Void, Never>?
    // macOS
    private var browser: SyncBrowser?
    private var liveBrowser: SyncBrowser?
    private var liveClient: SyncLiveClient?
    private var currentEndpoint: NWEndpoint?
    private var inFlight = false

    init(repo: Repository, live: LiveState) {
        self.repo = repo
        self.live = live
        pairedLabel = SyncPairing.load() != nil ? "Paired" : nil
        if let d = UserDefaults.standard.object(forKey: "localsync.lastSync") as? Date { lastSync = d }
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // MARK: Lifecycle

    func startIfEnabled() {
        guard isEnabled else { state = .off; return }
        guard SyncPairing.load() != nil else { state = .waitingForPair; return }
        start()
    }

    private func start() {
        #if os(iOS)
        startServer()
        #elseif os(macOS)
        startBrowser()
        #endif
    }

    func stop() {
        server?.stop(); server = nil
        liveServer?.stop(); liveServer = nil
        snapshotTask?.cancel(); snapshotTask = nil
        cancellables.removeAll()
        browser?.stop(); browser = nil
        liveBrowser?.stop(); liveBrowser = nil
        liveClient?.disconnect(); liveClient = nil
        live.clearRemote()
        currentEndpoint = nil
    }

    // MARK: Pairing / enable

    /// iOS: generate + persist a fresh code, (re)start the servers, return the code to show the user.
    func showPairingCode() -> String {
        let code = SyncCrypto.generateCode()
        SyncPairing.save(PairedPeer(code: code, identity: "peer"))
        pairedLabel = "Paired"
        isEnabled = true
        startIfEnabled()
        return code
    }

    /// macOS: store the code the user typed, then start discovering.
    func pair(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 6, trimmed.allSatisfy({ $0.isNumber }) else {
            state = .error("Enter the 6-digit code from your iPhone."); return
        }
        SyncPairing.save(PairedPeer(code: trimmed, identity: "peer"))
        pairedLabel = "Paired"
        isEnabled = true
        startIfEnabled()
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on { startIfEnabled() } else { stop(); state = .off }
    }

    func unpair() {
        SyncPairing.clear()
        UserDefaults.standard.removeObject(forKey: lastHashKey)
        stop()
        settingsRestore?()   // macOS: revert to this Mac's own profile/settings
        pairedLabel = nil
        isEnabled = false
        state = .off
    }

    /// Send a command up to the paired iPhone (Mac → iPhone → band), e.g. `.buzz`. On iOS `liveClient`
    /// is always nil (iOS is the source, not a subscriber), so this is a no-op there.
    func sendCommand(_ cmd: SyncCommand) { liveClient?.sendCommand(cmd) }

    /// True when this device is mirroring a paired iPhone over the live relay (so strap controls should
    /// piggyback the iPhone rather than the local BLE).
    var isRelaying: Bool { live.remoteSource != nil }

    // MARK: iOS servers (history + live)

    #if os(iOS)
    private func startServer() {
        guard let peer = SyncPairing.load() else { state = .waitingForPair; return }
        let psk = SyncCrypto.psk(fromCode: peer.code)

        // History server
        server?.stop()
        let advert = SyncAdvert(rev: UInt64(repo.days.count),
                                day: repo.days.last?.day ?? "",
                                v: WhoopStoreInfo.schemaVersion)
        let s = SyncServer(psk: psk, identity: "iphone", peerToPeer: false,
                           advert: { advert },
                           makeBackup: { [weak self] in await self?.makeBackup() })
        do { try s.start(); server = s; state = .listening }
        catch { state = .error("Couldn't start sync: \(error.localizedDescription)") }

        // Live server — streams the current snapshot ~1 Hz. Keep the outgoing snapshot fresh with a
        // main-actor timer loop (reads live HR/connection/battery every 0.4s), NOT objectWillChange +
        // RunLoop.main (which dropped updates and froze the snapshot before HR arrived).
        liveServer?.stop()
        snapshotTask?.cancel()
        refreshSnapshotHolder()
        snapshotTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshSnapshotHolder()
                try? await Task.sleep(nanoseconds: 400_000_000)   // 0.4s
            }
        }
        let ls = SyncLiveServer(psk: psk, useBonjour: true, peerToPeer: false, interval: 1.0,
                                snapshot: { [snapHolder] in snapHolder.get() },
                                onCommand: { [weak self] cmd in Task { @MainActor in self?.commandHandler?(cmd) } },
                                settings: { [settingsHolder] in settingsHolder.get() })
        try? ls.start()
        liveServer = ls
    }

    private func refreshSnapshotHolder() {
        snapHolder.set(live.snapshot())
        settingsHolder.set(settingsProvider?())   // profile + prefs mirror (change-driven on the wire)
    }

    private func makeBackup() async -> URL? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("noopsync-out-\(UUID().uuidString).noopbak")
        let result = await DataBackup.writeBackup(checkpoint: { await self.repo.checkpointForBackup() }, to: dest)
        if case .exported(let url) = result { return url }
        return nil
    }
    #endif

    // MARK: macOS browsers + pull/restore + live apply

    #if os(macOS)
    private func startBrowser() {
        state = .discovering
        // History discovery → pull + restore
        browser?.stop()
        let b = SyncBrowser(type: "_noopsync._tcp", onEndpoint: { [weak self] endpoint in
            Task { @MainActor in self?.handleEndpoint(endpoint) }
        })
        b.start(); browser = b

        // Live discovery → subscribe + apply snapshots
        liveBrowser?.stop()
        let lb = SyncBrowser(type: "_noopsync-live._tcp", onEndpoint: { [weak self] endpoint in
            Task { @MainActor in self?.connectLive(endpoint) }
        })
        lb.start(); liveBrowser = lb
    }

    private func handleEndpoint(_ endpoint: NWEndpoint) {
        currentEndpoint = endpoint
        guard !inFlight else { return }
        Task { await pullAndRestore(endpoint) }
    }

    private func connectLive(_ endpoint: NWEndpoint) {
        guard liveClient == nil, let peer = SyncPairing.load() else { return }   // connect once
        let client = SyncLiveClient(
            psk: SyncCrypto.psk(fromCode: peer.code), peerToPeer: false,
            onSnapshot: { [weak self] snap in Task { @MainActor in self?.live.applyRemote(snap, from: "iPhone") } },
            onHistoryChanged: { [weak self] _ in Task { @MainActor in self?.syncNow() } },
            onConnectionChange: { [weak self] up in Task { @MainActor in if !up { self?.onLiveLinkDown() } } },
            onSettings: { [weak self] s in Task { @MainActor in self?.settingsApplier?(s) } })
        client.connect(to: endpoint)
        liveClient = client
    }

    private func onLiveLinkDown() {
        live.clearRemote()
        liveClient = nil   // allow a future discovery to reconnect
    }

    /// Manual "Sync now": pull the DB from the last-seen peer immediately.
    func syncNow() {
        guard let endpoint = currentEndpoint else { state = .discovering; return }
        guard !inFlight else { return }
        Task { await pullAndRestore(endpoint) }
    }

    private func pullAndRestore(_ endpoint: NWEndpoint) async {
        guard let peer = SyncPairing.load() else { return }
        inFlight = true
        state = .syncing
        defer { inFlight = false }
        do {
            let client = SyncClient(psk: SyncCrypto.psk(fromCode: peer.code), identity: "mac", peerToPeer: false)
            let url = try await client.pull(from: endpoint)
            let data = try Data(contentsOf: url)
            let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if hex == UserDefaults.standard.string(forKey: lastHashKey) {
                try? FileManager.default.removeItem(at: url)
                state = .upToDate
                return
            }
            let result = DataBackup.restore(from: url)
            try? FileManager.default.removeItem(at: url)
            switch result {
            case .imported:
                UserDefaults.standard.set(hex, forKey: lastHashKey)
                lastSync = Date()
                UserDefaults.standard.set(lastSync, forKey: "localsync.lastSync")
                // Reopen the restored database in-process and reload the dashboards — no relaunch needed.
                await repo.reopenAfterRestore()
                state = .upToDate
            case .failure(let message):
                state = .error(message)
            default:
                state = .upToDate
            }
        } catch {
            state = .error("Sync failed: \(error.localizedDescription)")
        }
    }
    #else
    func syncNow() { startIfEnabled() }
    #endif
}
