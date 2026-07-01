# Local-Network Sync (iPhone → Mac) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the iPhone's NOOP database onto the Mac app automatically over the local network — no cloud, no account — using Bonjour discovery + a TLS-PSK connection, transferring the existing `.noopbak` snapshot.

**Architecture:** iPhone = server (advertises `_noopsync._tcp`, serves a `.noopbak` to an authenticated peer). Mac = client (discovers, compares a revision counter, pulls, and restores via existing `DataBackup`). Security is TLS-PSK derived from a 6-digit pairing code — Apple's documented peer-to-peer pattern. Pure logic (framing, key derivation, protocol) lives in a new `StrandSync` SPM package for fast `swift test`; transport + UI live in the app module because they need `Repository`/`DataBackup`.

**Tech Stack:** Swift, Network.framework (`NWListener`/`NWBrowser`/`NWConnection`), CryptoKit (HKDF), Security/Keychain, SwiftUI, swift-testing (package) + XCTest (`StrandTests`).

**Spec:** `docs/superpowers/specs/2026-07-01-local-network-sync-design.md`

## Global Constraints

- **LAN-only.** `NWParameters` must set `prohibitedInterfaceTypes = [.cellular]` and use `includePeerToPeer = true`; no `URLSession`, no remote hosts. Data never leaves the local link.
- **Opt-in, off by default.** No listener/browser starts until the user enables sync AND a paired peer exists.
- **Encrypted + authenticated.** Every connection uses TLS-PSK from the pairing secret. No unauthenticated path serves data.
- **Reuse `.noopbak`.** Payload = `DataBackup.writeBackup(to:)`; apply = `DataBackup.restore(from:)` (already snapshots-first + validates). Do NOT write a new DB-mutation path.
- **iOS permission.** iOS target Info.plist must declare `NSLocalNetworkUsageDescription` + `NSBonjourServices = ["_noopsync._tcp"]` (via `project.yml`).
- **Bonjour service type:** exactly `_noopsync._tcp`. **Revision** is a monotonic `UInt64`. **Pairing code** is 6 decimal digits.
- **Honest "automatic":** foreground/active + "Sync now"; never claim 24/7 background.

---

## File Structure

**New SPM package `Packages/StrandSync`** (pure, unit-tested via `swift test`):
- `Sources/StrandSync/SyncFraming.swift` — 4-byte big-endian length-prefixed framing (encode/decode).
- `Sources/StrandSync/SyncCrypto.swift` — 6-digit code → 32-byte PSK via HKDF-SHA256 with a fixed salt/info.
- `Sources/StrandSync/SyncProtocol.swift` — TXT-record model (`rev`, `day`, `v`) encode/decode; request/response tags.
- `Sources/StrandSync/SyncTLS.swift` — build `NWParameters` (TLS-PSK) from the PSK + LAN-only flags.
- `Tests/StrandSyncTests/*` — framing round-trip, crypto determinism, protocol codec, params sanity.

**App module (`Strand/Sync/`)** (needs `Repository`/`DataBackup`/UI):
- `SyncPairing.swift` — Keychain-backed pairing store (save/load/clear the PSK + peer id). Shared.
- `SyncServer.swift` (`#if os(iOS)`) — `NWListener`, advertise TXT, serve `.noopbak`.
- `SyncClient.swift` (`#if os(macOS)`) — `NWBrowser`, filter to paired peer, pull + restore.
- `SyncCoordinator.swift` — `ObservableObject` (`SyncState`, last-sync, peer label); owns server/client per platform; opt-in gating.
- `SyncSettingsView.swift` — Settings UI: enable, show/enter code, status, Sync now, unpair.

**Modified:**
- `project.yml` — add the `StrandSync` package dep to app targets; add iOS Info.plist keys.
- `Strand/Screens/SettingsView.swift` — add a "Local Sync" row → `SyncSettingsView`.
- `Strand/App/AppModel.swift` — own a `SyncCoordinator`, start/stop with scene/enable.
- `StrandTests/SyncLoopbackTests.swift` — in-process server↔client loopback over `.noopbak`.

---

## Task 1: Scaffold the `StrandSync` package + wire into the build

**Files:**
- Create: `Packages/StrandSync/Package.swift`
- Create: `Packages/StrandSync/Sources/StrandSync/SyncFraming.swift`
- Create: `Packages/StrandSync/Tests/StrandSyncTests/SyncFramingTests.swift`
- Modify: `project.yml` (add local package + dependency on the app targets)

