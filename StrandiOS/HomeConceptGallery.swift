#if os(iOS)
import SwiftUI
import StrandDesign
import WhoopStore

// MARK: - Home redesign concept gallery (live-wired)
//
// Three full Today/home-screen concepts rendered with the REAL StrandDesign components AND the REAL
// data pipeline: today's row from `Repository` (`repo.today` / `repo.days`), the live heart rate from
// `LiveState`, and the real 24h HR trend from `repo.hrBuckets`. Reachable two ways: the "Concepts" tab
// in RootTabView, and the DEBUG `--demo-screen homeconcepts` harness. When no data exists yet (a fresh
// install / simulator with no synced history) every metric falls back to an honest empty/calibrating
// state instead of a fake number — the same ethos as the rest of the app.
//
// Design spec: docs/superpowers/specs/2026-06-30-home-screen-redesign-design.md

struct HomeConceptGallery: View {
    enum Concept: String, CaseIterable, Identifiable {
        case heroStory = "A · Hero + Story"
        case triad     = "B · Triad"
        case coach     = "C · Coach"
        var id: String { rawValue }
    }
    @State private var concept: Concept = .heroStory
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var live: LiveState

    /// Real 24h heart-rate trend (5-min buckets), loaded async from the store.
    @State private var hrTrend: [Double] = []

    private var vm: HomeVM { HomeVM(days: repo.days, today: repo.today) }

    var body: some View {
        VStack(spacing: 0) {
            SegmentedPillControl(Concept.allCases, selection: $concept) { $0.rawValue }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)

            ScrollView {
                Group {
                    switch concept {
                    case .heroStory: ConceptHeroStory(vm: vm, live: live, hrTrend: hrTrend)
                    case .triad:     ConceptTriad(vm: vm, live: live, hrTrend: hrTrend)
                    case .coach:     ConceptCoach(vm: vm, live: live, hrTrend: hrTrend)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 40)
            }
        }
        .background(StrandPalette.surfaceBase.ignoresSafeArea())
        .task(id: repo.refreshSeq) { await loadHRTrend() }
    }

    private func loadHRTrend() async {
        let now = Int(Date().timeIntervalSince1970)
        let start = now - 12 * 3600
        let buckets = await repo.hrBuckets(from: start, to: now, bucketSeconds: 300)
        hrTrend = buckets.map(\.bpm)
    }
}

// MARK: - View model — resolves real values + baselines + series from the loaded day rows

private struct HomeVM {
    let charge: Double?
    let strain: Double?
    let sleepMin: Double?
    let hrv: Double?
    let rhr: Int?
    let resp: Double?
    let spo2: Double?
    let skinTempDev: Double?
    let steps: Int?

    let hrvBase: Double?
    let rhrBase: Double?
    let respBase: Double?
    let sleepBase: Double?

    let chargeSeries: [Double]
    let hrvSeries: [Double]
    let rhrSeries: [Double]
    let strainSeries: [Double]
    let sleepSeries: [Double]

    init(days: [DailyMetric], today: DailyMetric?) {
        // The row we describe: today's resolved row, else the most recent scored day (carry-over).
        let row = today ?? days.last(where: { $0.recovery != nil }) ?? days.last
        charge = row?.recovery
        strain = row?.strain
        sleepMin = row?.totalSleepMin
        hrv = row?.avgHrv
        rhr = row?.restingHr
        resp = row?.respRateBpm
        spo2 = row?.spo2Pct
        skinTempDev = row?.skinTempDevC
        steps = row?.steps

        hrvBase = HomeVM.mean(days.compactMap(\.avgHrv))
        rhrBase = HomeVM.mean(days.compactMap { $0.restingHr.map(Double.init) })
        respBase = HomeVM.mean(days.compactMap(\.respRateBpm))
        sleepBase = HomeVM.mean(days.compactMap(\.totalSleepMin))

        let tail = days.suffix(21)
        chargeSeries = tail.compactMap(\.recovery)
        hrvSeries = tail.compactMap(\.avgHrv)
        rhrSeries = tail.compactMap { $0.restingHr.map(Double.init) }
        strainSeries = tail.compactMap(\.strain)
        sleepSeries = tail.compactMap(\.totalSleepMin)
    }

