import Foundation

/// The iPhone's real-time state, streamed to the Mac ~1 Hz over the live channel so the Mac can show
/// live HR + "Connected via iPhone" + battery. JSON-encoded on the wire. Pure value type — the app maps
/// its `LiveState` to/from this.
public struct LiveSnapshot: Codable, Sendable, Equatable {
    public var heartRate: Int?
    public var connected: Bool
    public var bonded: Bool
    public var batteryPct: Double?
    public var charging: Bool?
    public var worn: Bool
    public var rr: [Int]
    public var rrRecent: [Int]        // recent R-R buffer (the Live console's R-R intervals card + RMSSD)
    public var lastFrameType: String? // the FRAME readout
    public var lastEvent: String?     // the EVENT readout
    public var ts: Double             // epoch seconds, for ordering / staleness

    public init(heartRate: Int? = nil, connected: Bool = false, bonded: Bool = false,
                batteryPct: Double? = nil, charging: Bool? = nil, worn: Bool = true,
                rr: [Int] = [], rrRecent: [Int] = [], lastFrameType: String? = nil,
                lastEvent: String? = nil, ts: Double = 0) {
        self.heartRate = heartRate; self.connected = connected; self.bonded = bonded
        self.batteryPct = batteryPct; self.charging = charging; self.worn = worn
        self.rr = rr; self.rrRecent = rrRecent; self.lastFrameType = lastFrameType
        self.lastEvent = lastEvent; self.ts = ts
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let s = try? JSONDecoder().decode(LiveSnapshot.self, from: data) else { return nil }
        self = s
    }
}