**Interfaces:**
- Produces: `enum SyncFraming { static func frame(_ payload: Data) -> Data; static func decode(_ buffer: inout Data) -> Data? }` — `frame` prepends a 4-byte BE length; `decode` pops one complete message from an accumulating buffer (returns nil if incomplete).

- [ ] **Step 1: Write the failing test**

```swift
// Packages/StrandSync/Tests/StrandSyncTests/SyncFramingTests.swift
import Testing
import Foundation
@testable import StrandSync

@Test func framing_roundTrips_singleMessage() {
    let payload = Data("hello noop".utf8)
    var buffer = SyncFraming.frame(payload)
    let decoded = SyncFraming.decode(&buffer)
    #expect(decoded == payload)
    #expect(buffer.isEmpty)          // fully consumed
}

@Test func framing_returnsNil_whenIncomplete() {
    let payload = Data(repeating: 7, count: 100)
    var framed = SyncFraming.frame(payload)
    var partial = framed.prefix(20)  // header + a few bytes only
    var buf = Data(partial)
    #expect(SyncFraming.decode(&buf) == nil)   // not enough yet
    _ = framed; _ = partial
}

@Test func framing_popsOneMessage_leavesRemainder() {
    var buf = SyncFraming.frame(Data("a".utf8))
    buf.append(SyncFraming.frame(Data("bb".utf8)))
    #expect(SyncFraming.decode(&buf) == Data("a".utf8))
    #expect(SyncFraming.decode(&buf) == Data("bb".utf8))
    #expect(SyncFraming.decode(&buf) == nil)
}
```

- [ ] **Step 2: Create the package manifest**

```swift
// Packages/StrandSync/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StrandSync",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "StrandSync", targets: ["StrandSync"])],
    targets: [
        .target(name: "StrandSync"),
        .testTarget(name: "StrandSyncTests", dependencies: ["StrandSync"]),
    ]
)
```

- [ ] **Step 3: Implement `SyncFraming`**

```swift
// Packages/StrandSync/Sources/StrandSync/SyncFraming.swift
import Foundation

/// Length-prefixed message framing over a byte stream: a 4-byte big-endian UInt32 length
/// followed by that many payload bytes. `decode` pops exactly one complete message from an
/// accumulating buffer, or returns nil when the buffer doesn't yet hold a full message.
public enum SyncFraming {
    public static func frame(_ payload: Data) -> Data {
        var out = Data(capacity: payload.count + 4)
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    public static func decode(_ buffer: inout Data) -> Data? {
        guard buffer.count >= 4 else { return nil }
        let len = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let total = 4 + Int(len)
        guard buffer.count >= total else { return nil }
        let payload = buffer.subdata(in: 4..<total)
        buffer.removeSubrange(0..<total)
        return payload
    }
}
```

- [ ] **Step 4: Register the package in `project.yml`**

Under `packages:` add `StrandSync: { path: Packages/StrandSync }`. Add `- package: StrandSync` to the `dependencies:` of the `NOOPiOS`, `Strand` (macOS), and `StrandTests` targets. Then `xcodegen generate`.

- [ ] **Step 5: Run tests**

Run: `cd Packages/StrandSync && swift test`
Expected: 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/StrandSync project.yml
git commit -m "feat(sync): StrandSync package + length-prefixed framing"
```

---

## Task 2: `SyncCrypto` — pairing code → PSK

**Files:**
- Create: `Packages/StrandSync/Sources/StrandSync/SyncCrypto.swift`
- Test: `Packages/StrandSync/Tests/StrandSyncTests/SyncCryptoTests.swift`

**Interfaces:**
- Produces: `enum SyncCrypto { static func psk(fromCode code: String) -> SymmetricKey; static func generateCode() -> String }`. `psk` is deterministic (same code → same key) via HKDF-SHA256 with fixed salt `"noop.localsync.v1"` and info `"psk"`. `generateCode()` returns 6 decimal digits.

- [ ] **Step 1: Write the failing test**

```swift
// SyncCryptoTests.swift
import Testing
import CryptoKit
@testable import StrandSync

