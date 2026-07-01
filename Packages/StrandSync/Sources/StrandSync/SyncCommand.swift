import Foundation

/// A command sent Mac → iPhone over the paired link. The iPhone executes it on the strap (the band is
/// bonded to the iPhone, so all band actions run there). Extensible — add cases as more actions are relayed.
public enum SyncCommand: Codable, Sendable, Equatable {
    case buzz                          // haptic-buzz the strap
    case armAlarm(epochMs: Int64)      // arm the strap's wake alarm at an absolute time
    case startWorkout(sport: String)   // begin a workout session
    case endWorkout                    // end the current workout

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let c = try? JSONDecoder().decode(SyncCommand.self, from: data) else { return nil }
        self = c
    }
}
