import Foundation

/// The iPhone's real-time state, streamed to the Mac ~1 Hz over the live channel so the Mac can show
/// live HR + "Connected via iPhone" + battery. JSON-encoded on the wire. Pure value type — the app maps
/// its `LiveState` to/from this.
public struct LiveSnapshot: Codable, Sendable, Equatable {
    public var heartRate: Int?
    public var connected: Bool
    public var bonded: Bool
    public var encryptedBond: Bool    // full encrypted bond → "Controls unlocked" vs "Live HR only"
    public var batteryPct: Double?
    public var charging: Bool?
    public var worn: Bool
    public var rr: [Int]
    public var rrRecent: [Int]        // recent R-R buffer (the Live console's R-R intervals card + RMSSD)
    public var lastFrameType: String? // the FRAME readout
    public var lastEvent: String?     // the EVENT readout
    // Devices / Settings / Live secondary readouts
    public var liveFeedActive: Bool   // realtime R10/R11 stream armed
    public var advertisingName: String?
    public var strapFirmware: String?
    public var pairingHint: String?
    public var reconnectGuide: String?
    public var standardHRMode: String?
    // Battery runway — flattened from StrandAnalytics BatteryEstimator.Estimate (kept out of this package)
    public var batteryRemainingHours: Double?
    public var batterySource: String?   // "measured" | "rated"
    public var batteryCurrentSoc: Double?
    public var ts: Double             // epoch seconds, for ordering / staleness

    public init(heartRate: Int? = nil, connected: Bool = false, bonded: Bool = false,
                encryptedBond: Bool = false, batteryPct: Double? = nil, charging: Bool? = nil,
                worn: Bool = true, rr: [Int] = [], rrRecent: [Int] = [], lastFrameType: String? = nil,
                lastEvent: String? = nil, liveFeedActive: Bool = false, advertisingName: String? = nil,
                strapFirmware: String? = nil, pairingHint: String? = nil, reconnectGuide: String? = nil,
                standardHRMode: String? = nil, batteryRemainingHours: Double? = nil,
                batterySource: String? = nil, batteryCurrentSoc: Double? = nil, ts: Double = 0) {
        self.heartRate = heartRate; self.connected = connected; self.bonded = bonded
        self.encryptedBond = encryptedBond
        self.batteryPct = batteryPct; self.charging = charging; self.worn = worn
        self.rr = rr; self.rrRecent = rrRecent; self.lastFrameType = lastFrameType
        self.lastEvent = lastEvent
        self.liveFeedActive = liveFeedActive; self.advertisingName = advertisingName
        self.strapFirmware = strapFirmware; self.pairingHint = pairingHint
        self.reconnectGuide = reconnectGuide; self.standardHRMode = standardHRMode
        self.batteryRemainingHours = batteryRemainingHours; self.batterySource = batterySource
        self.batteryCurrentSoc = batteryCurrentSoc
        self.ts = ts
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let s = try? JSONDecoder().decode(LiveSnapshot.self, from: data) else { return nil }
        self = s
    }
}
