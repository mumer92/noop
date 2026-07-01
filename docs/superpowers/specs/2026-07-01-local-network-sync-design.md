# Local-Network Sync (iPhone → Mac mirror) — Design Spec

**Date:** 2026-07-01
**Status:** Draft for review
**Scope:** A **one-way, automatic, LAN-only** sync that mirrors the iPhone's NOOP database onto the
Mac NOOP app, with **no cloud and no account** — data never leaves your own devices/local network.

---

## 1. Goals & constraints

**Problem.** NOOP is account-free and cloud-free, so each device keeps its own SQLite DB. A WHOOP
strap bonds to **one** collector at a time (the iPhone), so the Mac can't independently pull from the
strap. Today the only way to see iPhone data on the Mac is a manual export → import. We want the Mac
to **automatically mirror** the iPhone's data over the local network, with zero third-party servers.

**Decisions locked in brainstorming:**
- **Direction:** one-way **iPhone → Mac** (Mac is a read-only mirror). iPhone stays the sole strap collector.
- **Trigger:** **automatic** when both apps are active on the same network (see §8 for the honest limits).
- **Transport:** **Network.framework** (Bonjour + `NWListener`/`NWBrowser`/`NWConnection`), TLS-PSK.
- **Payload:** the existing **`.noopbak`** whole-DB snapshot; the Mac restores it via existing `DataBackup`.

