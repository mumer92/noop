import XCTest
@testable import Strand

final class SyncPairingTests: XCTestCase {
    override func setUp() { SyncPairing.clear() }
    override func tearDown() { SyncPairing.clear() }

    func testSaveLoadRoundTrips() {
        SyncPairing.save(PairedPeer(code: "402913", identity: "mac-abc"))
        XCTAssertEqual(SyncPairing.load(), PairedPeer(code: "402913", identity: "mac-abc"))
    }

    func testClearRemoves() {
        SyncPairing.save(PairedPeer(code: "111111", identity: "x"))
        SyncPairing.clear()
        XCTAssertNil(SyncPairing.load())
    }

    func testResaveOverwrites() {
        SyncPairing.save(PairedPeer(code: "111111", identity: "a"))
        SyncPairing.save(PairedPeer(code: "222222", identity: "b"))
        XCTAssertEqual(SyncPairing.load(), PairedPeer(code: "222222", identity: "b"))
    }
}