    static func mean(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        var sum = 0.0
        for x in xs { sum += x }
        return sum / Double(xs.count)
    }

    // MARK: Formatted display

    var hasScore: Bool { charge != nil }
    var chargeText: String { charge.map { String(Int($0.rounded())) } ?? "—" }
    var chargeState: String {
        guard let c = charge else { return "CALIBRATING" }
        return StrandPalette.recoveryState(c)
    }
    var strainText: String { strain.map { String(format: "%.1f", $0) } ?? "—" }
    var hrvText: String { hrv.map { String(Int($0.rounded())) } ?? "—" }
    var rhrText: String { rhr.map(String.init) ?? "—" }
    var respText: String { resp.map { String(format: "%.1f", $0) } ?? "—" }
    var stepsText: String { steps.map { Self.grouped($0) } ?? "—" }
    var sleepText: String {
        guard let m = sleepMin, m > 0 else { return "—" }
        let h = Int(m) / 60, mm = Int(m) % 60
        return "\(h)h \(mm)m"
    }
    var spo2Text: String? { spo2.map { String(format: "%.0f%%", $0) } }
    var skinTempTier: String {
        guard let d = skinTempDev else { return "—" }
        if d > 0.3 { return "Warmer" }
        if d < -0.3 { return "Cooler" }
        return "Typical"
    }

    static func grouped(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Top-of-list contributors as simple (name, value, deltaVsBaseline, positive) rows from real values.
    var drivers: [DriverDatum] {
        var out: [DriverDatum] = []
        if let h = hrv, let b = hrvBase {
            out.append(DriverDatum(name: "HRV", value: "\(Int(h.rounded())) ms", delta: h - b,
                                   positive: h >= b, frac: HomeVM.frac(h, b, spread: 25), base: 0.5,
                                   verdict: h >= b ? "Above your baseline — supporting recovery"
                                                   : "Below baseline — a mild drag"))
        }
        if let r = rhr, let b = rhrBase {
            let rd = Double(r)
            out.append(DriverDatum(name: "Resting HR", value: "\(r) bpm", delta: rd - b,
                                   positive: rd <= b, frac: HomeVM.frac(rd, b, spread: 10), base: 0.5,
                                   verdict: rd <= b ? "At or below baseline — restful"
                                                    : "A touch above baseline — mild drag"))
        }
        if let r = resp, let b = respBase {
            out.append(DriverDatum(name: "Respiratory", value: String(format: "%.1f rpm", r),
                                   delta: r - b, positive: abs(r - b) < 1.0,
                                   frac: HomeVM.frac(r, b, spread: 3), base: 0.5,
                                   verdict: "Breaths per minute vs your baseline"))
        }
        return out
    }
    static func frac(_ v: Double, _ base: Double, spread: Double) -> Double {
        let f = 0.5 + (v - base) / (spread * 2)
        return min(max(f, 0.06), 0.96)
    }
}

private struct DriverDatum: Identifiable {
    let id = UUID()
    let name: String, value: String
    let delta: Double
    let positive: Bool
    let frac: Double, base: Double
    let verdict: String
    var deltaText: String {
        let r = Int(delta.rounded())
        return (r >= 0 ? "+\(r)" : "\(r)")
    }
}

// MARK: - Live HR readout (ticks from LiveState)

private struct LiveHRReadout: View {
    @ObservedObject var live: LiveState
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 15))
                .foregroundStyle(live.connected ? StrandPalette.metricRose : StrandPalette.textTertiary)
                .symbolEffectPulse(active: live.connected)
            if live.connected, let bpm = live.heartRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(bpm)").font(StrandFont.number(20, weight: .bold))
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text("bpm live").font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                }
            } else {
                Text("Strap not connected").font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            Spacer()
            if let b = live.batteryPct {
                Label(String(format: "%.0f%%", b), systemImage: "battery.50")
                    .font(StrandFont.captionNumber).foregroundStyle(StrandPalette.textTertiary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StrandPalette.surfaceInset))
    }
}

