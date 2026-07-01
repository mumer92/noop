import Foundation
import CryptoKit

/// Derives the pre-shared key both devices use from the short pairing code the user types, and
/// mints fresh pairing codes. The derivation is deterministic (same code → same key) so the two
/// sides agree without ever transmitting the key.
public enum SyncCrypto {
    private static let salt = Data("noop.localsync.v1".utf8)
    private static let info = Data("psk".utf8)

    /// Deterministically derive a 256-bit pre-shared key from the pairing code (HKDF-SHA256).
    public static func psk(fromCode code: String) -> SymmetricKey {
        let ikm = SymmetricKey(data: Data(code.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: info, outputByteCount: 32)
    }

    /// A fresh 6-digit pairing code from the system CSPRNG.
    public static func generateCode() -> String {
        let n = UInt32.random(in: 0..<1_000_000)
        return String(format: "%06u", n)
    }
}