@Test func psk_isDeterministic_forSameCode() {
    let a = SyncCrypto.psk(fromCode: "402913")
    let b = SyncCrypto.psk(fromCode: "402913")
    #expect(a == b)
}
@Test func psk_differs_forDifferentCodes() {
    #expect(SyncCrypto.psk(fromCode: "000000") != SyncCrypto.psk(fromCode: "000001"))
}
@Test func generateCode_isSixDigits() {
    let c = SyncCrypto.generateCode()
    #expect(c.count == 6)
    #expect(c.allSatisfy(\.isNumber))
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test` → FAIL (SyncCrypto undefined).

- [ ] **Step 3: Implement**

```swift
// SyncCrypto.swift
import Foundation
import CryptoKit

public enum SyncCrypto {
    private static let salt = Data("noop.localsync.v1".utf8)
    private static let info = Data("psk".utf8)

    /// Deterministically derive a 256-bit pre-shared key from the pairing code (HKDF-SHA256).
    public static func psk(fromCode code: String) -> SymmetricKey {
        let ikm = SymmetricKey(data: Data(code.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: info, outputByteCount: 32)
    }

    /// A fresh 6-digit pairing code. Not for Math.random-style predictability — uses the system CSPRNG.
    public static func generateCode() -> String {
        let n = UInt32.random(in: 0..<1_000_000)   // SystemRandomNumberGenerator (CSPRNG)
        return String(format: "%06u", n)
    }
}
```

- [ ] **Step 4: Run tests** — `swift test` → PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(sync): PSK derivation from pairing code (HKDF)"`.

---

## Task 3: `SyncProtocol` — TXT record + message tags

**Files:**
- Create: `Packages/StrandSync/Sources/StrandSync/SyncProtocol.swift`
- Test: `Packages/StrandSync/Tests/StrandSyncTests/SyncProtocolTests.swift`

**Interfaces:**
- Produces:
  `struct SyncAdvert: Equatable { var rev: UInt64; var day: String; var v: Int; func txtDictionary() -> [String:String]; init?(txt: [String:String]) }`
  and `enum SyncMessage { case pullRequest; case backupChunk(Data); case done; var wireTag: UInt8 }` with `static func decode(_ data: Data) -> SyncMessage?`.

- [ ] **Step 1: Write the failing test**

```swift
// SyncProtocolTests.swift
import Testing
@testable import StrandSync
import Foundation

@Test func advert_txt_roundTrips() {
    let a = SyncAdvert(rev: 42, day: "2026-07-01", v: 3)
    let txt = a.txtDictionary()
    #expect(SyncAdvert(txt: txt) == a)
}
@Test func advert_rejectsMissingKeys() {
    #expect(SyncAdvert(txt: ["rev": "1"]) == nil)   // missing day/v
}
@Test func message_pullRequest_roundTrips() {
    let data = SyncMessage.pullRequest.encoded()
    if case .pullRequest? = SyncMessage.decode(data) {} else { Issue.record("wrong tag") }
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test` → FAIL.

- [ ] **Step 3: Implement**

```swift
// SyncProtocol.swift
import Foundation

public struct SyncAdvert: Equatable {
    public var rev: UInt64
    public var day: String
    public var v: Int
    public init(rev: UInt64, day: String, v: Int) { self.rev = rev; self.day = day; self.v = v }
    public func txtDictionary() -> [String: String] { ["rev": String(rev), "day": day, "v": String(v)] }
    public init?(txt: [String: String]) {
        guard let r = txt["rev"].flatMap(UInt64.init), let d = txt["day"],
              let vv = txt["v"].flatMap(Int.init) else { return nil }
        self.init(rev: r, day: d, v: vv)
    }
}

public enum SyncMessage {
    case pullRequest          // client → server: "send me your latest backup"
    case backupChunk(Data)    // server → client: one chunk of the .noopbak
    case done                 // server → client: end of stream

    public var wireTag: UInt8 { switch self { case .pullRequest: 1; case .backupChunk: 2; case .done: 3 } }

    public func encoded() -> Data {
        var d = Data([wireTag]); if case let .backupChunk(payload) = self { d.append(payload) }; return d
    }
    public static func decode(_ data: Data) -> SyncMessage? {
        guard let tag = data.first else { return nil }
        switch tag {
        case 1: return .pullRequest
        case 2: return .backupChunk(data.dropFirst())
        case 3: return .done
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run tests** — PASS. **Step 5: Commit** — `git commit -am "feat(sync): advert TXT + message protocol"`.

---

## Task 4: `SyncTLS` — LAN-only TLS-PSK parameters

**Files:**
- Create: `Packages/StrandSync/Sources/StrandSync/SyncTLS.swift`
- Test: `Packages/StrandSync/Tests/StrandSyncTests/SyncTLSTests.swift`

**Interfaces:**
- Produces: `enum SyncTLS { static func parameters(psk: SymmetricKey, identity: String) -> NWParameters }` — returns TCP params with TLS-PSK options set (cipher `TLS_PSK_WITH_AES_128_GCM_SHA256`), `includePeerToPeer = true`, `prohibitedInterfaceTypes = [.cellular]`.

- [ ] **Step 1: Write the failing test** (sanity: params build + are LAN-only)

```swift
// SyncTLSTests.swift
import Testing
import Network
import CryptoKit
@testable import StrandSync

@Test func tls_params_areLanOnly_andPeerToPeer() {
    let p = SyncTLS.parameters(psk: SymmetricKey(size: .bits256), identity: "noop")
    #expect(p.includePeerToPeer == true)
    #expect(p.prohibitedInterfaceTypes?.contains(.cellular) == true)
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test` → FAIL.

- [ ] **Step 3: Implement** (uses `sec_protocol_options_add_pre_shared_key` — Apple's WWDC19 passcode pattern)

```swift
// SyncTLS.swift
import Foundation
import Network
import CryptoKit

public enum SyncTLS {
    public static func parameters(psk: SymmetricKey, identity: String) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let keyData = psk.withUnsafeBytes { DispatchData(bytes: $0) }
        let idData = identity.data(using: .utf8)!.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions, keyData as __DispatchData, idData as __DispatchData)
        sec_protocol_options_append_tls_ciphersuite(
            tls.securityProtocolOptions,
            tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))!)
        let params = NWParameters(tls: tls)
        params.includePeerToPeer = true
        params.prohibitedInterfaceTypes = [.cellular]
        return params
    }
}
```

> NOTE (execution): the exact `DispatchData`/`sec_protocol` bridging can need small tweaks to satisfy the compiler; verify by building the package. The behavior (PSK + cipher + LAN-only flags) is the contract the test locks.

- [ ] **Step 4: Run tests** — PASS. **Step 5: Commit** — `git commit -am "feat(sync): LAN-only TLS-PSK NWParameters"`.

---

## Task 5: `SyncPairing` — Keychain-backed pairing store (app module)

**Files:**
- Create: `Strand/Sync/SyncPairing.swift`
- Test: `StrandTests/SyncPairingTests.swift`

**Interfaces:**
- Produces: `struct PairedPeer: Equatable { let code: String; let identity: String }` and
  `enum SyncPairing { static func save(_ peer: PairedPeer); static func load() -> PairedPeer?; static func clear() }`. Stores the code under a Keychain generic-password item (`service = "noop.localsync"`, `account = "pairing"`); `identity` is a stable local device id.

- [ ] **Step 1: Write the failing test**

```swift
// StrandTests/SyncPairingTests.swift
import XCTest
@testable import Strand   // app module