private extension View {
    @ViewBuilder func symbolEffectPulse(active: Bool) -> some View {
        if #available(iOS 17.0, *), active {
            self.symbolEffect(.pulse, options: .repeating)
        } else { self }
    }
}

// MARK: - Top bar mock

private struct TopBarMock: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle").font(.system(size: 22))
                .foregroundStyle(StrandPalette.textSecondary)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StrandPalette.textTertiary)
                Text("Today").font(StrandFont.headline).foregroundStyle(StrandPalette.textPrimary)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            Spacer()
            Image(systemName: "bell").font(.system(size: 18)).foregroundStyle(StrandPalette.textSecondary)
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                .foregroundStyle(StrandPalette.accent)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Reusable pieces (all real-data driven)

private struct SecondaryScoreCard: View {
    let label: String, value: String, unit: String, state: String, caption: String
    let tint: Color, series: [Double], gradient: Gradient
    var body: some View {
        NoopCard(tint: tint) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).strandOverline()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(StrandFont.number(30, weight: .bold)).foregroundStyle(tint)
                    Text(unit).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                }
                Text(state).font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                if series.count > 1 {
                    Sparkline(values: series, gradient: gradient, showsHover: false).frame(height: 26)
                } else {
                    Text("Building history").font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary).frame(height: 26, alignment: .leading)
                }
                Text(caption).font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
            }
        }
    }
}

private struct DriverBarRow: View {
    let datum: DriverDatum
    private var tint: Color { datum.positive ? StrandPalette.chargeColor : StrandPalette.metricRose }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(datum.name).font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                    .frame(width: 78, alignment: .leading)
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(StrandPalette.surfaceInset).frame(height: 6)
                        Capsule().fill(tint.opacity(0.9)).frame(width: max(8, w * datum.frac), height: 6)
                        Rectangle().fill(StrandPalette.textTertiary).frame(width: 2, height: 12)
                            .offset(x: w * datum.base - 1)
                        Circle().fill(tint).frame(width: 11, height: 11)
                            .overlay(Circle().stroke(StrandPalette.surfaceBase, lineWidth: 2))
                            .offset(x: max(0, w * datum.frac - 5.5))
                    }
                }
                .frame(height: 14)
                Text(datum.deltaText).font(StrandFont.captionNumber).foregroundStyle(tint)
                    .frame(width: 34, alignment: .trailing)
            }
            Text(datum.verdict).font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
                .padding(.leading, 86)
        }
    }
}

private struct ContributorBlock: View {
    let vm: HomeVM
    var body: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("What shaped it").strandOverline()
                if vm.drivers.isEmpty {
                    Text("Wear your strap to bed for a few nights — your contributors appear once your baseline forms.")
                        .font(StrandFont.subhead).foregroundStyle(StrandPalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(vm.drivers) { DriverBarRow(datum: $0) }
                    HStack(spacing: 8) {
                        Text("Skin temp").font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                            .frame(width: 78, alignment: .leading)
                        Text(vm.skinTempTier).font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(StrandPalette.surfaceInset))
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct HRTrendBlock: View {
    let hrTrend: [Double]
    var body: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Heart rate · last 12h").strandOverline()
                    Spacer()
                    if let avg = HomeVM.mean(hrTrend) {
                        Text("avg \(Int(avg.rounded())) bpm").font(StrandFont.captionNumber)
                            .foregroundStyle(StrandPalette.textSecondary)
                    }
                }
                if hrTrend.count > 1 {
                    Sparkline(values: hrTrend, gradient: StrandPalette.strainGradient,
                              lineWidth: 2.2, showsHover: false).frame(height: 64)
                } else {
                    Text("No heart-rate samples yet today.").font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textTertiary).frame(height: 64, alignment: .leading)
                }
            }
        }
    }
}

