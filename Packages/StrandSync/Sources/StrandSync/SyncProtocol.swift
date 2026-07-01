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
    case pullRequest          // client → server: "send me your latest backup"
    case backupChunk(Data)    // server → client: one chunk of the .noopbak
    case done                 // server → client: end of stream

    public var wireTag: UInt8 {
        switch self {
        case .pullRequest: return 1
        case .backupChunk: return 2
        case .done:        return 3
        }
    }

    public func encoded() -> Data {
        var d = Data([wireTag])
        if case let .backupChunk(payload) = self { d.append(payload) }
        return d
    }

    public static func decode(_ data: Data) -> SyncMessage? {
        guard let tag = data.first else { return nil }
        switch tag {
        case 1: return .pullRequest
        case 2: return .backupChunk(data.dropFirst())
        case 3: return .done
        default: return nil
        }
    }
}
