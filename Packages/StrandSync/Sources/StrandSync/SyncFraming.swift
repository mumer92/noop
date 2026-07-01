import Foundation

/// Length-prefixed message framing over a byte stream: a 4-byte big-endian UInt32 length
/// followed by that many payload bytes. `decode` pops exactly one complete message from an
/// accumulating buffer, or returns nil when the buffer doesn't yet hold a full message.
public enum SyncFraming {
    public static func frame(_ payload: Data) -> Data {
        var out = Data(capacity: payload.count + 4)
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    /// Pop one complete message from the front of `buffer`, mutating it to drop the consumed bytes.
    /// Returns nil (and leaves `buffer` untouched) when fewer than a full framed message is present.
    public static func decode(_ buffer: inout Data) -> Data? {
        guard buffer.count >= 4 else { return nil }
        let header = buffer.prefix(4)
        let len = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let total = 4 + Int(len)
        guard buffer.count >= total else { return nil }
        let payload = buffer.subdata(in: (buffer.startIndex + 4)..<(buffer.startIndex + total))
        buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + total))
        return payload
    }
}
