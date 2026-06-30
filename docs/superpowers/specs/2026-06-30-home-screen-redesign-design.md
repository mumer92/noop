# NOOP Home (Today) Screen Redesign — Design Spec

**Date:** 2026-06-30
**Status:** Draft for review
**Scope:** Full ground-up redesign of the Today/home screen, iOS **and** macOS.
**Author:** design exploration (brainstorming → spec)

---

## 1. Goals & constraints

From the brainstorming session, the redesign is a **full ground-up rethink** across three axes simultaneously:

1. **Visual craft** — make it distinctive/premium, not a generic card grid.
2. **Information hierarchy** — one clear "how am I today" answer; demote the rest.
3. **Metric set** — surface the most useful signals; cut noise; honest about gaps.

**Hard constraints (NOOP's ethos):**

- **Never fake a number.** Everything on-device, no cloud. If a value can't be stood behind (e.g. SpO2), it is shown as an honest empty/import state, never a placeholder digit. This is the same principle behind the blank SpO2 tile.
- **Reuse the existing design system** (`StrandDesign`) — palette, fonts, ring/gauge/chart primitives are already rich and API-stable. This is a *recomposition*, not a re-architecture.
- **Both platforms.** iPhone-first composition that also resolves to a wide macOS window.

**Design posture:** aspirational — design the best possible home, and explicitly *flag* the pieces that need new data/algorithm work as future phases.

**Target structure (user's words):** a *layered* home that blends a glanceable **hero** score, a plain-language **narrative**, **secondary** headline scores, and a rich glanceable **metric wall**.

---

## 2. Research synthesis

Four parallel research agents informed this spec: (a) external wearable home-screen patterns, (b) health-dashboard UX & dataviz best practices, (c) the existing `StrandDesign` system inventory, (d) an audit of which metrics this app can honestly surface.

### 2.1 What the best apps do (transferable patterns)

| App | Leads with | Tier encoding | "What shaped it" | Signature motif |
|---|---|---|---|---|
| **WHOOP** | 3 dials (Sleep·Recovery·Strain); Recovery % the de-facto hero (~72pt) | Traffic-light 67/34/0 | 4 drivers on deep-dive | Strain-vs-Recovery overlay, Coach |
| **Oura** | "One big thing" + Readiness gauge | Verbal: Optimal / Good / Pay attention | **Contributors list** — horizontal baseline bars, red = dragging down | Contributors list (gold standard), Advisor |
| **Garmin** | Body Battery 0–100 + **Morning Report** narrative | Named bands Prime/Primed/Recovering/Strained | **Charged-vs-Drained ledger** + 6 readiness factors | Morning Report wake-up narrative, battery metaphor |
| **Athlytic** | **Self-rewriting plain-language summary** + score panels | Static morning verdict, green/yellow/red | HRV+RHR vs 60-day baseline | Static verdict + live "battery" split |
| **Bevel** | Stacked % cards + "Energy Bank" battery | Qualitative labels, target bands | Drivers on detail + AI feed | Energy-Bank fusion, single-number-first |
| **Apple Fitness/Health** | Activity rings / Favorites feed | Goal arc length (no tiers) | 90-vs-365-day arrow trends | Closeable rings, auto-insight Highlights |

**Most transferable for a layered home:**

1. **Hero = one color-coded morning verdict**, huge type, glanceable in <10s.
2. **Static verdict + a separate live "battery"** — resolves the "why did my score move midday?" confusion and gives a reason to reopen the app.
3. **Plain-language narrative** that updates with time of day (Garmin/Athlytic) — the biggest differentiator vs WHOOP.
4. **Row of secondary score dials** as doorways into detail.
5. **"Why?" one tap down via baseline-bar contributors** (Oura) + factor breakdown (Garmin).
6. **Reorderable, user-curated metric wall** with widget/complication parity.
7. **One trend overlay on home** + per-metric up/down-vs-baseline arrow.

**Anti-patterns to avoid:** information overload (WHOOP/Athlytic/Ultrahuman all read as "daunting"); inconsistent chart metaphors (Ultrahuman mixes speedometer/line/bar); cold-start blank slate; ambiguous score motion.

### 2.2 Dataviz / UX guidance (evidence-based)

- **Rings/gauges are perceptually weak** for reading precise values (Cleveland-McGill: angle/area rank low; a radial-vs-linear study shows bars win). Color zones rank *dead last*. → **Use a ring only for the single 0–100 self-comparison hero**, always paired with the **exact number + a plain headline**. Use **bars (bullet-style)** for value-vs-baseline, **sparklines** for trends.
- **Reserve the most saturated color for the hero**; mute secondaries. Size is the strongest hierarchy cue — at most 1–2 "big" elements, ~3 type sizes. Pass the squint/5-second test.
- **Color:** never red/green alone (~8% of men are red-green colorblind; WCAG 1.4.1). Prefer blue-orange diverging; differ the ends by *luminance*, not just hue. Don't paint many things red (alarm fatigue). Desaturate status colors in dark mode.
- **Sparklines (Tufte):** 14–30 days, strip axes, dot/label min & max + last, render the **personal baseline as a light gray band** behind the line ("above = elevated, below = reduced"), band from the user's own rolling distribution.
- **Honest states (NN/g):** never leave a metric blank; distinguish *calibrating/loading* from *no data*; never show a placeholder number that later changes; use empty states to teach how to populate them.
- **Typography:** tabular/monospaced figures for any live/columnar number; explicit consistent units; avoid false precision.
- **Accessibility (Apple HIG/WCAG):** 44×44pt targets, Dynamic Type, 4.5:1 contrast both modes, Swift Charts audio graphs, convey state with more than color.

### 2.3 What `StrandDesign` already gives us (reuse)

- **Hero gauges:** `RecoveryRing`, `StrainGauge`, `BevelGauge`, `GlowRing` (240° open gauge; state words DEPLETED/LOW/MODERATE/PRIMED/PEAK).
- **Charts:** `Sparkline` (inline 14-day), `TrendChart` (Swift Charts multi-day/24h), `PipBar` (segmented progress).
- **Surfaces/cards:** `NoopCard` / `FrostedCardSurface` (optional domain tint wash), `StatTile` (fixed-height metric tile + sparkline).
- **Honest-state model:** `ScoreState` (.solid/.building/.calibrating/.live), `MetricTileState` (.scored/.calibrating(n)/.carriedLastNight/.needsStrap).
- **"What shaped it" already modeled:** `ChargeDrivers` returns ordered, *real* contribution terms (HRV, RHR, Rest, Respiration, Skin-temp) each with signed `deltaPoints`, `valueText`, `baselineText`, plain-English `verdict`; plus `ScoreConfidence` tiers and `SkinTempRelative` (cooler/typical/warmer).
- **Palette "colour worlds":** Charge (green), Effort (amber), Rest (slate), Stress — each a deep→bright gradient + glow, sampled by score. Text tiers, tabular numeric fonts, haptics, motion all present.

### 2.4 Honest data availability (what we can feature)

| Metric | On-device for strap-only? | Trend? | Baseline? | Drivers? | Home treatment |
|---|---|---|---|---|---|
| **Charge** (recovery) | ✅ when sleep detected | ✅ | ✅ | ✅ (ChargeDrivers) | **Hero** |
| **Effort** (strain) | ✅ when HR | ✅ | — | — | **Secondary / live battery** |
| **Rest** (sleep perf) | ✅ when sleep | ✅ | partial | components | **Secondary** |
| **HRV** | ✅ | ✅ | ✅ | dominant driver | Wall + driver bar |
| **Resting HR** | ✅ | ✅ | ✅ | driver | Wall + driver bar |
| **Respiratory** | ⚠️ may be nil (APPROXIMATE) | ✅ | ✅ | driver if present | Wall (labeled approx) |
| **Steps** | ⚠️ strap estimate (APPROXIMATE) | ✅ | — | — | Wall (labeled est.) |
| **Calories** | ⚠️ HR-only estimate | ✅ | — | — | Wall (labeled est.) |
| **Skin temp** | ✅ deviation only (in-bed) | ✅ | ✅ | driver (tier) | Wall as **warmer/typical/cooler**, never absolute |
| **Sleep stages** | ✅ | ✅ | — | confidence gate | Rest detail |
| **Vitality / Body Age** | ✅ if ≥3 factors | ✅ | population | contributions | Wall (gated) |
| **Fitness Age** | ❌ needs VO₂max | ✅ | population | — | Wall only if present |
| **SpO2** | ❌ hardcoded nil on-device | ✅ if imported | imported | — | **Gap: "Import to unlock", never a fake dash** |

---

## 3. Design principles for this screen

1. **One hero, exact + emotional.** A single Charge ring + the exact number + a plain headline. The ring is the only radial element.
2. **Static verdict, live battery.** Charge is your *morning* verdict and does **not** drift all day. Effort + live HR is the moving "battery" that earns re-opens. Make the distinction explicit in copy ("this morning" vs "right now").
3. **One saturated color = the hero.** Charge green dominates; Effort/Rest muted; metric wall neutral until tapped.
4. **One chart language.** Ring = goal-state (hero only). Line = intraday/trend. Horizontal bar = contributor-vs-baseline. Never mix metaphors for the same job.
5. **Honest by construction.** Every metric resolves through `MetricTileState`/`ScoreState`. Gaps teach (import nudge), they don't lie.
6. **Progressive disclosure.** Glance answer on the surface; drivers, trends, and detail one tap down (the Charge breakdown sheet already exists).
7. **Accessible & legible.** Tabular figures, Dynamic Type, audio graphs, ≥44pt targets, color never the sole signal.

---

## 4. The three approaches

All three honor the principles; they differ in **how dominant the single answer is** and **how much narrative leads**.

### Approach A — "Single Hero + Story" ⭐ Recommended

Collapse today's three co-equal rings into **one** large Charge ring, with the plain-language **narrative directly beneath**, then Effort + Rest as smaller **secondary doorways**, a **contributor bar** strip, the HR trend, and the metric wall.

```
┌──────────────────────────────────────────────┐
│ ⚙︎      ‹   Today   ›             ● ◔  🔔  +  ☰ │  top bar
├──────────────────────────────────────────────┤
│                 ╭────────────╮                 │
│                (     78      )                 │  ① HERO — Charge
│                 ╰── PRIMED ───╯                │   RecoveryRing 260pt
│              ● Solid · baseline trusted        │   exact # + state + confidence
├──────────────────────────────────────────────┤
│  This morning you're primed. Strong HRV (+6)   │  ② NARRATIVE
│  and solid sleep led; resting HR ran a touch   │   from ChargeDrivers,
│  high.                                         │   time-of-day aware
├───────────────────────┬──────────────────────┤
│ EFFORT  12.4   ▁▃▅▆    │ REST  84      ▅▄▆▅    │  ③ SECONDARY scores
│ Moderate · right now   │ Solid · last night    │   (live)        (static)
├───────────────────────┴──────────────────────┤
│ what shaped it                                 │  ④ CONTRIBUTOR bars
│  HRV    62 ms  ▕────●──▏  +6  above baseline    │   DriverBar, bullet-style
│  RHR    53 bpm ▕──●────▏  −2  above baseline    │   length-on-scale (good
│  Sleep  84     ▕─────●─▏  +4  strong            │   dataviz), red = drag
│  Skin   typical                                │
├──────────────────────────────────────────────┤
│ Heart rate · today            ╱╲__╱╲___╱╲      │  ⑤ HR TREND (TrendChart)
├──────────────────────────────────────────────┤
│ Your metrics                          Edit ›   │  ⑥ METRIC WALL
│ ┌──────┐┌──────┐┌──────┐┌──────┐               │   StatTile + Sparkline
│ │HRV 62││RHR 53││Sleep ││Steps │               │   + baseline band
│ │ ▁▃▂▅▆││ ▅▄▅▃▂││7h12m ││~8.1k │               │   approx labeled,
│ └──────┘└──────┘└──────┘└──────┘               │   SpO2 = import tile
│        [ Show all metrics ]                     │
├──────────────────────────────────────────────┤
│ Synced from WHOOP 4.0 · 86% 🔋          ▸      │  ⑦ SOURCES (collapsed)
└──────────────────────────────────────────────┘
```

**Pros:** clearest single answer (best per dataviz research); directly matches the strongest cross-app pattern (Oura/Garmin/Athlytic); biggest "premium" upgrade; the narrative + contributor bars lean into NOOP's honest-insight ethos. **Cons:** biggest departure from today's triad; requires the most recomposition.

### Approach B — "Balanced Triad, Elevated"

Keep the three rings but make **Charge primary** (larger, centered/top), with Effort + Rest as smaller flanking rings; add the narrative band and the wall.

```
┌──────────────────────────────────────────────┐
│ ⚙︎      ‹   Today   ›             ● ◔  🔔  +  ☰ │
├──────────────────────────────────────────────┤
│        ╭────────╮                              │
│       (   78    )   ← Charge, large            │  HERO triad
│        ╰─PRIMED─╯                              │  Charge dominant,
│   ╭────╮            ╭────╮                      │  Effort+Rest smaller
│  ( 12.4 ) Effort   ( 84 ) Rest                 │
│   ╰────╯            ╰────╯                      │
├──────────────────────────────────────────────┤
│  Primed — strong HRV and solid sleep led.      │  narrative
├──────────────────────────────────────────────┤
│  [ contributor bars ] [ HR trend ] [ wall ]    │
└──────────────────────────────────────────────┘
```

**Pros:** lowest risk, closest to today, keeps the familiar three-ring identity. **Cons:** three rings still split the glance; weaker single-answer clarity; least differentiated.

### Approach C — "Coach / Narrative-first"

Lead with a **big plain-language insight card** (the score embedded in the sentence), ring smaller and to the side; then secondary scores, contributor bars, wall.

```
┌──────────────────────────────────────────────┐
│ ⚙︎      ‹   Today   ›             ● ◔  🔔  +  ☰ │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────╮  ╭────╮ │  HERO = insight card
│ │ You're PRIMED this morning.        │ ( 78 )│   + small ring
│ │ Strong HRV and 7h12m sleep carried │  ╰────╯│   number embedded in copy
│ │ it. Resting HR ran a touch high —  │        │
│ │ good day for moderate strain.      │        │
│ └────────────────────────────────────╯        │
├──────────────────────────────────────────────┤
│  [ secondary scores ] [ contributor bars ]     │
│  [ HR trend ] [ metric wall ]                  │
└──────────────────────────────────────────────┘
```

**Pros:** most distinctive; strongest brand voice; mirrors Garmin Morning Report (highest-engagement motif). **Cons:** the exact number is less dominant at a glance (mitigated by a bold numeral in the card); power users may want number-first.

**Recommendation:** **Approach A**, adopting C's narrative band as its second row. A and C merge naturally — "hero + story" is exactly the requested blend, with A's number-first glance and C's voice.

---

## 5. Recommended design — section by section (Approach A)

Each section lists: **what it displays**, **data source**, **rendering component (reuse/new)**, and **honest states**.

### ① Hero — Charge
- **Displays:** big Charge ring (~260pt), the exact 0–100 number, the state word (DEPLETED…PEAK), and a confidence pill ("Solid · baseline trusted"). Tap → existing Charge breakdown sheet.
- **Data:** today's recovery; `chargeScoreState`; `chargeBreakdownConfidence`.
- **Component:** **reuse** `RecoveryRing` (enlarged, single instead of triad). Confidence pill = existing `ScoreState` → `ScoreStatePill`.
- **Honest states:** `.calibrating(n)` → ring shows a calm "Calibrating — n nights to your baseline," **no number invented**; `.carriedLastNight` → last scored value + "Last night · <date>"; `.needsStrap` → "Wear your strap to bed for a Charge score" + setup affordance (teaching empty state).
- **Static-verdict rule:** this number is the *morning* verdict and does not move during the day.

### ② Narrative band
- **Displays:** one or two plain-language sentences summarizing the top 2–3 contributors and the day's recommendation, **time-of-day aware** ("This morning…" / "This evening…").
- **Data:** top `ChargeDrivers` (already ordered by |deltaPoints|) + readiness word (Push/Maintain/Rest) + confidence.
- **Component:** **new** `ChargeNarrative` — a deterministic text synthesizer over `ChargeDrivers` (no LLM; honest, derived from the same terms the score uses). Lives in `StrandDesign` or `StrandAnalytics`.
- **Honest states:** cold-start → "Still learning your baseline — scores unlock after a few nights." Never asserts a driver that didn't fire.

### ③ Secondary scores — Effort & Rest
- **Displays:** two muted cards. **Effort** (live "battery"): value /scale, state word, "right now," tiny intraday sparkline. **Rest** (static): last-night score, state word, "last night," sleep sparkline. Each taps into detail.
- **Data:** `effort` + `ScoreConfidence.effort`; `rest` + `ScoreConfidence.rest`.
- **Component:** **new** `SecondaryScoreCard` wrapping `StrainGauge`/`GlowRing`/`PipBar` (small) + `Sparkline`. Muted tint (Effort amber, Rest slate) — *not* hero-saturated.
- **Honest states:** Effort `.live` while HR streams; Rest `.building` in cold-start; either `.needsStrap` when absent.

### ④ Contributor bars — "what shaped it"
- **Displays:** horizontal bullet bars for each Charge driver: metric name, value, a baseline marker, and a signed delta with plain verdict ("above baseline, supporting recovery"). Skin temp as a tier chip (warmer/typical/cooler).
- **Data:** `ChargeDrivers` (`deltaPoints`, `valueText`, `baselineText`, `verdict`) + `SkinTempRelative`.
- **Component:** **new** `DriverBar` (bullet-style: track + baseline tick + value dot + delta label). This is the Oura "contributors" pattern, validated by dataviz (length on a common scale, top of the accuracy ranking).
- **Honest states:** only renders rows that actually fed the score (no fabricated zeros); empty in cold-start. Color: blue/amber + sign + text, never red/green alone.
- **Note:** this section can be collapsed by default (lives inside the Charge breakdown sheet) or shown inline — see Open Questions.

### ⑤ Heart-rate trend
- **Displays:** today's HR line (midnight→now, ~5-min buckets) with the sleep-session band.
- **Data:** existing 24h HR series.
- **Component:** **reuse** `TrendChart`. Optionally collapsible to reduce length.

### ⑥ Metric wall
- **Displays:** adaptive grid of `StatTile`s, each with UPPERCASE label, big value, unit, and a **14–30-day sparkline with a personal-baseline band** + min/max dots; a per-tile up/down-vs-baseline arrow. First ~6 shown, rest behind "Show all metrics." User-reorderable.
- **Data:** `Repository` metric series + baselines per metric (`metricSeries`/`points(key:)`, `BaselineState`).
- **Component:** **reuse** `StatTile` + `Sparkline`; **new** `SparklineBand` overlay (gray baseline band + min/max dots — the one charting gap vs the research ideal). Reorder via existing `KeyMetricPrefs`/`DashboardCardPrefs`.
- **Honest states & ordering:** confident metrics first (HRV, RHR, Sleep, then Vitality). Approximate metrics (Steps, Calories, Respiratory) carry a small "est." marker. **SpO2** renders as an **"Import to unlock"** tile (tap → import flow), never a fake dash. Skin temp shows **warmer/typical/cooler**. Fitness Age only appears if VO₂max exists.

### ⑦ Sources
- **Displays:** collapsed "Synced from <strap> · <battery>%," expands to per-source rows + sync/battery.
- **Component:** **reuse** existing sources section.

---

## 6. Component inventory — reuse vs new

**Reuse as-is:** `RecoveryRing`, `StrainGauge`, `GlowRing`, `PipBar`, `Sparkline`, `TrendChart`, `NoopCard`/`FrostedCardSurface`, `StatTile`, `ScoreState`/`ScoreStatePill`, `MetricTileState`, `ChargeDrivers`/`ScoreConfidence`/`SkinTempRelative`, `StrandPalette`/`StrandFont`/`StrandHaptic`/`StrandMotion`.

**New (small, mostly in `StrandDesign`):**

| Component | Purpose | Source feeding it |
|---|---|---|
| `ChargeNarrative` | One honest sentence from drivers + confidence, time-of-day aware | `ChargeDrivers`, readiness word |
| `DriverBar` | Bullet-style contributor bar (value, baseline, signed delta) | `ChargeDriver` |
| `SecondaryScoreCard` | Muted Effort/Rest doorway (small gauge + sparkline) | `effort`/`rest` + confidence |
| `SparklineBand` | Baseline band + min/max dots over `Sparkline` | metric series + `BaselineState` |
| Metric-wall gap/approx states | "Import to unlock" / "est." markers | `MetricTileState` + source flags |

**Touch points:** primarily `Strand/Screens/TodayView.swift` (recompose `heroSection` + body order) and `Strand/Screens/DashboardCards.swift` (reorder + states); new files under `Packages/StrandDesign/Sources/StrandDesign/`. No score/analytics math changes — the honesty plumbing already exists.

---

## 7. macOS variant

- **Hero** Charge ring in the main content column; **narrative** directly beneath.
- **Secondary** Effort + Rest in a horizontal row beside or below the hero (wide window affords side-by-side).
- **Contributor bars** in a side panel or a two-column block.
- **Metric wall** as a 3–4-column grid (vs 2 on iPhone).
- Keep the existing window **toolbar** (Support heart, updates bell) — macOS hosts affordances there, not in-content.
- All `StrandPalette` tokens already resolve NSColor/UIColor automatically; no per-view plumbing.

---

## 8. Accessibility & honesty checklist

- Tabular figures (`.monospacedDigit()`) on all live/columnar numbers.
- Dynamic Type throughout; dense rows stack at AX sizes (`isAccessibilityCategory`).
- Contrast ≥4.5:1 (text) / 3:1 (large/non-text) in **both** light and dark; desaturated status hues in dark.
- State conveyed by **text + shape + position**, never color alone.
- Swift Charts audio graphs preserved on `TrendChart`; custom bars get accessibility labels with units ("62 milliseconds, 6 above baseline").
- ≥44pt tap targets; ~12pt spacing between adjacent controls.
- Every empty/uncertain state reads as `calibrating` / `no data` / `import to unlock` — never a placeholder digit.

---

## 9. Iteration / phasing plan

- **Phase 1 — Hero + Story (biggest visual win, ~all reuse).** Single Charge ring hero, `ChargeNarrative` band, `SecondaryScoreCard` for Effort/Rest. Recompose `TodayView` body order. Ship behind nothing risky — mostly layout.
- **Phase 2 — Insight & wall.** `DriverBar` contributor strip, metric-wall reflow with confident-first ordering, `SparklineBand` baseline bands, approximate/import honest states (incl. SpO2 import tile).
- **Phase 3 — Platform & polish.** macOS wide layout, accessibility pass (audio graphs, AX sizes), motion polish, time-of-day narrative variants, optional widget/complication parity.

Each phase is independently shippable and reversible.

---

## 10. Open questions

1. **Contributor bars (④):** inline on the home screen, or kept inside the Charge breakdown sheet (tap-to-reveal) to keep the surface calm? (Recommendation: collapsed inline, expandable — balances Oura's at-a-glance "why" against overload.)
2. **Effort as the "live battery":** do we want an explicit battery/Energy-Bank metaphor (Garmin/Bevel) layered on Effort, or keep Effort as a strain score with a "right now" label? (Recommendation: start with the label; evaluate a battery visual in Phase 3.)
3. **Narrative tone:** terse ("Primed. HRV strong, RHR high.") vs conversational ("You're primed this morning…")? (Recommendation: conversational but short; A/B later.)
4. **Metric-wall default set:** confirm the confident-first default order and how many show before "Show all."
5. **Skin temp & SpO2 placement:** keep both in the wall as honest states, or hide SpO2 entirely for strap-only users until an import exists?

---

## 11. Decision log

- **Single hero over triad:** dataviz hierarchy + cross-app convergence on one dominant answer.
- **Ring kept only for the hero:** radial is acceptable for one self-comparison score; bars/sparklines used everywhere else per perceptual-accuracy research.
- **Static verdict + live battery:** adopted from Garmin/Athlytic/Bevel to resolve score-motion ambiguity; NOOP already has the Charge/Effort duality to express it.
- **Honest gap states (esp. SpO2):** consistent with NOOP's no-faking ethos and the SpO2 limitation (raw red/IR only, no calibrated %).
- **Recompose, don't re-architect:** `StrandDesign` + `ChargeDrivers` + confidence/state models already exist; new work is a handful of small view components.
