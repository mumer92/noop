# Live Relay (iPhone → Mac real-time) Design Spec

**Date:** 2026-07-01
**Status:** Draft for review
**Depends on:** `2026-07-01-local-network-sync-design.md` (the history mirror + pairing + TLS-PSK transport)

---

## 1. Goal

Make the **iPhone the hub that pushes everything to the Mac** over the local network:

1. **History** (already built) — the whole database (scores, sleep, history) is mirrored to the Mac.
2. **Live state** (this spec) — while both apps are open on the same Wi-Fi, the iPhone **streams its
   real-time state** (heart rate, strap-connected, battery, R-R, worn) to the Mac ~1 Hz, so the Mac's
   dashboard shows **live HR** and a **"Connected — via iPhone"** badge instead of "Strap not connected."

The strap bonds to one collector (the iPhone). The Mac has no strap of its own, so today its badge
correctly reads "not connected." The fix is not to pretend the Mac has a strap — it's to **relay the
iPhone's live truth** and label it honestly as coming from the phone.

**Non-goals:** the Mac never talks to the strap directly; live relay is best-effort and only while both
apps are active (see constraints). No cloud, LAN-only, opt-in, reusing the existing paired TLS-PSK link.

---

## 2. Architecture — two channels over one pairing

```
 WHOOP strap ──BLE──► iPhone  (source of truth: reads strap, computes, stores)
                        │
                        ├── HISTORY channel: whole-DB .noopbak, pulled on change  ──► Mac restores it
                        │
                        └── LIVE channel: LiveSnapshot ~1 Hz, streamed while open  ──► Mac LiveState
                                                                                        (live HR + "via iPhone")
```

- **iPhone = broadcaster/server.** Advertises `_noopsync._tcp`, authenticates peers with TLS-PSK,
  serves the DB on request AND streams live snapshots on a subscription.
- **Mac = subscriber/client.** Discovers the iPhone, opens a **persistent** live connection, and applies
  each snapshot to its own `LiveState`. Separately pulls the DB (history channel) on connect / on change.

Two **separate connections** (not multiplexed) keeps each simple: history is a short request/response;
live is a long-lived stream. Both use the same `SyncTLS` params + pairing PSK.

---

## 3. Data model & protocol additions

### 3.1 `LiveSnapshot` (new, in `StrandSync`, `Codable` + `Sendable`)

```swift
public struct LiveSnapshot: Codable, Sendable, Equatable {
    public var heartRate: Int?      // current bpm, nil if none
    public var connected: Bool      // iPhone↔strap BLE link
    public var bonded: Bool         // encrypted bond established
    public var batteryPct: Double?  // strap battery %
    public var charging: Bool?
    public var worn: Bool
    public var rr: [Int]            // recent R-R intervals (ms), capped (e.g. last 8)
    public var ts: Double           // epoch seconds, for staleness/ordering
    public init(...)                // memberwise
}
```

Encoded as JSON `Data` and carried in a framed message.

### 3.2 `SyncMessage` additions (extend the existing enum)

```swift
case subscribeLive               // client → server: "stream me live snapshots"
case liveSnapshot(Data)          // server → client: one JSON-encoded LiveSnapshot
case historyChanged(UInt64)      // server → client: "my DB revision is now N" (client pulls if newer)
```

Wire tags 4/5/6 (1–3 already used by pull/backupChunk/done). `encoded()`/`decode()` gain the new tags.

### 3.3 Why a `historyChanged` signal