private struct MetricWall: View {
    let vm: HomeVM
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your metrics").strandOverline()
                Spacer()
                Text("Edit").font(StrandFont.footnote).foregroundStyle(StrandPalette.accent)
            }
            LazyVGrid(columns: cols, spacing: 12) {
                StatTile(label: "HRV", value: vm.hrvText, caption: "ms", accent: StrandPalette.metricCyan,
                         sparkline: vm.hrvSeries.count > 1 ? vm.hrvSeries : nil, sparkColor: StrandPalette.metricCyan)
                StatTile(label: "Resting HR", value: vm.rhrText, caption: "bpm", accent: StrandPalette.metricRose,
                         sparkline: vm.rhrSeries.count > 1 ? vm.rhrSeries : nil, sparkColor: StrandPalette.metricRose)
                StatTile(label: "Sleep", value: vm.sleepText, caption: "last night", accent: StrandPalette.restColor,
                         sparkline: vm.sleepSeries.count > 1 ? vm.sleepSeries : nil, sparkColor: StrandPalette.restColor)
                StatTile(label: "Steps", value: vm.stepsText, caption: "estimated", accent: StrandPalette.metricPurple)
                StatTile(label: "Respiratory", value: vm.respText, caption: "rpm · approx", accent: StrandPalette.metricAmber)
                spo2Tile
            }
        }
    }

    @ViewBuilder private var spo2Tile: some View {
        if let s = vm.spo2Text {
            StatTile(label: "Blood O₂", value: s, caption: "imported", accent: StrandPalette.metricCyan)
        } else {
            NoopCard(padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Blood O₂").strandOverline()
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.down.circle").font(.system(size: 20))
                        .foregroundStyle(StrandPalette.accent)
                    Text("Import to unlock").font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                    Text("Not measured on-device").font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            }
        }
    }
}

private struct SourcesRow: View {
    @ObservedObject var live: LiveState
    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 13))
                .foregroundStyle(StrandPalette.textTertiary)
            Text(live.connected ? "Strap connected" : "Synced from your strap")
                .font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StrandPalette.textTertiary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Narrative (deterministic, from real drivers)

private func narrative(_ vm: HomeVM) -> String {
    guard let c = vm.charge else {
        return "Still learning your baseline — your Charge score unlocks after a few nights of wear."
    }
    let state = StrandPalette.recoveryState(c).lowercased()
    let lead = vm.drivers.first
    if let d = lead {
        let dir = d.positive ? "led the way" : "held it back"
        return "This morning you're **\(state)** at \(Int(c.rounded())). \(d.name) \(d.deltaText) \(dir)."
    }
    return "This morning you're **\(state)** at \(Int(c.rounded()))."
}

// MARK: - Concept A — Single Hero + Story

