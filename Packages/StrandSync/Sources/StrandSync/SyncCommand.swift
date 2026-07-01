import Foundation

/// A command sent Mac → iPhone over the paired link. The iPhone executes it on the strap (the band is
/// bonded to the iPhone, so all band actions run there). Extensible — add cases as more actions are relayed.
public enum SyncCommand: Codable, Sendable, Equatable {
    case buzz                                  // haptic-buzz the strap (default pattern)
    case buzzPattern(pattern: UInt8, loops: UInt8)  // custom haptic pattern
    case stopHaptics                           // cancel an ongoing buzz
    case armAlarm(epochMs: Int64)              // arm the strap's wake alarm at an absolute time
    case disableAlarm                          // clear the strap's wake alarm
    case startWorkout(sport: String)           // begin a workout session
    case endWorkout                            // end the current workout
    case startRealtime                         // arm the high-rate live HR/R-R stream
    case stopRealtime                          // disarm the high-rate live stream
    case syncNow                               // force a history offload from the strap
    case scan                                  // (re)connect / scan for the strap
    case disconnect                            // disconnect the strap
    case refreshBattery                        // request a fresh battery reading

    // Left local-only (not relayed): renameStrap, enableWhoop5DeepData, captureRawAccel,
    // getStrapAlarm, setBroadcastHr — response-driven / stateful / diagnostic.

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let c = try? JSONDecoder().decode(SyncCommand.self, from: data) else { return nil }
        self = c
    }
}