Today the Mac pulls the DB on discovery and via "Sync now". Adding `historyChanged(rev)` on the live
connection lets the iPhone **notify** the Mac the instant new data lands (offload/import), so the Mac
pulls the fresh DB automatically — i.e. history becomes **push-triggered** ("all data pushed from the
mobile") without the iPhone having to hold/track Macs.

---

## 4. New components

### 4.1 `SyncLiveServer` (iOS, in `StrandSync` — payload-agnostic)

```swift
public final class SyncLiveServer {
    public init(psk: SymmetricKey,
                snapshot: @escaping () -> LiveSnapshot,   // pulls the current LiveSnapshot
                revision: @escaping () -> UInt64)          // current DB revision for historyChanged
    public func start() throws                             // NWListener on _noopsync-live._tcp (or reuse)
    public func broadcastLive()                            // send current snapshot to all subscribers
    public func broadcastHistoryChanged()                  // send historyChanged to all subscribers
    public func stop()
}
```

Holds the set of live subscriber connections. On `.subscribeLive`, adds the connection and immediately
sends the current snapshot + revision. `broadcastLive()` fans the latest snapshot to all subscribers;
called ~1 Hz (driven by the coordinator observing `LiveState.$heartRate`).

> Transport note: to avoid entangling the short history-pull connections with long-lived live streams,
> the live stream uses a **distinct Bonjour type `_noopsync-live._tcp`** (own listener), or the same
> listener with the message tag distinguishing intent. Recommendation: **separate listener/type** —
> cleanest lifecycle. (Open question Q1.)

### 4.2 `SyncLiveClient` (macOS, in `StrandSync`)

```swift
public final class SyncLiveClient {
    public init(psk: SymmetricKey,
                onSnapshot: @escaping (LiveSnapshot) -> Void,
                onHistoryChanged: @escaping (UInt64) -> Void,
                onConnectionChange: @escaping (Bool) -> Void)  // true=live link up, false=down
    public func connect(to endpoint: NWEndpoint)               // persistent; sends .subscribeLive
    public func disconnect()
}
```

Maintains one persistent connection to the paired iPhone; decodes `.liveSnapshot`/`.historyChanged`;
reports link up/down so the Mac can revert to "not connected" when the stream drops.

### 4.3 `LiveState` extensions (app module, both platforms)

```swift
extension LiveState {
    /// The label to show when live data is relayed from another device (e.g. "iPhone"); nil = local strap.
    @Published public var remoteSource: String?   // add stored @Published

    /// Apply a relayed snapshot from the paired iPhone. Sets HR/connected/battery/etc and marks the source.
    func applyRemote(_ s: LiveSnapshot, from source: String)

    /// Called when the relay link drops or a snapshot goes stale — revert to disconnected.
    func clearRemote()
}
```

`applyRemote` sets `heartRate`, `connected = s.connected`, `bonded`, `batteryPct`, `charging`, `worn`,
`rr`, and `remoteSource = source`. `clearRemote` sets `connected=false`, `heartRate=nil`,
`remoteSource=nil`. The Mac's own BLE never fights this (it has no strap), so the relay owns the badge.

### 4.4 `SyncCoordinator` changes

- Gains a `live: LiveState` reference (from `AppModel`).
- **iOS:** owns a `SyncLiveServer` with `snapshot: { LiveSnapshot(from: self.live) }`; observes
  `live.$heartRate`/`$connected`/`$batteryPct` (Combine) and calls `broadcastLive()` (throttled ~1 Hz);
  calls `broadcastHistoryChanged()` when `repo.refreshSeq`/revision bumps.
- **macOS:** owns a `SyncLiveClient`; `onSnapshot` → `live.applyRemote(_, from: "iPhone")`;
  `onHistoryChanged` → trigger the existing history pull; `onConnectionChange(false)` /staleness →
  `live.clearRemote()`.

### 4.5 UI: the connection badge (macOS `RootView`)

`RootView`'s sidebar badge reads `live.connected` + `live.batteryPct`. Add: when
`live.remoteSource != nil`, render **"Connected · via iPhone"** (and battery), so it's honest that the
link is relayed, not a local strap. Live-HR views already read `live.heartRate` — they light up for free.

---

## 5. Data flow (live)

1. Mac discovers the iPhone (existing Bonjour browse).
2. Mac `SyncLiveClient.connect(endpoint)` → TLS-PSK handshake → sends `.subscribeLive`.
3. iPhone `SyncLiveServer` registers the subscriber, immediately sends current `LiveSnapshot` + `historyChanged(rev)`.
4. iPhone streams a fresh `LiveSnapshot` whenever `LiveState` changes (≤1 Hz), e.g. each HR tick.
5. Mac `onSnapshot` → `live.applyRemote(...)` → dashboard live HR + "Connected · via iPhone" update.
6. On new strap data (offload/import) the iPhone sends `historyChanged(newRev)` → Mac pulls the DB
   (history channel) → `reopenAfterRestore()` → history refreshes in place.
7. iPhone backgrounds / app closes / Wi-Fi drops → connection ends → Mac `onConnectionChange(false)` →
   `clearRemote()` → badge returns to "Strap not connected."

**Staleness guard:** the Mac also runs a timer; if no snapshot arrives for ~5 s, `clearRemote()` (covers
a silently-wedged link).

---

## 6. Constraints & honesty (unchanged principles)

- **Both apps open, same non-isolated Wi-Fi.** iOS suspends backgrounded apps, so the iPhone streams
  only while foreground/active. When it suspends, the Mac shows disconnected — correct, not a bug.
- **"via iPhone" labeling.** The Mac never claims a local strap. The badge and any live view make the
  relayed source explicit.
- **LAN-only, opt-in, encrypted** — same pairing + TLS-PSK as the history channel. No cloud.
- **One-way.** Live + history both flow iPhone → Mac only.

---

## 7. Error handling

| Case | Behavior |
|---|---|
| Live link drops (iPhone backgrounds / Wi-Fi lost) | Mac `clearRemote()` → "Strap not connected"; client retries with backoff. |
| Snapshot stale (>5 s) | `clearRemote()` even if the socket looks open. |
| Wrong PSK / unpaired | TLS handshake fails → no stream (same as history). |
| Multiple Macs subscribe | iPhone fans out to all subscriber connections. |
| Malformed snapshot | Dropped (decode returns nil); link stays up. |

---

## 8. Testing

- **Unit (StrandSync):** `LiveSnapshot` JSON round-trip; `SyncMessage` new tags round-trip.
- **Loopback integration:** `SyncLiveServer` + `SyncLiveClient` in-process — subscribe, push N snapshots,
  assert the client receives them in order; assert `onConnectionChange(false)` on server stop.
- **Two-device manual:** HR ticking on the Mac within ~1 s of the iPhone; badge shows "via iPhone";
  background the iPhone → Mac reverts to disconnected; new offload → Mac history refreshes live.

---

## 9. Phasing

- **Phase 1 — Live HR + connection badge.** `LiveSnapshot`, protocol tags, `SyncLiveServer`/`Client`,
  coordinator wiring, `LiveState.applyRemote/clearRemote/remoteSource`, the "via iPhone" badge. Loopback
  test. This delivers the visible win: live HR + "Connected via iPhone" on the Mac.
- **Phase 2 — Push-triggered history.** `historyChanged(rev)` on the live link → Mac auto-pulls the DB
  the instant the iPhone gets new data (no polling), so *all* data is pushed from the phone.
- **Phase 3 — Robustness.** Reconnect backoff, staleness tuning, multi-Mac, battery/CPU throttling of
  the 1 Hz stream when nothing changes.

Each phase is independently shippable; Phase 1 is the one you asked for.

---

## 10. Open questions

1. **Separate Bonjour type (`_noopsync-live._tcp`) vs one listener with message-tag routing?**
   Recommendation: separate listener/type — cleanest lifecycle for a long-lived stream vs short pulls.
2. **Stream cadence:** push on every `LiveState` change (event-driven, up to ~1 Hz from HR) vs a fixed
   1 Hz timer. Recommendation: event-driven, coalesced to ≤1 Hz.
3. **Revision source for `historyChanged`:** reuse `repo.refreshSeq` (session) or a persisted monotonic
   `syncRevision`. Recommendation: a persisted counter bumped on offload/import commit (survives relaunch).
4. **Mac-side ownership of `LiveState`:** the Mac already has a `LiveState` (its own, idle). Confirm
   feeding it via `applyRemote` doesn't conflict with any Mac BLE path (it shouldn't — no strap on Mac).

---

## 11. Decision log

- **Relay live state, don't fake a local strap:** honest "via iPhone" badge; strap is single-collector.
- **Two channels, two connections:** short history pull + long-lived live stream — simplest lifecycles.
- **iPhone broadcaster / Mac subscriber:** matches the existing server/client roles; iPhone stays
  stateless about Macs beyond the set of live subscribers.
- **`historyChanged` push signal:** makes "all data pushed from the phone" real without polling.
- **Best-effort, both-apps-open:** consistent with iOS background limits and the no-daemon/no-cloud ethos.
