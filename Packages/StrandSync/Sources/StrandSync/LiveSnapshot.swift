import Foundation

/// A manual workout/session running on the iPhone, mirrored to the Mac so remote commands have visible
/// state there even though the Mac is not the device recording samples into the database.
public struct LiveSessionSnapshot: Codable, Sendable, Equatable {
    public var sport: String
    public var startTs: Double
    public var elapsed: Double
    public var currentHr: Int?
    public var liveStrain: Double
    public var avgHr: Int
    public var peakHr: Int
    public var lastCommandAck: String?

    public init(sport: String,
                startTs: Double,
                elapsed: Double,
                currentHr: Int? = nil,
                liveStrain: Double = 0,
                avgHr: Int = 0,
                peakHr: Int = 0,
                lastCommandAck: String? = nil) {
        self.sport = sport
        self.startTs = startTs
        self.elapsed = elapsed
        self.currentHr = currentHr
        self.liveStrain = liveStrain
        self.avgHr = avgHr
        self.peakHr = peakHr
        self.lastCommandAck = lastCommandAck
    }
}

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
    public var session: LiveSessionSnapshot?
    public var lastCommandAck: String?
    public var ts: Double             // epoch seconds, for ordering / staleness

    public init(heartRate: Int? = nil, connected: Bool = false, bonded: Bool = false,
                encryptedBond: Bool = false, batteryPct: Double? = nil, charging: Bool? = nil,
                worn: Bool = true, rr: [Int] = [], rrRecent: [Int] = [], lastFrameType: String? = nil,
                lastEvent: String? = nil, liveFeedActive: Bool = false, advertisingName: String? = nil,
                strapFirmware: String? = nil, pairingHint: String? = nil, reconnectGuide: String? = nil,
                standardHRMode: String? = nil, batteryRemainingHours: Double? = nil,
                batterySource: String? = nil, batteryCurrentSoc: Double? = nil,
                session: LiveSessionSnapshot? = nil, lastCommandAck: String? = nil, ts: Double = 0) {
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
        self.session = session
        self.lastCommandAck = lastCommandAck
        self.ts = ts
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let s = try? JSONDecoder().decode(LiveSnapshot.self, from: data) else { return nil }
        self = s
    }
}
