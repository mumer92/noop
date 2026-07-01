import Testing
import Foundation
import Network
@testable import StrandSync

// MARK: - Protocol round-trips

@Test func liveSnapshot_json_roundTrips() {
    let s = LiveSnapshot(heartRate: 62, connected: true, bonded: true, batteryPct: 77,
                         charging: false, worn: true, rr: [810, 795], ts: 123.5)
    #expect(LiveSnapshot(data: s.encoded()) == s)
}

@Test func message_liveTags_roundTrip() {
    #expect(SyncMessage.decode(SyncMessage.subscribeLive.encoded()) == .subscribeLive)
    let payload = Data([1, 2, 3, 4])
    #expect(SyncMessage.decode(SyncMessage.liveSnapshot(payload).encoded()) == .liveSnapshot(payload))
    #expect(SyncMessage.decode(SyncMessage.historyChanged(4242).encoded()) == .historyChanged(4242))
}

// MARK: - Live loopback

private final class SnapBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [LiveSnapshot] = []
    func add(_ s: LiveSnapshot) { lock.lock(); items.append(s); lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return items.count }
    var first: LiveSnapshot? { lock.lock(); defer { lock.unlock() }; return items.first }
}

private func waitForLivePort(_ server: SyncLiveServer, timeout: TimeInterval = 5) async throws -> UInt16 {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let p = server.port { return p }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    throw SyncError.timedOut
}

@Test func liveRelay_streamsSnapshots_withMatchingPSK() async throws {
    let psk = SyncCrypto.psk(fromCode: "222222")
    let snap = LiveSnapshot(heartRate: 60, connected: true, batteryPct: 80, ts: 1)
    let server = SyncLiveServer(psk: psk, useBonjour: false, peerToPeer: false, interval: 0.1,
                                snapshot: { snap }, revision: { 7 })
    try server.start()
    defer { server.stop() }
    let port = try await waitForLivePort(server)

    let box = SnapBox()
    let client = SyncLiveClient(psk: psk, peerToPeer: false, onSnapshot: { box.add($0) })
    client.connect(to: NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!))
    defer { client.disconnect() }

    let deadline = Date().addingTimeInterval(5)
    while box.count < 2 && Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }

    #expect(box.count >= 2)                 // stream delivered multiple snapshots
    #expect(box.first?.heartRate == 60)
    #expect(box.first?.connected == true)
}