final class SyncPairingTests: XCTestCase {
    override func tearDown() { SyncPairing.clear() }
    func testSaveLoadRoundTrips() {
        SyncPairing.save(PairedPeer(code: "402913", identity: "mac-abc"))
        XCTAssertEqual(SyncPairing.load(), PairedPeer(code: "402913", identity: "mac-abc"))
    }
    func testClearRemoves() {
        SyncPairing.save(PairedPeer(code: "111111", identity: "x"))
        SyncPairing.clear()
        XCTAssertNil(SyncPairing.load())
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `xcodebuild -scheme Strand -destination 'platform=macOS' test` → FAIL.

- [ ] **Step 3: Implement** (Keychain generic-password; store `code|identity` as UTF-8)

```swift
// Strand/Sync/SyncPairing.swift
import Foundation
import Security

public struct PairedPeer: Equatable { public let code: String; public let identity: String }

public enum SyncPairing {
    private static let service = "noop.localsync"
    private static let account = "pairing"

    public static func save(_ peer: PairedPeer) {
        clear()
        let value = "\(peer.code)|\(peer.identity)".data(using: .utf8)!
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }
    public static func load() -> PairedPeer? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let s = String(data: data, encoding: .utf8) else { return nil }
        let parts = s.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return PairedPeer(code: parts[0], identity: parts[1])
    }
    public static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: account] as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests** — PASS. **Step 5: Commit** — `git commit -am "feat(sync): Keychain pairing store"`.

---

## Task 6: `SyncServer` (iOS) — advertise + serve the backup

**Files:**
- Create: `Strand/Sync/SyncServer.swift` (`#if os(iOS)`)
- (Integration is covered by the loopback test in Task 9.)

**Interfaces:**
- Consumes: `SyncTLS.parameters`, `SyncFraming`, `SyncProtocol`, `SyncPairing`, `DataBackup.writeBackup`.
- Produces: `final class SyncServer { init(psk: SymmetricKey, identity: String, advert: @escaping () -> SyncAdvert, makeBackup: @escaping () async -> URL?); func start() throws; func stop() }`.

- [ ] **Step 1: Implement** — `NWListener(using: SyncTLS.parameters(...))`; set `listener.service = NWListener.Service(type: "_noopsync._tcp", txtRecord: NWTXTRecord(advert().txtDictionary()))`; on `newConnectionHandler`, start the `NWConnection`, read framed `SyncMessage`; on `.pullRequest` → `await makeBackup()` → read the file → send it as one or more `.backupChunk` frames then `.done`; close. Re-publish the TXT whenever the advert revision changes.

- [ ] **Step 2: Compile-check** — `xcodebuildmcp simulator build --scheme NOOPiOS --simulator-name "iPhone 17 Pro"`. Expected: builds.

- [ ] **Step 3: Commit** — `git commit -am "feat(sync): iOS NWListener server serving .noopbak"`.

> Full behavior is asserted by the Task 9 loopback test (server + client in one process).

---

## Task 7: `SyncClient` (macOS) — discover + pull + restore

**Files:**
- Create: `Strand/Sync/SyncClient.swift` (`#if os(macOS)`)

**Interfaces:**
- Consumes: `SyncTLS`, `SyncFraming`, `SyncProtocol`, `SyncPairing`, `DataBackup.restore`.
- Produces: `final class SyncClient { init(psk: SymmetricKey, identity: String, lastSyncedRev: @escaping () -> UInt64, onRestored: @escaping (UInt64) -> Void); func start(); func syncNow(); func stop() }`.

- [ ] **Step 1: Implement** — `NWBrowser(for: .bonjourWithTXTRecord(type: "_noopsync._tcp", domain: nil), using: params)`; on results, read the TXT → `SyncAdvert`; if `advert.rev > lastSyncedRev()` (or `syncNow()`), open `NWConnection` to the endpoint with `SyncTLS.parameters`, send `.pullRequest`, accumulate `.backupChunk` payloads into a temp file until `.done`, then `DataBackup.restore(from: tempURL)`; on success call `onRestored(advert.rev)`. On any failure: discard temp, keep current DB.

- [ ] **Step 2: Compile-check** — `xcodebuildmcp macos build --scheme Strand`. Expected: builds.

- [ ] **Step 3: Commit** — `git commit -am "feat(sync): macOS NWBrowser client pull+restore"`.

---

## Task 8: `SyncCoordinator` + Settings UI + app wiring

**Files:**
- Create: `Strand/Sync/SyncCoordinator.swift` (shared `ObservableObject`)
- Create: `Strand/Sync/SyncSettingsView.swift`
- Modify: `Strand/Screens/SettingsView.swift` (add a "Local Sync" row)
- Modify: `Strand/App/AppModel.swift` (own a `SyncCoordinator`; start/stop on enable + scene-active)
- Modify: `project.yml` (iOS Info.plist: `NSLocalNetworkUsageDescription`, `NSBonjourServices`)

**Interfaces:**
- Produces: `final class SyncCoordinator: ObservableObject { enum State { case off, discovering, upToDate, syncing(Double), error(String) }; @Published var state; @Published var lastSync: Date?; @Published var pairedLabel: String?; func enable(); func disable(); func showPairingCode() -> String; func pair(code: String); func unpair(); func syncNow() }`. Platform-split internals own a `SyncServer` (iOS) or `SyncClient` (macOS).

- [ ] **Step 1: Implement coordinator** — persist enabled flag (`@AppStorage("localsync.enabled")`) + `lastSyncedRev` (UserDefaults). On iOS: `showPairingCode()` generates+stores a code (`SyncPairing.save`) and returns it; starts `SyncServer` with `advert: { SyncAdvert(rev: repo.syncRevision, day: repo.latestDayKey, v: DBSchema.version) }`. On macOS: `pair(code:)` stores the code; `syncNow()`/auto drives `SyncClient`.
- [ ] **Step 2: Add `syncRevision`** — a persisted monotonic `UInt64` on `Repository`, bumped where offloads/imports commit (reuse the point that bumps `refreshSeq`). Default 0.
- [ ] **Step 3: Settings UI** — `SyncSettingsView`: Enable toggle; iOS shows the 6-digit code; macOS has a code field + Pair; status card (`state`, `lastSync`, `pairedLabel`); "Sync now"; "Unpair" (destructive). Copy: "Syncs your data to your Mac over the local network. Nothing leaves your devices. Works when both apps are open on the same Wi-Fi."
- [ ] **Step 4: Info.plist via project.yml** — under the iOS app target `info.properties`: `NSLocalNetworkUsageDescription: "NOOP uses your local network to mirror your data to the NOOP Mac app on the same Wi-Fi. Nothing leaves your devices."` and `NSBonjourServices: ["_noopsync._tcp"]`. `xcodegen generate`.
- [ ] **Step 5: Compile both** — `xcodebuildmcp simulator build --scheme NOOPiOS ...` and `xcodebuildmcp macos build --scheme Strand`. Expected: both build.
- [ ] **Step 6: Commit** — `git commit -am "feat(sync): coordinator, settings UI, permission plumbing, syncRevision"`.

---

## Task 9: Loopback integration test (server ↔ client in one process)

**Files:**
- Create: `StrandTests/SyncLoopbackTests.swift`

- [ ] **Step 1: Write the test** — seed a small SQLite, `DataBackup.writeBackup` to get a `.noopbak`; start a `SyncServer` on `127.0.0.1` serving that file with a known PSK; start a `SyncClient` with the same PSK pointed at `localhost`; call `syncNow()`; await restore; assert the client's restored DB row count equals the seeded one. Assert a WRONG psk yields no restore (handshake fails).

```swift
// StrandTests/SyncLoopbackTests.swift — shape
func testLoopbackTransfersAndRestores() async throws {
    // arrange: seed source DB → writeBackup → tmpNoopbak
    // act: SyncServer(psk:A).start(); SyncClient(psk:A).syncNow()
    // assert: restored DB matches; then SyncClient(psk:B) → no restore
}
```

- [ ] **Step 2: Run** — `xcodebuild -scheme Strand -destination 'platform=macOS' test`. Expected: PASS (same-PSK restores; wrong-PSK doesn't).
- [ ] **Step 3: Commit** — `git commit -am "test(sync): loopback transfer + restore + wrong-PSK rejection"`.

---

## Task 10: Manual two-device verification (checklist, not automated)

- [ ] Build+install iOS on the physical iPhone (`update-and-install-device` flow or device build-and-run) and run the Mac app (`macos build-and-run`).
- [ ] iPhone: Settings → Local Sync → Enable → accept the iOS Local Network prompt → note the 6-digit code.
- [ ] Mac: Settings → Local Sync → Enable → enter the code → Pair.
- [ ] Confirm the Mac status → "Syncing…" → "Up to date"; verify the Mac now shows the iPhone's data.
- [ ] Change data on the iPhone (e.g. import/offload), confirm the Mac pulls the new revision (or via "Sync now").
- [ ] Negative paths: deny the iOS permission (honest state), wrong code (no data), both on an AP-isolated network (no peer found), unpair (next pull fails).
- [ ] Note results in the PR/spec; file follow-ups for anything rough.

---

## Self-review notes

- **Spec coverage:** transport (T6/T7), TLS-PSK (T4), pairing (T2/T5), payload reuse (T6/T7 via DataBackup), permission (T8), revision gating (T7/T8), UI (T8), error paths (T7/T9/T10), testing (T1-4 unit, T9 loopback, T10 manual). Phase 2/3 (auto-on-change, incremental) are intentionally out of this plan.
- **Type consistency:** `SyncAdvert`, `SyncMessage`, `PairedPeer`, `SyncTLS.parameters`, `SyncFraming.frame/decode`, `SyncCrypto.psk`, `SyncCoordinator` used consistently across tasks.
- **Known execution risk:** the `sec_protocol`/`DispatchData` bridging in Task 4 and the exact `NWTXTRecord`/`NWBrowser.bonjourWithTXTRecord` APIs in T6/T7 may need small compiler-driven fixes; the tests + compile-checks are the gates that finalize them.
