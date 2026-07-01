import Foundation
import StrandSync

/// Bridges `LiveState` to the local-network live relay: the iPhone maps its state into a `LiveSnapshot`
/// to stream, and the Mac applies received snapshots back into its own `LiveState` so the dashboard's
/// live HR + connection badge reflect the paired iPhone ("Connected · via <source>").
@MainActor
extension LiveState {
    /// Build a snapshot of the current live state to stream to a paired Mac.
    func snapshot() -> LiveSnapshot {
        LiveSnapshot(
            heartRate: heartRate,
            connected: connected,
            bonded: bonded,
            batteryPct: batteryPct,
            charging: charging,
            worn: worn,
            rr: Array(rr.suffix(8)),
            ts: Date().timeIntervalSince1970
        )
    }

    /// Apply a snapshot relayed from `source` (e.g. "iPhone"): the Mac shows this as its live state,
    /// tagged so the badge reads "via <source>".
    func applyRemote(_ s: LiveSnapshot, from source: String) {
        heartRate = s.heartRate
        connected = s.connected
        bonded = s.bonded
        batteryPct = s.batteryPct
        charging = s.charging
        worn = s.worn
        rr = s.rr
        remoteSource = source
    }

    /// The relay link dropped (or a snapshot went stale) — revert to "not connected".
    func clearRemote() {
        guard remoteSource != nil else { return }
        connected = false
        bonded = false
        heartRate = nil
        batteryPct = nil
        charging = nil
        remoteSource = nil
    }
}
