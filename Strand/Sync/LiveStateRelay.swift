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
            encryptedBond: encryptedBond,
            batteryPct: batteryPct,
            charging: charging,
            worn: worn,
            rr: Array(rr.suffix(8)),
            rrRecent: Array(rrRecent.suffix(60)),
            lastFrameType: lastFrameType,
            lastEvent: lastEvent,
            ts: Date().timeIntervalSince1970
        )
    }

    /// Apply a snapshot relayed from `source` (e.g. "iPhone"): the Mac shows this as its live state,
    /// tagged so the badge reads "via <source>".
    func applyRemote(_ s: LiveSnapshot, from source: String) {
        heartRate = s.heartRate
        connected = s.connected
        bonded = s.bonded
        encryptedBond = s.encryptedBond
        batteryPct = s.batteryPct
        charging = s.charging
        worn = s.worn
        rr = s.rr
        setRelayedRRRecent(s.rrRecent)
        lastFrameType = s.lastFrameType
        lastEvent = s.lastEvent
        remoteSource = source
    }

    /// The relay link dropped (or a snapshot went stale) — revert to "not connected".
    func clearRemote() {
        guard remoteSource != nil else { return }
        connected = false
        bonded = false
        encryptedBond = false
        heartRate = nil
        batteryPct = nil
        charging = nil
        setRelayedRRRecent([])
        lastFrameType = nil
        lastEvent = nil
        remoteSource = nil
    }
}
