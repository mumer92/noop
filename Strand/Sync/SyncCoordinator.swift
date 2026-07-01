import Foundation
import Network
import CryptoKit
import StrandSync
import WhoopStore

/// The app-side brain for local-network sync. On iOS it runs a `SyncServer` that advertises the strap
/// data and serves a `.noopbak` to the paired Mac; on macOS it runs a `SyncBrowser` + `SyncClient`,
/// pulling the iPhone's backup and restoring it via `DataBackup`. One-way (iPhone → Mac), opt-in, and
/// only active once paired. Observable so the Settings screen can show status.
@MainActor
final class SyncCoordinator: ObservableObject {
    enum State: Equatable {
        case off              // disabled or not paired
        case waitingForPair   // enabled, needs a code
        case listening        // iPhone: advertising
        case discovering      // Mac: looking for the iPhone
        case syncing          // Mac: transferring
        case upToDate         // Mac: nothing new
        case needsRestart     // Mac: restored — relaunch to load it
        case error(String)
    }

    @Published private(set) var state: State = .off
    @Published private(set) var lastSync: Date?
    @Published private(set) var pairedLabel: String?

    private let repo: Repository
    private let enabledKey = "localsync.enabled"
    private let lastHashKey = "localsync.lastHash"

    // iOS
    private var server: SyncServer?
    // macOS
    private var browser: SyncBrowser?
    private var currentEndpoint: NWEndpoint?
    private var inFlight = false

    init(repo: Repository) {
        self.repo = repo
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
        browser?.stop(); browser = nil
        currentEndpoint = nil
    }

    // MARK: Pairing / enable

    /// iOS: generate + persist a fresh code, (re)start the server, return the code to show the user.
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
        pairedLabel = nil
        isEnabled = false
        state = .off
    }

    // MARK: iOS server

    #if os(iOS)
    private func startServer() {
        guard let peer = SyncPairing.load() else { state = .waitingForPair; return }
        server?.stop()
        let advert = SyncAdvert(rev: UInt64(repo.days.count),
                                day: repo.days.last?.day ?? "",
                                v: WhoopStoreInfo.schemaVersion)
        let s = SyncServer(psk: SyncCrypto.psk(fromCode: peer.code), identity: "iphone",
                           advert: { advert },
                           makeBackup: { [weak self] in await self?.makeBackup() })
        do { try s.start(); server = s; state = .listening }
        catch { state = .error("Couldn't start sync: \(error.localizedDescription)") }
    }

    private func makeBackup() async -> URL? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("noopsync-out-\(UUID().uuidString).noopbak")
        let result = await DataBackup.writeBackup(checkpoint: { await self.repo.checkpointForBackup() }, to: dest)
        if case .exported(let url) = result { return url }
        return nil
    }
    #endif

    // MARK: macOS browser + pull + restore

    #if os(macOS)
    private func startBrowser() {
        browser?.stop()
        state = .discovering
        let b = SyncBrowser(onEndpoint: { [weak self] endpoint in
            Task { @MainActor in self?.handleEndpoint(endpoint) }
        })
        b.start()
        browser = b
    }

    private func handleEndpoint(_ endpoint: NWEndpoint) {
        currentEndpoint = endpoint
        guard !inFlight else { return }
        Task { await pullAndRestore(endpoint) }
    }

    /// Manual "Sync now": pull from the last-seen peer immediately.
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
            let client = SyncClient(psk: SyncCrypto.psk(fromCode: peer.code), identity: "mac")
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
                state = .needsRestart
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
