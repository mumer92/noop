import Foundation
import Network
import CryptoKit

/// Builds the `NWParameters` for a LAN-only, TLS-PSK-secured connection. The pre-shared key is the
/// one both devices derived from the pairing code (`SyncCrypto.psk`), so only paired devices can
/// complete the handshake. Peer-to-peer Wi-Fi is enabled and cellular is prohibited, so the link
/// stays on the local network and never reaches the internet.
public enum SyncTLS {
    /// The TLS-PSK *identity* — a fixed, shared string that BOTH peers must present so they agree on
    /// which pre-shared key to use. This is NOT a device name (both sides use the same value); device
    /// identity/pinning is handled separately by the pairing layer.
    static let pskIdentity = "noop.localsync"

    /// `peerToPeer` enables the peer-to-peer Wi-Fi interface — required for real Bonjour discovery on a
    /// LAN, but it stalls a *direct* host:port connection (e.g. loopback tests), so callers pass `false`
    /// when they already have an explicit endpoint.
    public static func parameters(psk: SymmetricKey, peerToPeer: Bool = true) -> NWParameters {
        let tls = NWProtocolTLS.Options()

        let keyData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let idData = Data(pskIdentity.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
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
        params.includePeerToPeer = peerToPeer
        params.prohibitedInterfaceTypes = [.cellular]
        return params
    }
}
