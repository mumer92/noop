import Foundation
import StrandSync
import StrandAnalytics

/// Bridges `LiveState` to the local-network live relay: the iPhone maps its state into a `LiveSnapshot`
/// to stream, and the Mac applies received snapshots back into its own `LiveState` so the dashboard's
/// live HR + connection badge reflect the paired iPhone ("Connected · via <source>").
@MainActor
extension LiveState {
    /// Build a snapshot of the current live state to stream to a paired Mac.
    func snapshot(session: LiveSessionSnapshot? = nil, commandAck: String? = nil) -> LiveSnapshot {
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
            liveFeedActive: liveFeedActive,
            advertisingName: advertisingName,
            strapFirmware: strapFirmware,
            pairingHint: pairingHint,
            reconnectGuide: reconnectGuide,
            standardHRMode: standardHRMode,
            batteryRemainingHours: batteryEstimate?.remainingHours,
            batterySource: batteryEstimate?.source.rawValue,
            batteryCurrentSoc: batteryEstimate?.currentSoc,
            session: session,
            lastCommandAck: commandAck,
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
        liveFeedActive = s.liveFeedActive
        advertisingName = s.advertisingName
        strapFirmware = s.strapFirmware
        pairingHint = s.pairingHint
        reconnectGuide = s.reconnectGuide
        standardHRMode = s.standardHRMode
        if let hours = s.batteryRemainingHours, let soc = s.batteryCurrentSoc,
           let src = s.batterySource.flatMap(BatteryEstimator.Source.init(rawValue:)) {
            relayedBatteryEstimate = BatteryEstimator.Estimate(remainingHours: hours, source: src, currentSoc: soc)
        } else {
            relayedBatteryEstimate = nil
        }
        remoteSession = s.session
        remoteCommandAck = s.lastCommandAck ?? s.session?.lastCommandAck
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
        liveFeedActive = false
        advertisingName = nil
        strapFirmware = nil
        pairingHint = nil
        reconnectGuide = nil
        standardHRMode = nil
        relayedBatteryEstimate = nil
        remoteSession = nil
        remoteCommandAck = nil
        remoteSource = nil
    }
}
