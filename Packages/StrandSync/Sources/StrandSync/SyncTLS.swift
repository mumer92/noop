import Foundation
import Network
import CryptoKit

/// Builds the `NWParameters` for a LAN-only, TLS-PSK-secured connection. The pre-shared key is the
/// one both devices derived from the pairing code (`SyncCrypto.psk`), so only paired devices can
/// complete the handshake. Peer-to-peer Wi-Fi is enabled and cellular is prohibited, so the link
/// stays on the local network and never reaches the internet.
public enum SyncTLS {
    public static func parameters(psk: SymmetricKey, identity: String) -> NWParameters {
        let tls = NWProtocolTLS.Options()

        let keyData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let idData = Data(identity.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(
            tls.securityProtocolOptions,
            keyData as __DispatchData,
            idData as __DispatchData
        )
        sec_protocol_options_append_tls_ciphersuite(
            tls.securityProtocolOptions,
            tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!
        )

        let params = NWParameters(tls: tls)
        params.includePeerToPeer = true
        params.prohibitedInterfaceTypes = [.cellular]
        return params
    }
}
