import Testing
import Foundation
import Network
@testable import StrandSync

/// Poll until the server's listener has bound a port (state → ready), or time out.
private func waitForPort(_ server: SyncServer, timeout: TimeInterval = 5) async throws -> UInt16 {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let p = server.port { return p }
        try await Task.sleep(nanoseconds: 20_000_000)   // 20ms
    }
    throw SyncError.timedOut
}

private func makeTempBackup(_ payload: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("src-\(UUID().uuidString).noopbak")
    try payload.write(to: url)
    return url
}

@Test func loopback_transfersBackup_withMatchingPSK() async throws {
    let psk = SyncCrypto.psk(fromCode: "123456")
    let payload = Data((0..<250_000).map { UInt8($0 & 0xFF) })   // spans many chunks
    let src = try makeTempBackup(payload)

    let server = SyncServer(psk: psk, identity: "iphone", useBonjour: false, peerToPeer: false,
                            advert: { SyncAdvert(rev: 1, day: "2026-07-01", v: 1) },
                            makeBackup: { src })
    try server.start()
    defer { server.stop() }
    let port = try await waitForPort(server)

    let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
    let client = SyncClient(psk: psk, identity: "mac", peerToPeer: false)
    let received = try await client.pull(from: endpoint)

    let receivedData = try Data(contentsOf: received)
    #expect(receivedData == payload)
    try? FileManager.default.removeItem(at: received)
    try? FileManager.default.removeItem(at: src)
}

@Test func loopback_wrongPSK_failsToTransfer() async throws {
    let serverPSK = SyncCrypto.psk(fromCode: "123456")
    let clientPSK = SyncCrypto.psk(fromCode: "999999")   // different code → different key
    let src = try makeTempBackup(Data(repeating: 42, count: 1000))

    let server = SyncServer(psk: serverPSK, identity: "iphone", useBonjour: false, peerToPeer: false,
                            advert: { SyncAdvert(rev: 1, day: "2026-07-01", v: 1) },
                            makeBackup: { src })
    try server.start()
    defer { server.stop() }
    let port = try await waitForPort(server)

    let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
    let client = SyncClient(psk: clientPSK, identity: "mac", peerToPeer: false)

    await #expect(throws: (any Error).self) {
        _ = try await client.pull(from: endpoint, timeout: 4)
    }
    try? FileManager.default.removeItem(at: src)
}