**Hard constraints (must not violate NOOP's ethos):**
- **LAN-only.** No internet, no server, no account. The connection must refuse anything that isn't a
  direct local-network peer. Nothing is ever sent off your devices.
- **Opt-in, off by default.** No networking happens until the user pairs the two devices and enables sync.
- **Encrypted + authenticated.** Only *your* paired Mac can receive the data; a stranger on the same
  WiFi can neither read it (TLS) nor request it (pairing/PSK).
- **Reuse, don't reinvent.** The transferred payload is the same `.noopbak` the backup feature already
  produces; the Mac side is "receive blob → `DataBackup.restore` (snapshot-first, validated)."

---

## 2. Research synthesis (why this design)

Validated via Apple docs + community (see §12 sources):

- **Apple recommends Network.framework over Multipeer Connectivity for new code.** Multipeer hasn't
  evolved, is built on the deprecation-scheduled `NSStream`, lacks flow control, and always forces
  peer-to-peer Wi-Fi. The modern path is `NWListener` (advertise) + `NWBrowser` (discover) +
  `NWConnection` (connect) over Bonjour.
- **Apple's own reference (WWDC 2019 "Advances in Networking, Part 2", the tic-tac-toe sample)** does
  exactly this: advertise `_tictactoe._tcp`, discover with `NWBrowser`, connect with `NWConnection`,
  and secure it with **TLS derived from a passcode** — i.e. the pairing-code → PSK model here.
- **TLS-PSK is the recommended security for peer-to-peer** ("easier to deploy in a peer-to-peer
  environment"). Derive a symmetric key from the pairing code (HMAC) and use
  `TLS_PSK_WITH_AES_128_GCM_SHA256`. Sniffers see AES-GCM ciphertext only.
- **iOS Local Network privacy (iOS 14+, TN3179):** the app must declare `NSLocalNetworkUsageDescription`
  and `NSBonjourServices` (`_noopsync._tcp`) and the system shows a one-time permission prompt.

**Conclusion:** the chosen stack is Apple's documented, blessed pattern — not exotic. The security
model (TLS-PSK from a pairing code) is exactly what Apple ships in their sample.

---

## 3. Architecture overview

```
┌──────────────── iPhone (SERVER / source of truth) ────────────────┐
│  LocalSyncService (iOS)                                            │
│   • NWListener advertises Bonjour "_noopsync._tcp" (+ TLS-PSK)     │
│   • On a paired peer connect: checkpoint DB → make .noopbak →      │
│     stream it (length-prefixed) → close                           │
│   • Advertises a TXT record: {dbVersion, latestDayKey, revision}  │
└───────────────────────────────┬───────────────────────────────────┘
                                 │  TLS-PSK NWConnection (LAN only)
                                 │  length-prefixed .noopbak bytes
┌───────────────────────────────▼───────────────────────────────────┐
│  LocalSyncService (macOS) — CLIENT / mirror                        │
│   • NWBrowser discovers "_noopsync._tcp"                           │
│   • Filters to the PAIRED peer (identity in TXT/PSK)              │
│   • Reads TXT revision; if newer than local, connects & pulls     │
│   • Receives .noopbak → DataBackup.restore (snapshot-first)       │
└────────────────────────────────────────────────────────────────────┘
```

**Roles.** The **iPhone is the server** (it owns the truth and listens); the **Mac is the client**
(it discovers, decides it's stale, and pulls). This matches the one-way direction and keeps the
iPhone from ever having to know/track Macs — it just answers authenticated pull requests.

**Why pull, not push:** the Mac knows its own last-synced revision, so it decides when to pull. The
iPhone stays stateless (no list of Macs, no push scheduling) — simpler and more private.

---

## 4. Components (each small, testable, single-purpose)

New code lives in a `LocalSync` area, shared where possible (`Strand/Sync/`), `#if os` split only at
the transport edges.

1. **`SyncPairing`** — stores the pairing secret + peer identity in the Keychain. API:
   `pair(code:) -> PairedPeer`, `pairedPeer -> PairedPeer?`, `unpair()`. The 6-digit code seeds the
   PSK (HMAC-SHA256 → symmetric key). Pure, unit-testable.
2. **`SyncTLS`** — builds `NWParameters` with TLS-PSK from the pairing secret (the one Apple-sample
   extension: passcode → `sec_protocol_options_add_pre_shared_key`). Shared iOS/macOS. Unit-testable
   (given a code, produces deterministic PSK params).
3. **`SyncFraming`** — length-prefixed message framing over `NWConnection` (a 4-byte big-endian length
   + payload). Pure, unit-testable with in-memory pipes.
4. **`SyncServer` (iOS)** — owns the `NWListener`, advertises `_noopsync._tcp` + TXT record, accepts
   only PSK-authenticated connections, and on request: `await DataBackup.writeBackup(to: temp)` →
   stream. Depends on `SyncTLS`, `SyncFraming`, `DataBackup`, `Repository`.
5. **`SyncClient` (macOS)** — owns the `NWBrowser`, filters to the paired peer, compares TXT `revision`
   to the local last-synced revision, and when stale connects → receives `.noopbak` → `DataBackup.restore`.
   Depends on `SyncTLS`, `SyncFraming`, `DataBackup`.
6. **`SyncState`** — an `ObservableObject` for the UI: `.idle / .discovering / .transferring(progress)
   / .upToDate / .error`, last-sync timestamp, paired-peer label. Drives the Settings screen.
7. **`SyncSettingsView`** — pairing flow (enable, show/enter the 6-digit code, pair, status, "sync now",
   unpair). Mirrors the existing `BackupSyncView` idiom.

Boundaries: transport (`Server`/`Client`) never touches the DB directly — it goes through `DataBackup`.
Pairing/TLS never touch the network. Framing never knows about backups. Each unit is replaceable.

---

## 5. Data flow (happy path)

1. **Pair once.** iPhone: Settings → Local Sync → Enable → shows a 6-digit code. Mac: Settings → Local
   Sync → Enable → enter the code. Both derive the same PSK and store the peer identity in Keychain.
2. **Advertise.** When enabled + foreground/active, the iPhone `NWListener` advertises `_noopsync._tcp`
   with a TXT record `{rev: <monotonic revision>, day: <latestDayKey>, v: <dbSchemaVersion>}`.
3. **Discover.** The Mac `NWBrowser` sees the service, matches the paired peer, reads TXT `rev`.
4. **Decide.** If `rev > localSyncedRev`, the Mac opens a TLS-PSK `NWConnection`.
5. **Authenticate.** TLS-PSK handshake — succeeds only if both sides hold the pairing secret. A stranger
   without the code fails the handshake and gets nothing.
6. **Transfer.** iPhone checkpoints the WAL, writes a fresh `.noopbak` to a temp file, streams it
   length-prefixed. Mac receives to a temp file, verifying the framed length.
7. **Restore.** Mac calls `DataBackup.restore(from: temp)` — which **snapshots the current Mac DB first,
   validates the incoming file is a real NOOP DB, then swaps it in** (existing, battle-tested path).
8. **Record.** Mac sets `localSyncedRev = rev`, updates last-sync time; `SyncState → .upToDate`.

The iPhone's **revision** bumps whenever its data changes (hook into `Repository.refreshSeq` / the
same signal that already fires on new offloads/imports), so the Mac only pulls when there's something new.

---

## 6. Security model

- **Encryption:** TLS 1.3 over `NWConnection`, **PSK** derived from the pairing code (AES-GCM). On-path
  attackers see ciphertext + metadata (that two peers talk, byte sizes/timing) — never health data.
- **Authentication / authorization:** the PSK *is* the authorization. Only a device that completed
  pairing (holds the secret) can complete the handshake, so only *your* Mac can pull. The iPhone also
  pins the paired peer identity (from TXT/connection) and ignores unpaired browsers.
- **LAN-only enforcement:** parameters use `prohibitedInterfaceTypes = [.cellular]` and
  `includePeerToPeer`, and the listener binds to the local link; the client refuses endpoints that
  aren't link-local / local Bonjour. No path to the public internet exists in the code.
- **Least data:** the TXT record carries only a revision counter + latest-day key + schema version —
  no health values, no identifiers beyond an opaque paired-peer id.
- **Revocation:** "Unpair" deletes the Keychain secret on either device; the next handshake fails.
- **Restore safety:** `DataBackup.restore` already snapshots-first + validates, so a corrupt/hostile
  payload can't silently wipe the Mac's data (worst case: restore rejects it, Mac keeps its snapshot).

---

## 7. iOS Local Network permission (required)

Add to the **iOS** target's Info.plist (via `project.yml`, so it survives regeneration):
- `NSLocalNetworkUsageDescription` = a plain-language string, e.g. *"NOOP uses your local network to
  send your data to the NOOP Mac app on the same Wi-Fi. Nothing leaves your devices."*
- `NSBonjourServices` = `["_noopsync._tcp"]`.

iOS shows a one-time permission prompt the first time the listener starts. If the user denies it, the
feature surfaces an honest "Local Network access is off — enable it in Settings" state and does nothing
else. (macOS has no equivalent prompt.)

---

## 8. "Automatic in the background" — the honest reality

iOS does **not** allow a general networking daemon in the background; suspended apps stop advertising.
So "automatic" concretely means:
- **iPhone:** advertises + serves while the app is **foreground or recently active** (and briefly in the
  background grace period). Opening the app re-advertises. This is enough for the common case ("I open
  NOOP on my phone in the morning; my Mac mirrors it").
- **Mac:** macOS is more permissive — the `NWBrowser` can keep discovering while the app runs, so the
  Mac pulls promptly whenever the iPhone is reachable.
- **Not** a 24/7 push. We will **not** claim always-on background sync. The UI copy says "syncs when
  both apps are open on the same network," and a manual **"Sync now"** is always available.

This is a deliberate scope choice consistent with the ethos (no background network abuse) and with iOS
platform limits — not a bug.

---

## 9. Error handling & edge cases

| Case | Behavior |
|---|---|
| Local Network permission denied (iOS) | Honest state + link to Settings; no retries hammering the prompt. |
| Networks with AP/client isolation (café/corporate) | Discovery finds nothing → "No paired device on this network." No error spam. |
| Wrong pairing code / stranger connects | TLS-PSK handshake fails → connection dropped, nothing served. |
| Transfer interrupted mid-stream | Framed length mismatch → Mac discards the temp file, keeps current DB, retries later. |
| Restore validation fails | `DataBackup.restore` rejects it; Mac keeps its pre-restore snapshot. Surface an error. |
| Mac had its own (older) data | One-way mirror = restore replaces it (snapshot-first). Documented; unpair to stop. |
| Schema version mismatch (old iPhone build ↔ new Mac) | TXT `v` compared; if incompatible, skip with a "update the other app" note rather than a bad restore. |
| Both apps updated mid-sync | Revision + schema-version gating prevents applying a stale/incompatible pull. |

---

## 10. UI (Settings → Local Sync)

Mirror the `BackupSyncView` pattern:
- **Enable Local Sync** toggle (off by default).
- **Pairing:** on iPhone, "Show pairing code" (6 digits, rotates); on Mac, "Enter pairing code."
- **Status card:** paired-peer label, `SyncState` (Discovering / Up to date / Syncing… / Error),
  last-sync time.
- **Sync now** button (manual pull).
- **Unpair** (destructive) — clears the Keychain secret.
- Honest one-liner: "Syncs your data to your Mac over the local network. Nothing leaves your devices.
  Works when both apps are open on the same Wi-Fi."

---

## 11. Testing strategy

- **Unit:** `SyncPairing` (code → deterministic PSK), `SyncFraming` (round-trip over in-memory pipe,
  truncation/oversize rejection), `SyncTLS` (params built from a code), revision/schema comparison logic.
- **Integration (loopback):** run `SyncServer` + `SyncClient` on `localhost` in one process, transfer a
  seeded `.noopbak`, assert the client DB matches after restore.
- **Manual two-device:** the real iPhone + this Mac on the same Wi-Fi — pair, change data on the phone,
  confirm the Mac mirrors it; test permission-denied, wrong-code, and AP-isolation paths.
- Reuse the existing `DataBackup` round-trip tests for the payload half (already covered).

---

## 12. Phasing

- **Phase 1 — Manual, paired, secure.** Pairing (code→PSK), `NWListener`/`NWBrowser`/`NWConnection`
  with TLS-PSK, whole-`.noopbak` transfer, `DataBackup.restore`, a "Sync now" button, iOS permission
  plumbing. Ship this first — it's the whole security-critical core, testable end-to-end.
- **Phase 2 — Auto-on-change.** TXT revision gating so the Mac pulls automatically when the iPhone has
  new data and both are active; status UI polish.
- **Phase 3 — Incremental (optional).** Replace whole-DB transfer with a row-level diff since
  `localSyncedRev` for faster syncs on large histories. Only if the whole-DB transfer proves too slow.

Each phase is independently shippable; Phase 1 alone already delivers "my Mac mirrors my iPhone."

---

## 13. Open questions

1. **Pairing UX:** 6-digit code (simple, Apple-sample style) vs a QR code shown on the iPhone and read
   by the Mac camera (nicer, but Macs may lack a camera / more code). Recommendation: 6-digit first.
2. **Revision source:** reuse `Repository.refreshSeq`, or a persisted monotonic counter bumped on every
   DB mutation? Recommendation: a small persisted `syncRevision` bumped where offload/import commit, so
   it survives relaunch and is comparable across devices.
3. **Multiple Macs:** support pairing >1 Mac to one iPhone? Recommendation: allow N paired peers (the
   iPhone just answers any authenticated puller) — falls out of the pull model for free.
4. **Whole-DB size:** is replace-restore acceptable for a multi-year history over Wi-Fi (seconds), or is
   Phase 3 (incremental) needed sooner? Measure on real data before deciding.
5. **Upstream-ability:** this is ethos-adjacent (adds a Bonjour listener). Keep it as a personal
   local-only feature, or shape it (opt-in, off by default, LAN-only) to potentially propose upstream
   as the answer to issue #349? Recommendation: build behind the opt-in; decide on upstreaming later.

---

## 14. Decision log

- **Network.framework over Multipeer:** Apple's current recommendation; Multipeer is legacy (`NSStream`,
  no back-pressure, forced P2P Wi-Fi).
- **TLS-PSK from a pairing code:** Apple's documented P2P security pattern (WWDC19 sample); simplest way
  to get encryption + authorization from one shared secret.
- **iPhone = server, Mac = pull client:** keeps the iPhone stateless about Macs; the Mac owns "am I stale?".
- **Reuse `.noopbak` + `DataBackup.restore`:** the payload and the snapshot-first, validated restore
  already exist and are tested — the feature is mostly transport + pairing.
- **One-way mirror, manual-then-auto:** matches the strap-is-single-collector reality and the maintainer's
  suggested "read-only Mac mirror" first scope (#349); avoids bidirectional conflict complexity (YAGNI).
- **Honest "automatic":** scoped to foreground/active + "Sync now", never claiming a 24/7 background
  daemon, consistent with iOS limits and the no-network-abuse ethos.

---

## Sources

- WWDC 2019 "Advances in Networking, Part 2" (P2P Bonjour + TLS sample) — developer.apple.com/videos/play/wwdc2019/713/
- Network framework Security Options / TLS-PSK — developer.apple.com/documentation/network/security-options
- Apple TLS security (TLS-PSK for peer-to-peer) — support.apple.com/guide/security/tls-security-sec100a75d12/web
- TN3179 Understanding local network privacy — developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- NSLocalNetworkUsageDescription / NSBonjourServices — developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription
- Network.framework + Bonjour walkthrough — boramaapps.medium.com/ios-osx-connections-with-network-framework-and-bonjour-service-7fa6130f5789
- Related upstream request — github.com/NoopApp/noop/issues/349 (optional iCloud sync iOS↔macOS)
