import Testing
import CryptoKit
@testable import StrandSync

@Test func psk_isDeterministic_forSameCode() {
    #expect(SyncCrypto.psk(fromCode: "402913") == SyncCrypto.psk(fromCode: "402913"))
}

@Test func psk_differs_forDifferentCodes() {
    #expect(SyncCrypto.psk(fromCode: "000000") != SyncCrypto.psk(fromCode: "000001"))
}

@Test func generateCode_isSixDigits() {
    let c = SyncCrypto.generateCode()
    let allDigits = c.allSatisfy { $0.isNumber }
    #expect(c.count == 6)
    #expect(allDigits)
}
