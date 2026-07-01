import SwiftUI
import StrandDesign
import StrandSync

/// Settings screen for local-network sync. On iPhone: enable, show a 6-digit pairing code, view status.
/// On Mac: enable, enter the iPhone's code, "Sync now", view status. Unpair on either.
struct SyncSettingsView: View {
    @ObservedObject var coordinator: SyncCoordinator
    @State private var enabled: Bool = false
    @State private var shownCode: String?
    @State private var enteredCode: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mirror your data to your other device over the local network. Nothing leaves your devices — it works when both apps are open on the same Wi-Fi.")
                    .font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                NoopCard {
                    Toggle(isOn: $enabled) {
                        Text("Enable Local Sync").font(StrandFont.headline)
                            .foregroundStyle(StrandPalette.textPrimary)
                    }
                    .onChangeCompat(of: enabled) { on in coordinator.setEnabled(on) }
                }

                if enabled {
                    #if os(iOS)
                    pairingCodeCard
                    #elseif os(macOS)
                    enterCodeCard
                    #endif
                    statusCard
                    #if os(macOS)
                    if coordinator.pairedLabel != nil { remoteControlCard }
                    #endif
                    if coordinator.pairedLabel != nil {
                        NoopButton("Unpair", kind: .destructive) {
                            coordinator.unpair(); enabled = false; shownCode = nil
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
        .navigationTitle("Local Sync")
        .onAppear { enabled = coordinator.isEnabled }
    }

    #if os(iOS)
    private var pairingCodeCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("PAIR WITH YOUR MAC").strandOverline()
                if let code = shownCode {
                    Text(code)
                        .font(StrandFont.number(40, weight: .bold))
                        .foregroundStyle(StrandPalette.accent)
                        .tracking(6)
                    Text("Enter this code in NOOP on your Mac (Settings → Local Sync).")
                        .font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
                } else {
                    NoopButton("Show pairing code", kind: .primary) {
                        shownCode = coordinator.showPairingCode()
                    }
                }
            }
        }
    }
    #endif

    #if os(macOS)
    private var enterCodeCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("PAIR WITH YOUR IPHONE").strandOverline()
                TextField("6-digit code", text: $enteredCode)
                    .textFieldStyle(.roundedBorder)
                    .font(StrandFont.number(20, weight: .semibold))
                HStack(spacing: 10) {
                    NoopButton("Pair", kind: .primary) { coordinator.pair(code: enteredCode) }
                    NoopButton("Sync now", kind: .secondary) { coordinator.syncNow() }
                }
            }
        }
    }
    #endif

    #if os(macOS)
    /// Send actions to the iPhone to run on the strap (the band is bonded to the phone).
    private var remoteControlCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("REMOTE CONTROL").strandOverline()
                Text("Send an action to your iPhone to run on the strap.")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
                HStack(spacing: 10) {
                    NoopButton("Buzz strap", kind: .primary) { coordinator.sendCommand(.buzz) }
                    NoopButton("Start workout", kind: .secondary) { coordinator.sendCommand(.startWorkout(sport: "Workout")) }
                    NoopButton("End", kind: .tertiary) { coordinator.sendCommand(.endWorkout) }
                }
            }
        }
    }
    #endif

    private var statusCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("STATUS").strandOverline()
                HStack {
                    Text(statusText).font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
                    Spacer()
                    if let label = coordinator.pairedLabel {
                        Text(label).font(StrandFont.caption).foregroundStyle(StrandPalette.statusPositive)
                    }
                }
                if let last = coordinator.lastSync {
                    Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
                }
            }
        }
    }

    private var statusText: String {
        switch coordinator.state {
        case .off:            return "Off"
        case .waitingForPair: return "Enter the code to pair"
        case .listening:      return "Ready — open NOOP on your Mac"
        case .discovering:    return "Looking for your iPhone…"
        case .syncing:        return "Syncing…"
        case .upToDate:       return "Up to date"
        case .needsRestart:   return "Synced — restart NOOP to load it"
        case .error(let m):   return m
        }
    }
}
