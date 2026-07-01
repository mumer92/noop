import Testing
import Network
import CryptoKit
@testable import StrandSync

@Test func tls_params_areLanOnly_andPeerToPeer() {
    let p = SyncTLS.parameters(psk: SymmetricKey(size: .bits256), identity: "noop")
    #expect(p.includePeerToPeer == true)
    #expect(p.prohibitedInterfaceTypes?.contains(.cellular) == true)
}
