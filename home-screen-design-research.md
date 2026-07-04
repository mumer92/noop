# Designing a Best-in-Class HOME / TODAY Screen for a WHOOP Companion App
## Competitive teardown of 8 recovery/wearable apps + design synthesis

> **Sourcing note:** Numeric thresholds and band labels below are well-sourced from official docs. Exact hex values are mostly *not* published by these brands (Apple, WHOOP, Oura all withhold them) — where hex appears it is community reverse-engineered and flagged. Sample real values from current App Store screenshots before locking a palette.

---

## 1. WHOOP — three co-equal dials, Recovery as de-facto hero

**Leads with:** NOT a single hero. The redesign puts **three circular dials side-by-side at the top — Sleep · Recovery · Strain** — each a colored arc with a large central number, each a doorway to a deep-dive page. In practice **Recovery %** is the emotional anchor (rendered ~72pt, readable at arm's length). Above the dials sits a thin band-battery/status strip.

**Tier encoding (copy exactly):**
- **Recovery 0–100%, traffic-light:** Green **67–100%** ("primed to perform"), Yellow **34–66%** ("maintaining"), Red **0–33%** ("rest"). Average member ≈ 58%.
- **Strain 0–21**, Borg-based and **logarithmic** (16→17 is harder than 4→5), in **blue**: Light 0–9, Moderate 10–13, High 14–17, All Out 18–21.
- **Sleep Performance %** = % of sleep need achieved (own blue/teal ring); guidance bands 100/85/70%.

**What shaped it:** Home stays minimal — below the dials are **quick-access biometric cards (Heart Rate, HRV, Respiratory Rate)**, each tappable. The four canonical Recovery drivers (HRV, RHR, Sleep Performance, Respiratory Rate) are fully broken out only on the deep-dive page. Three-tier IA: overview → 7-day trend → raw 30-day biometric graph. "Each tile is a doorway, not a destination."

**Trend treatment:** A **Strain-vs-Recovery weekly overlay chart** on home; per-metric sparklines on deep-dives; longer-horizon narrative is the Weekly/Monthly Performance Assessment (now email-delivered as of May 2025).

**Hierarchy below hero:** vertical scroll of tiles — status strip → 3 dials → Weekly Plans → biometric quick cards → weekly trend chart → coaching. Tiles are **user-reorderable**. Bottom nav: Sleep/Recovery/Strain/Stress/Behaviors/Coach + a persistent floating "+" (log workout/journal, and the **WHOOP Coach** AI entry).

**Color/dark mode:** near-black (Cod Gray) canvas, dark-first. Disciplined semantic vocabulary — green/yellow/red carry meaning, strain owns blue, "no arbitrary accent colors." Huge score numerals, small secondary labels, white-on-black sans-serif. Black is chosen so colored scores read as primary, not decorative, and for early-morning eye comfort.

**Signature motifs:** the traffic-light Recovery ring; **Strain Coach target dial** (recommends a daily strain range you fill toward); **Sleep Coach/Planner** with haptic smart alarm; **WHOOP Coach** AI chat; **Stress Monitor** (0–3 + breathwork); **Journal** (160+ behaviors auto-correlated to recovery). Reviewers warn it's information-dense and "daunting" — *a companion app can win by being calmer.*

Sources: whoop.com/thelocker/the-all-new-whoop-home-screen, .../how-does-whoop-recovery-work-101, .../how-does-whoop-strain-work-101; developer.whoop.com/docs/whoop-101; 925studios.co/blog/whoop-design-breakdown; the5krunner.com/2023/03/28/new-whoop-home-screen.

---

## 2. Oura — "one big thing" + the contributors list

**Leads with:** Redesigned app collapses to **three tabs (Today · Vitals · My Health)**. The **Today tab** leads with **"one big thing"** — a single dynamic, time-of-day-aware highlight/insight — with the **three scores (Readiness · Sleep · Activity)** as a row of shortcut chips/circular gauges at the top. Readiness is the morning hero, shown as a **circular 0–100 gauge**.

**Tier encoding:** Readiness **85+ = "Optimal, ready for action," 70–84 = "Good," <70 = "Pay attention, not fully recovered."** Named, plain-language tiers — the strongest verbal labeling of any app here.

**What shaped it (gold-standard contributors list):** Readiness decomposes into ~7 **contributors** in three pillars — *Body Stress* (Resting Heart Rate, HRV Balance, Body Temperature, Recovery Index), *Sleep* (Sleep, Sleep Balance), *Activity* (Previous Day Activity, Activity Balance). Each contributor is a **horizontal bar against a baseline**; **red bars flag what's dragging the score down**. In the new app a **down-arrow expands top contributors inline; a side-arrow opens full detail** — clean progressive disclosure. Baseline ranges contextualize every metric.

**Trend treatment:** Vitals tab shows each metric with its baseline band; My Health holds slow-moving trends (Cardiovascular Age, Stress Resilience) as weekly/quarterly/yearly graphs and shareable reports.

**Hierarchy below hero:** Today = highlight → score shortcuts → secondary shortcuts (Heart Rate, Daytime Stress, Cycle) → **Timeline** (tag habits, see impact) → **Discoveries** (correlations). Dynamic and personalized by time of day.

**Color/dark mode:** signature **purple/teal** palette; **parts of the app recolor based on your biometrics** as a glanceable cue. Premium, calm, lots of breathing room.

**Signature motifs:** the **contributors-with-baseline-bars list**; the **narrative readiness message**; **"one big thing"** focus; **Oura Advisor** (AI reading across sleep/activity/diet, surfacing correlations); habit **tagging → Discoveries** loop.

Sources: support.ouraring.com Readiness Score; ouraring.com/blog/new-oura-app-experience, .../new-app-design; crausser.com/oura-redesign; liveworksleep.com/oura-app-features.

---

## 3. Ultrahuman — many scores, varied chart vocabulary

**Leads with:** Three big indices front-and-center — **Movement Index · Sleep Index · Recovery (Dynamic Recovery)** — followed by blocks: Stimulant (caffeine) Window, Cardio Fitness, heart rate, skin temperature, glucose/metabolic (on CGM).

**Tier encoding:** 0–100 indices, color-coded; Recovery (like Oura Readiness) blends RHR, HRV, temperature, sleep quality, movement. Specific thresholds unpublished.

**What shaped it:** drivers surface as expandable detail; **Dynamic Recovery** updates through the day.

**Trend treatment / signature:** notable trait is **heterogeneous chart metaphors on the home feed** — movement = **speedometer**, caffeine window = **line graph**, dynamic recovery = **bar graph** — but tapping in normalizes everything to simple bars. **Double-edged**: visually rich/scannable but inconsistent (cautionary anti-pattern).

**Signature motifs worth borrowing:** the **Stimulant/Caffeine Window** (timing guidance as a horizontal time-bar), **metabolic/glucose** integration, and **PowerPlugs** (toggleable add-on modules — users install the cards/insights they care about).

Sources: ultrahuman.com/ring; apps.apple.com/us/app/ultrahuman/id1491286709; honehealth.com/edge/oura-vs-ultrahuman; androidcentral.com Ultrahuman Ring Air review.

---

## 4. Apple — two paradigms: closeable Rings vs. neutral Health Summary

### Apple Fitness (Activity Rings)
- **Leads with** three large concentric nested rings: **Move (red/pink, outer)** = active kcal; **Exercise (green, middle)** = brisk minutes; **Stand (cyan/blue, inner)** = stand-hours. The rings *are* the hero.
- **Tier encoding: none.** Metaphor is **percentage-of-goal as arc length** — fill the 360° track, "close your ring" at 100%. Overachievement **wraps and overlaps with a glow** at the leading tip (built-in micro-reward). Each ring is a **two-tone angular gradient** with a bright moving "head."
- **Trend:** a **grid of miniature ring-trios**, one per day — scan a wall of tiny rings for streaks.
- Reverse-engineered colors (unofficial): Move ≈ #FA114F→#FF5E3A, Exercise ≈ #92E82A→#00E676, Stand ≈ #1EEAEF→#00B9C8, always on **pure black**.
- **Motifs:** closeable full-circle goal (zero numeric literacy needed), overlap glow, concentric nesting, grid-of-rings history, saturated-on-black premium feel.

### Apple Health (Summary tab)
- **Leads with a feed, not a number:** **Favorites** (user-pinned metric cards: value + unit + inline sparkline) → **Highlights** (auto-generated insight cards) → **Trends** → **"Get More From Health."**
- **Deliberately neutral/clinical — no scores, no good/bad tiers.** Per-category accent colors only (Heart red, Sleep teal/indigo, Respiratory teal).
- **Trends engine:** compares **last 90 days vs 365-day baseline**, shows an **up/down arrow** per metric. Detail pages use **D/W/M/6M/Y segmented charts**.
- **Motifs:** auto-insight Highlights feed, 90-vs-365 arrow trends, pin-your-own Favorites, an education/growth slot at the bottom.

Sources: developer.apple.com/design/human-interface-guidelines/activity-rings; apple.com/watch/close-your-rings; support.apple.com guides; macstories.net Health in iOS 13; github.com/JonasDoesThings/react-activity-rings.

---

## 5. Garmin — Body Battery energy metaphor + Morning Report narrative

### Body Battery (the energy hero)
- A **0–100 "energy reserve"** with an explicit **battery metaphor** (you charge/drain like a phone), shown as current value + a **24-hour line/area graph color-coded green=charging, orange/red=draining.**
- Bands: 76–100 very high, 51–75 medium-high, 26–50 low, 5–25 very low.
- **What shaped it (best-in-class explainability):** a **"Charged" vs "Drained" ledger** — sleep dominates charging (+40–60 overnight); workouts, stress, alcohol, illness drain. The green-up/red-down timeline makes cause→effect visible at a glance.

### Morning Report (the narrative sequence)
On first wake wrist-raise, a **once-daily story of stacked cards**: greeting+weather → **Sleep Score (0–100)** → **HRV Status** (Balanced/Unbalanced/Low/Poor) → **Body Battery** → **Training Readiness** → **Recovery Time**. Reads like a story, not a dashboard. Content/order editable.

### Training Readiness (closest analog to a recovery score)
**Named color bands:** 80–100 "Prime" (blue), 60–79 "Primed" (green), 40–59 "Recovering" (orange), 20–39 "Strained" (red), 0–19 "Very Strained" (dark red); >73 train hard, <34 rest. Crucially it **lists its six contributing factors with sub-scores** (last-night sleep, 3-night sleep history, recovery time, HRV status, acute load, 3-day stress) — a transparent contributors panel.

**Home ("My Day"):** a **fully reorderable** vertical stack of color-coded metric cards ("Edit My Day," drag handles, pin-to-top), plus a 7-day comparison strip. Garmin-blue palette + per-metric accents; OS-following dark mode.

**Motifs to borrow:** the once-daily **Morning Report narrative timed to wake-up** (strongest engagement pattern of all eight); **Body Battery battery metaphor + charged/drained ledger**; **named color bands** pairing a word with a number; deeply reorderable cards.

Sources: support.garmin.com Body Battery FAQ & Morning Report; garmin.com training-readiness; the5krunner.com Body Battery & Training Readiness; shoulditrain.com/blog/garmin-morning-report-explained; road.cc Garmin Connect dashboard revamp.

---

## 6. Athlytic — the closest HealthKit WHOOP clone, narration-first

**Leads with:** a **dynamic written daily summary greeting** ("puts all the stats into words") that **rewrites itself through the day** — the standout emotional motif — plus score panels. Recent refresh literally announced **"Goodbye rings!"**, moving the hero to **rectangular panels** (Recovery %, Sleep %, Calories), keeping a **ring only for Exertion** (with a target slider), under iOS-26 **Liquid Glass** translucency on a dark base.

**Tier encoding:** Recovery 0–100%, **green/yellow/red** (tracks WHOOP's bands; exact cutoffs unpublished), and notably **static — generated once each morning**. **Exertion 0–10** (lower ceiling vs WHOOP's 21) with a personalized **green Target Exertion band**. Sleep = % quality + Target Bed Time.

**What shaped it:** Recovery driven by **HRV + RHR vs a rolling 60-day baseline** (HRV weighted higher). Drivers surface as **Daily HRV / HR charts**, not inline breakdowns — and via the written summary. Reviewers note it's "data-heavy / slightly busy."

**Trend:** home line graph plots **Recovery + Exertion together with the Target Range overlaid** (effort vs recommendation in one glance) + HRV/HR/Stress/Weekly-Battery charts.

**Signature dual-metric pattern (key insight):** **static morning Recovery verdict + a live "Battery"** that charges/drains in real time off each new HRV sample (naps charge, hard workouts/alcohol drain). Cleanly solves "should the number move during the day?" — keep the verdict fixed, let a *separate* battery move. Plus **deep widget/complication parity** (11+ widgets mirror every card).

Sources: techradar.com "this app turns my Apple Watch into a WHOOP band"; athlyticapp.helpscoutdocs.com (Recovery, Battery); athlyticapp.com/widgets; apps.apple.com/us/app/athlytic-ai-fitness-coach.

---

## 7. Bevel — single-number-first + "Energy Bank" fusion

**Leads with:** a stacked column of **percentage score cards (Strain · Recovery · Sleep)** plus the signature **"Energy Bank"** body-battery. Every domain reduces to **one 0–100% number** with a line graph (e.g. "Recovery 70% – strong recovery"); drill down one tap for the why.

**Tier encoding:** unified 0–100%, higher=better, "intuitive color coding" + qualitative labels ("strong recovery," "below normal"). **Strain uses a personalized Target Strain band, not fixed zones**, with the one confirmed semantic color **orange = above-target (overreaching)**.

**What shaped it:** interpretation over raw data — contributors (Sleep Score, Resting HRV, RHR, +temp/resp/SpO2) live on detail screens and in **"Bevel Intelligence"** (AI chat that connects the dots), keeping the home hero clean.

**Trend:** **line graphs (not WHOOP bars)**; **Energy Bank = battery icon + dual intraday line of Energy + Stress** across the day. (Weekly/monthly comparison is a known user-requested gap.)

**Hierarchy/customization:** editable, **themeable** vertical card stack (illustrative *or* minimalist backgrounds), reorderable, mirrored into a lock-screen **Smart Stack**. Rich card inventory (Strain, Recovery, Sleep, Stress, Energy Bank, Health Monitor, Hydration, Nutrition, Macros, Biological Age, Journal).

**Motifs to borrow:** **"Energy Bank"** fusing Recovery+Sleep+Strain+Stress into one intraday curve; personalized target band with orange=overreaching; AI feed keeps cards clean; delightful micro-interactions (mood logger morphs as you slide). Aesthetic called "remarkably Apple-esque."

*Other HealthKit apps:* **Gentler Streak** — "Daily Readiness" + an **"Activity Path" comfort-zone corridor** (Go Gentler / Push Harder) instead of pass/fail verdicts; **Training Today / HRV4Training** — minimalist single readiness gauge (the calm opposite of Athlytic's density).

Sources: screensdesign.com/showcase/bevel-health-performance; bevel.health (+ /blog strain & recovery); help.bevel.health; neura.health Bevel review; gentler.app.

---

# SYNTHESIS

## (a) The 5–7 most transferable patterns for a layered home

1. **Hero = one color-coded morning verdict, glanceable in <10s.** Make Recovery a single arc/ring or big % with the **green/yellow/red** traffic light (WHOOP's 67/34/0 bands are the de-facto standard users already understand). One number, huge type (~60–72pt), on black. Don't make people read to know if today is green.

2. **Pair the static verdict with a live "battery."** The cleanest solution to "should my score change during the day?" (Athlytic, Bevel, Garmin all converged here): **freeze Recovery as a morning verdict, add a separate intraday energy battery** that charges/drains off new samples. The battery metaphor is universally legible and gives a reason to reopen the app midday.

3. **Narrate it in plain language.** Athlytic's **self-rewriting daily summary** and Garmin's **Morning Report** are the highest-engagement motifs found. Lead with **one or two sentences** ("You're 78% recovered and well-rested — room for a hard session today") that update with time of day. Biggest differentiation opportunity over WHOOP itself.

4. **Secondary headline scores as a row of chips/dials.** Below the hero, a horizontal trio (Sleep · Strain · Battery, or Sleep · Activity · Stress) as **small rings/gauges with number + one-word label** — each a doorway. Mirrors WHOOP's three dials and Oura's score shortcuts.

5. **Always answer "why?" one tap down — with a baseline-bar contributors list.** Oura's **horizontal contributor bars vs baseline, red = dragging you down**, plus Garmin's **six-factor breakdown with sub-scores**, are the gold standard. On home, show 2–3 top drivers inline behind a **down-arrow expand**; full breakdown behind a **side-arrow**. Keep raw HRV/RHR/respiratory as quick-access cards, full charts on the deep dive (WHOOP's 3-tier IA).

6. **A reorderable, user-curated metric wall.** Below the headline scores, a **vertical scroll of editable cards** (Garmin "Edit My Day," Apple "Favorites," Bevel themeable stack, Ultrahuman PowerPlugs). Let users pin/reorder/hide and mirror cards into **widgets + lock-screen + complications** with identical vocabulary (Athlytic's parity is the bar).

7. **A daily-narrative moment + a trend overlay.** Borrow Garmin's **once-per-day wake-up report** as a dismissible top card, and WHOOP's **Strain-vs-Recovery weekly overlay** as the one chart on home. Add Apple's **90-vs-365 up/down arrow** as the dead-simple "trending better or worse?" cue on each metric.

## (b) Common pitfalls / anti-patterns to avoid

- **Information overload.** WHOOP, Athlytic, and Ultrahuman are all called "daunting / data-heavy / busy." More numbers ≠ more value. **Calm is a competitive edge** — default to a quiet home, let power users expand.
- **Inconsistent chart metaphors.** Ultrahuman mixes speedometer + line + bar on one screen, then normalizes to bars on tap — jarring, raises cognitive load. **Pick one chart language and repeat it.**
- **A blank-slate cold start.** Bevel's home "starts as a completely blank slate" until data populates — demoralizing on day one. Seed with onboarding/sample states and baseline-building messaging.
- **Ambiguous score motion.** A single score that silently moves during the day confuses (is it recovery or current state?). Resolve with the verdict-vs-battery split (pattern #2).
- **Customization that can't actually reorder.** Apple Health Favorites long couldn't be freely reordered — a recurring complaint. If you ship customization, make it true drag-reorder + hide.
- **Missing the longer horizon.** Bevel users explicitly request weekly/monthly comparison it lacks. Ship at least a 7-day and 30-day trend from day one.
- **Burying the verdict under chrome.** Don't let a battery strip, greeting, or nav steal the top third — the recovery color must be the first thing the eye lands on.

## (c) Concrete color / typography / charting conventions

### Color system
- **Canvas: true black / near-black** (WHOOP Cod Gray, Apple rings-on-black, Athlytic/Bevel dark base). Dark-first is the category default — makes saturated data glow, eases dawn/dusk checks, reads premium. Offer light mode but design dark-first.
- **Semantic, not decorative, color.** Reserve hue for meaning and repeat everywhere: **Recovery = green→yellow→red traffic light; Strain/effort = blue (WHOOP) or orange-when-over-target (Bevel); over-target/overreaching = orange/amber.**
- **Per-metric accent identity** (Apple/Garmin): give Sleep, Heart, Respiratory each a consistent accent so cards are recognizable by color alone. Oura recolors UI regions by biometric state as an ambient cue.
- **Reference hex (unofficial, reverse-engineered — sample real values first):** Apple Move ≈ #FA114F→#FF5E3A, Exercise ≈ #92E82A→#00E676, Stand ≈ #1EEAEF→#00B9C8. WHOOP/Oura withhold official hex. Use **two-tone angular gradients** on rings for an energetic moving "head" rather than flat fills.

### Typography
- **Aggressive size hierarchy:** hero score huge (~60–72pt), labels small/secondary, white/light-gray on black. SF Pro / SF Compact Rounded (or a clean geometric sans) for numerals.
- **Pair every number with a word** (Garmin Prime/Primed, Oura Optimal/Good/Pay attention). A number alone underperforms a number + tier label + plain-language sentence.

### Charting
- **One chart language, repeated.** Choose bars (WHOOP) or lines (Bevel) and stay consistent.
- **Rings for goal-completion / single-score state** (recovery, exertion-vs-target); **lines for intraday continuous signals** (Body Battery, energy/stress, HR); **horizontal baseline bars for contributors** (Oura); **mini-ring or sparkline grids for streak history** (Apple).
- **Always plot a baseline/target band**, not just the raw value — Oura's baseline ranges, Athlytic's target-exertion overlay, Garmin's personal HRV band. Context (vs *your* normal) beats absolute numbers.
- **Color-code the trend itself** (Garmin green=charging/red=draining on the same line) so direction is readable without axis-reading.
- **Tier depth:** home = score + 1 chart; tap = 7-day trend + top contributors; tap again = 30-day raw biometrics. Smooth shared-element transitions to preserve spatial context.

### Suggested layout to sketch (top → bottom)
Black canvas → slim status/greeting strip → **plain-language narrative sentence** → **hero Recovery ring (green/yellow/red, ~70pt %)** → **row of 3 secondary dials** (Sleep · Strain · live Battery) → **expandable top-3 contributors** (baseline bars, red = dragging) → **Strain-vs-Recovery weekly overlay** → **reorderable card wall** (quick biometrics, journal, stress, nutrition…) → education/coach slot. One AI/coach entry as a persistent button.

---

## Source URLs

**WHOOP**
- https://www.whoop.com/us/en/thelocker/the-all-new-whoop-home-screen/
- https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/
- https://www.whoop.com/us/en/thelocker/how-does-whoop-strain-work-101/
- https://developer.whoop.com/docs/whoop-101/
- https://www.925studios.co/blog/whoop-design-breakdown
- https://the5krunner.com/2023/03/28/new-whoop-home-screen-looks-pretty-but-is-it-as-intuitive/

**Oura**
- https://support.ouraring.com/hc/en-us/articles/360025588434-Readiness-Score
- https://ouraring.com/blog/new-oura-app-experience/
- https://ouraring.com/blog/new-app-design/
- https://www.crausser.com/oura-redesign
- https://liveworksleep.com/oura-app-features/

**Ultrahuman**
- https://www.ultrahuman.com/ring/
- https://apps.apple.com/us/app/ultrahuman/id1491286709
- https://honehealth.com/edge/oura-vs-ultrahuman/
- https://www.androidcentral.com/wearables/ultrahuman-ring-air-review

**Apple**
- https://developer.apple.com/design/human-interface-guidelines/activity-rings
- https://www.apple.com/watch/close-your-rings/
- https://support.apple.com/en-us/104997
- https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios
- https://www.macstories.net/stories/health-in-ios-13-a-foundation-for-apples-grand-wellness-ambitions/
- https://github.com/JonasDoesThings/react-activity-rings

**Garmin**
- https://support.garmin.com/en-US/?faq=VOFJAsiXut9K19k1qEn5W5 (Body Battery)
- https://support.garmin.com/en-US/?faq=6LL2ZOEJry3z69WKK9Ymd9 (Morning Report)
- https://www.garmin.com/en-US/garmin-technology/running-science/physiological-measurements/training-readiness/
- https://the5krunner.com/garmin-features/sleep/body-battery/
- https://the5krunner.com/garmin-features/training/training-readiness/
- https://www.shoulditrain.com/blog/garmin-morning-report-explained
- https://road.cc/content/tech-news/231723-garmin-connect-mobile-app-gets-revamp-colourful-new-dashboard

**Athlytic**
- https://www.techradar.com/computing/websites-apps/this-app-turns-my-apple-watch-into-a-whoop-band
- https://athlyticapp.helpscoutdocs.com/article/20-understanding-recovery
- https://athlyticapp.helpscoutdocs.com/article/38-understanding-battery
- https://www.athlyticapp.com/widgets
- https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755

**Bevel**
- https://screensdesign.com/showcase/bevel-health-performance
- https://www.bevel.health/
- https://www.bevel.health/blog/the-basics-strain-performance
- https://help.bevel.health/en/articles/10431489
- https://neura.health/insight/bevel-health-app-in-depth-review

**Gentler Streak / others**
- https://gentler.app/
- https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102
