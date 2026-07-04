import Foundation

/// The Bonjour TXT record the iPhone advertises so the Mac can decide whether it's stale without
/// opening a connection: a monotonic revision, the latest day key, and the DB schema version.
public struct SyncAdvert: Equatable {
    public var rev: UInt64
    public var day: String
    public var v: Int
    public init(rev: UInt64, day: String, v: Int) { self.rev = rev; self.day = day; self.v = v }

    public func txtDictionary() -> [String: String] {
        ["rev": String(rev), "day": day, "v": String(v)]
    }
    public init?(txt: [String: String]) {
        guard let r = txt["rev"].flatMap(UInt64.init),
              let d = txt["day"],
              let vv = txt["v"].flatMap(Int.init) else { return nil }
        self.init(rev: r, day: d, v: vv)
    }
}

/// The wire messages exchanged once a TLS-PSK connection is open. One-byte tag + optional payload.
public enum SyncMessage: Equatable {
    // History channel
    case pullRequest          // client → server: "send me your latest backup"
    case backupChunk(Data)    // server → client: one chunk of the .noopbak
    case backupDigest(Data)   // server → client: SHA-256 digest of the streamed .noopbak
    case done                 // server → client: end of stream
    // Live channel
    case subscribeLive          // client → server: "stream me live snapshots"
    case liveSnapshot(Data)     // server → client: one JSON-encoded LiveSnapshot
    case historyChanged(UInt64) // server → client: "my DB revision is now N" (client pulls if newer)
    case command(Data)          // client → server: one JSON-encoded SyncCommand (Mac → iPhone → band)
    case settings(Data)         // server → client: one JSON-encoded SyncSettings (profile + prefs mirror)

    public var wireTag: UInt8 {
        switch self {
        case .pullRequest:    return 1
        case .backupChunk:    return 2
        case .done:           return 3
        case .subscribeLive:  return 4
        case .liveSnapshot:   return 5
        case .historyChanged: return 6
        case .command:        return 7
        case .settings:       return 8
        case .backupDigest:   return 9
        }
    }

    public func encoded() -> Data {
        var d = Data([wireTag])
        switch self {
        case .backupChunk(let payload), .backupDigest(let payload), .liveSnapshot(let payload),
             .command(let payload), .settings(let payload):
            d.append(payload)
        case .historyChanged(let rev):
            var be = rev.bigEndian
            withUnsafeBytes(of: &be) { d.append(contentsOf: $0) }
        default:
            break
        }
        return d
    }

    public static func decode(_ data: Data) -> SyncMessage? {
        guard let tag = data.first else { return nil }
        let body = data.dropFirst()
        switch tag {
        case 1: return .pullRequest
        case 2: return .backupChunk(body)
        case 3: return .done
        case 4: return .subscribeLive
        case 5: return .liveSnapshot(body)
        case 6:
            guard body.count >= 8 else { return nil }
            let rev = body.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            return .historyChanged(rev)
        case 7: return .command(body)
        case 8: return .settings(body)
        case 9: return .backupDigest(body)
        default: return nil
        }
    }
}
