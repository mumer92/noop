import Testing
import Foundation
@testable import StrandSync

@Test func framing_roundTrips_singleMessage() {
    let payload = Data("hello noop".utf8)
    var buffer = SyncFraming.frame(payload)
    let decoded = SyncFraming.decode(&buffer)
    #expect(decoded == payload)
    #expect(buffer.isEmpty)
}

@Test func framing_returnsNil_whenIncomplete() {
    let framed = SyncFraming.frame(Data(repeating: 7, count: 100))
    var buf = Data(framed.prefix(20))   // header + a few bytes only
    #expect(SyncFraming.decode(&buf) == nil)
}

@Test func framing_popsOneMessage_leavesRemainder() {
    var buf = SyncFraming.frame(Data("a".utf8))
    buf.append(SyncFraming.frame(Data("bb".utf8)))
    #expect(SyncFraming.decode(&buf) == Data("a".utf8))
    #expect(SyncFraming.decode(&buf) == Data("bb".utf8))
    #expect(SyncFraming.decode(&buf) == nil)
}
