import Foundation
import Security

/// A device that has completed pairing: the shared 6-digit code (which both sides turn into the
/// TLS pre-shared key) plus an opaque identity label for display/pinning.
public struct PairedPeer: Equatable {
    public let code: String
    public let identity: String
    public init(code: String, identity: String) { self.code = code; self.identity = identity }
}

/// Persists the pairing secret in the Keychain (generic-password), so it survives relaunch and never
/// touches UserDefaults/plists. Only one pairing is stored at a time; re-pairing overwrites it.
public enum SyncPairing {
    private static let service = "noop.localsync"
    private static let account = "pairing"

    public static func save(_ peer: PairedPeer) {
        clear()
        let value = Data("\(peer.code)|\(peer.identity)".utf8)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    public static func load() -> PairedPeer? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        let parts = string.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return PairedPeer(code: parts[0], identity: parts[1])
    }

    public static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
