import Testing
import Foundation
@testable import StrandSync

@Test func advert_txt_roundTrips() {
    let a = SyncAdvert(rev: 42, day: "2026-07-01", v: 3)
    #expect(SyncAdvert(txt: a.txtDictionary()) == a)
}

@Test func advert_rejectsMissingKeys() {
    #expect(SyncAdvert(txt: ["rev": "1"]) == nil)
}

@Test func message_pullRequest_roundTrips() {
    #expect(SyncMessage.decode(SyncMessage.pullRequest.encoded()) == .pullRequest)
}

@Test func message_backupChunk_roundTrips() {
    let chunk = Data([9, 8, 7, 6])
    #expect(SyncMessage.decode(SyncMessage.backupChunk(chunk).encoded()) == .backupChunk(chunk))
}

@Test func message_done_roundTrips() {
    #expect(SyncMessage.decode(SyncMessage.done.encoded()) == .done)
}