private struct ConceptHeroStory: View {
    let vm: HomeVM
    @ObservedObject var live: LiveState
    let hrTrend: [Double]
    var body: some View {
        VStack(spacing: 18) {
            TopBarMock()
            LiveHRReadout(live: live)
            VStack(spacing: 10) {
                if vm.hasScore, let c = vm.charge {
                    RecoveryRing(score: c, diameter: 248, lineWidth: 16, showsHover: false)
                    ScoreStatePill(.solid, text: "Solid · baseline trusted")
                } else {
                    placeholderRing
                    ScoreStatePill(.calibrating, text: "Calibrating")
                }
            }
            .padding(.top, 2)
            NoopCard(tint: StrandPalette.chargeGlow) {
                Text(.init(narrative(vm))).font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                SecondaryScoreCard(label: "Effort", value: vm.strainText, unit: "/100",
                                   state: live.connected ? "Live" : "Today", caption: "cardio load",
                                   tint: StrandPalette.effortColor, series: vm.strainSeries,
                                   gradient: StrandPalette.strainGradient)
                SecondaryScoreCard(label: "Sleep", value: vm.sleepText, unit: "",
                                   state: "Last night", caption: "time asleep",
                                   tint: StrandPalette.restColor, series: vm.sleepSeries,
                                   gradient: StrandPalette.restGradient)
            }
            ContributorBlock(vm: vm)
            HRTrendBlock(hrTrend: hrTrend)
            MetricWall(vm: vm)
            SourcesRow(live: live)
        }
    }
    private var placeholderRing: some View {
        ZStack {
            Circle().stroke(StrandPalette.surfaceInset, lineWidth: 16).frame(width: 248, height: 248)
            VStack(spacing: 4) {
                Text("—").font(StrandFont.display(64)).foregroundStyle(StrandPalette.textTertiary)
                Text("NO SCORE YET").font(StrandFont.overline).tracking(1.4)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
    }
}

// MARK: - Concept B — Balanced Triad

private struct ConceptTriad: View {
    let vm: HomeVM
    @ObservedObject var live: LiveState
    let hrTrend: [Double]
    var body: some View {
        VStack(spacing: 18) {
            TopBarMock()
            LiveHRReadout(live: live)
            if vm.hasScore, let c = vm.charge {
                RecoveryRing(score: c, diameter: 208, lineWidth: 15, showsHover: false).padding(.top, 2)
            }
            HStack(spacing: 18) {
                StrainGauge(strain: vm.strain ?? 0, outOf: 100, diameter: 128, lineWidth: 11, showsHover: false)
                ringMini(value: vm.sleepText, label: "Sleep", color: StrandPalette.restColor)
            }
            NoopCard(tint: StrandPalette.chargeGlow) {
                Text(.init(narrative(vm))).font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            ContributorBlock(vm: vm)
            HRTrendBlock(hrTrend: hrTrend)
            MetricWall(vm: vm)
            SourcesRow(live: live)
        }
    }
    private func ringMini(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value).font(StrandFont.number(26, weight: .bold)).foregroundStyle(color)
            Text(label.uppercased()).font(StrandFont.overline).tracking(1.2)
                .foregroundStyle(StrandPalette.textTertiary)
        }
        .frame(width: 128, height: 128)
        .background(Circle().stroke(StrandPalette.surfaceInset, lineWidth: 11))
    }
}

// MARK: - Concept C — Coach / Narrative-first

private struct ConceptCoach: View {
    let vm: HomeVM
    @ObservedObject var live: LiveState
    let hrTrend: [Double]
    var body: some View {
        VStack(spacing: 18) {
            TopBarMock()
            LiveHRReadout(live: live)
            NoopCard(tint: StrandPalette.chargeGlow) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THIS MORNING").strandOverline()
                        Text(vm.hasScore ? "You're \(vm.chargeState.lowercased())." : "No score yet.")
                            .font(StrandFont.rounded(26, weight: .bold))
                            .foregroundStyle(vm.charge.map { StrandPalette.recoveryColor($0) } ?? StrandPalette.textSecondary)
                        Text(.init(narrative(vm))).font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if vm.hasScore, let c = vm.charge {
                        RecoveryRing(score: c, diameter: 94, lineWidth: 9, showsWordmark: false, showsHover: false)
                    }
                }
            }
            HStack(spacing: 12) {
                SecondaryScoreCard(label: "Effort", value: vm.strainText, unit: "/100",
                                   state: live.connected ? "Live" : "Today", caption: "cardio load",
                                   tint: StrandPalette.effortColor, series: vm.strainSeries,
                                   gradient: StrandPalette.strainGradient)
                SecondaryScoreCard(label: "Sleep", value: vm.sleepText, unit: "",
                                   state: "Last night", caption: "time asleep",
                                   tint: StrandPalette.restColor, series: vm.sleepSeries,
                                   gradient: StrandPalette.restGradient)
            }
            ContributorBlock(vm: vm)
            HRTrendBlock(hrTrend: hrTrend)
            MetricWall(vm: vm)
            SourcesRow(live: live)
        }
    }
}
#endif
