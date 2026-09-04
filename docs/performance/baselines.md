# Performance baselines — recording protocol

**Purpose:** capture the "before" numbers that Phases 1–3 of the performance plan are graded
against. A finding is not fixed because the code looks better; it is fixed because a number
moved.

**Status:** protocol and tooling are in place (Phase 0). **The baseline tables below are
empty and must be filled in on a physical device before Phase 1 starts.**

---

## 1. Ground rules

These exist so that a run taken today and a run taken in three weeks are comparable. A
baseline recorded loosely is worse than no baseline, because it invites false conclusions.

| Rule | Why |
|---|---|
| **Physical device, never the Simulator** | The Simulator runs your Mac's cores and GPU. Its CPU and render numbers say nothing about a phone. Note the exact model — an iPhone 13 and an iPhone 16 Pro will not agree, and neither is wrong. |
| **`NextOutcome (Profile)` scheme** | Release config, debugger off, Main Thread Checker and Performance Antipattern Checker off. Debug is `-Onone` and inflates ARC and generics traffic well beyond what ships. |
| **Same device, same iOS version, before and after** | Comparing across devices measures the devices, not the change. |
| **Device off charge, screen brightness fixed, ~30 s cool-down between runs** | Thermal throttling silently halves sustained CPU. If the device is warm, the "after" run will look better for free. |
| **Wi-Fi, same network** | Several screens are network-bound on first load. Cellular variance will drown the signal. |
| **Three runs per screen, record the median** | Single runs are noise. Discard the first run after a cold launch — it pays one-time caching costs. |
| **No `-verboseNetworkLogging`** | The Profile scheme omits it, so `NetworkLogger` stays at `.basic`. With it on, `prettyJSON` re-serialises every response body mid-trace and lands directly on what you are measuring. |

### A gotcha to know about

The `-preselectCategory <slug> <tagID>` launch argument that jumps straight to a rail
category is `#if DEBUG` only (`RootView.swift`), so it **does not work in the Profile
scheme**. Navigate manually instead, and start the Instruments recording *after* you have
arrived on the screen — Instruments' record button is independent of app launch. That is
better practice here anyway: it keeps navigation cost out of the steady-state numbers.

---

## 2. What to record

Three numbers per screen. Definitions matter more than precision.

**Hitch rate** — from the **Animation Hitches** template. Record *hitch time ratio*
(ms hitched per second of scrolling), not the raw hitch count. Apple's guidance: under
5 ms/s is good, over 10 ms/s is user-visible. This is the number that corresponds to
"the app feels janky".

**Average CPU** — from **Time Profiler**, reading the CPU track over the steady-state
window only (exclude launch and initial load). Record the app process's average, and
separately note the main thread's share — a screen at 40% CPU split evenly across threads
is a very different problem from 40% pinned on the main thread.

**Resident memory** — from **Allocations** with the **VM Tracker**, taking *resident size*
(not "All Heap Allocations", which understates by ignoring image and layer backing stores).
Record the value after the interaction script completes, then again 5 s later once transient
allocations have drained.

---

## 3. Interaction scripts

A baseline is only comparable if the "after" run does the same thing. Follow these exactly
and keep them stable across phases — if a script has to change, the old numbers retire with
it.

### 3.1 Home scroll — audit findings #01, #03, #04, #05, #15, #17

1. Cold launch, wait for the feed to render.
2. Start recording.
3. Flick-scroll to the bottom of the loaded page, pause 1 s, flick-scroll back to the top.
   Repeat three times. Use fast flicks, not slow drags — the goal is peak load.
4. Stop recording.

*Watch for:* `EventList.visibleEvents` and `HomeCardKind.classify` signpost counts
(§4); `Hasher.combine` under `NavigationLink` in the inverted call tree; offscreen render
passes from `OutcomePill`.

### 3.2 Crypto hub — #01, #03, #04, #05, #10, #15

1. From Home, tap the **Crypto** rail category. Wait for the list to settle.
2. Start recording.
3. Scroll the list top to bottom twice.
4. Change the sub-tab (**All → Up/Down → All**), then the sort (**24h volume → Total
   volume → 24h volume**). Each change re-runs the filter pipeline.
5. Stop recording.

*Watch for:* `CryptoHub.visibleEvents` count and duration — this is the screen where the
uncached five-filter chain runs over the largest array (up to 500 rows).

### 3.3 Esports hub — #02, #09, #11, #15

1. From Home, tap the **Esports** rail category. Wait for hero cards and live scores.
2. Start recording. **Hold for a full 60 s** — this screen's cost is sustained, not
   transient, and a short trace will miss it.
3. Scroll the match list once, then return to the top and leave it idle for the remainder.
4. Stop recording.

*Watch for:* `JSONDecoder` time in Time Profiler (the firehose is decoded once per open
socket); the count of open WebSockets to `sports-api.polymarket.com` in the **Network**
instrument — expect **5**.

### 3.4 Crypto live (BTC 5m) — #09, #11, #14

1. From the Crypto hub, open the pinned **BTC Up or Down 5m** card.
2. Start recording. Hold for 60 s with no interaction — the screen is fully live-driven.
3. Switch the chart mode (**Price → Candles → Price**), hold 10 s on each.
4. Stop recording.
5. **Then run the two lifecycle probes in §3.6** from this screen — it is the app's densest
   concentration of live work and therefore the best place to see them.

*Watch for:* update frequency of `spotState` (20 Hz today); time in `refreshCandleDomain`.

### 3.5 World Cup hub — #06, #07, #09, #15

1. From Home, open **Sports → World Cup**, or the World Cup rail category if present.
2. Start recording on the tab showing the **flag marquee**. Hold 30 s without touching.
3. Switch to the **Map** tab (the SceneKit globe). Hold 30 s without touching.
4. Navigate away to Home. **Keep recording 15 s.**
5. Stop recording.

*Watch for:* sustained GPU utilisation and frame rate on the Map tab; whether GPU work
continues after step 4 (`rendersContinuously` is set with no pause on disappear, so whether
SwiftUI tearing down the `SCNView` saves you is exactly the open question).

### 3.6 Lifecycle probes — finding #09

**Read this before measuring #09, or you will measure the wrong thing.**

The audit originally framed #09 as background battery drain. That framing was too broad.
`Info.plist` declares only `remote-notification`, which wakes the app for silent pushes and
does *not* keep it running — so iOS suspends the process within a few seconds of
backgrounding and freezes every thread regardless of what our code does. A naive "background
it and watch CPU" test will read ~0 either way and tell you nothing.

The teardown is also better than "no `scenePhase` anywhere" suggested: `EsportsHubView`,
`SocialStripView`, and `WorldCupHubViewModel.pollResults` are all correctly tied to
`.task` / `.onAppear`+`.onDisappear`. What remains genuinely exposed is narrower, and these
two probes target it.

**Probe A — hidden but foregrounded.** This is the one that matters.

1. Reach a live screen (Crypto live, or the Esports hub).
2. Start recording, hold 15 s to establish the live rate.
3. Switch to another tab. Stay in the app. Hold 45 s.
4. Present a sheet over a live screen (e.g. tap a trade button) and hold 30 s.
5. Stop recording.

*SwiftUI does not fire `onDisappear` for a view covered by a sheet*, so step 4 is where
work most plausibly survives. Record whether CPU and network traffic fall on the tab switch
and on the sheet.

**Probe B — suspend and resume.**

1. From a live screen, start recording. Background the app.
2. Watch the **first 5 seconds** — the pre-suspension window is the only part where our code
   still runs. Record peak CPU in that window.
3. Wait 60 s, then foreground the app. Record the **reconnect burst**: how many sockets
   re-open at once, and the CPU spike as every backoff loop resumes together.

*Steady-state background CPU is not the measurement.* The pre-suspension window and the
resume burst are.

---

## 4. Reading the signposts

Two audit findings claim that work is repeated per SwiftUI body evaluation. Signposts settle
that rather than arguing it.

**Setup:** Instruments → **os_signpost** instrument (add it to the Time Profiler template so
you get both in one trace). Set the subsystem filter to `com.nextoutcome.perf`, category
`RenderPath`.

**Intervals emitted** (defined in `Sources/SharedDomain/PerfSignpost.swift`):

| Interval | Site | Audit finding |
|---|---|---|
| `EventList.visibleEvents` | `EventListViewModel.visibleEvents` | #05 |
| `CryptoHub.visibleEvents` | `CryptoHubViewModel.visibleEvents` | #05 |
| `HomeCardKind.classify` | `HomeCardKind.classify` | #03 |

**What to record: the count, then the duration.** These paths are individually cheap and
collectively ruinous — the finding is about repetition. Concretely:

- `HomeCardKind.classify` should fire **once per event, per data load**. If a 30 s Home
  scroll shows thousands of intervals, #03 is confirmed as stated.
- `EventList.visibleEvents` should fire **once per user action** (filter change, page load).
  If it fires on every frame of a scroll, #05 is confirmed.

After Phase 1 and Phase 2, re-run and record the new counts in the same table. The success
criterion for both findings is a **collapse in interval count**, not a faster interval.

> Signposts ship in Release deliberately — that is what they are for. When Instruments is not
> recording, `OSSignposter` short-circuits on a boolean check and emits nothing. Instrumentation
> compiled out of Release would be instrumentation you could never use, because Release is the
> only configuration worth measuring.

---

## 5. Baseline tables — TO BE FILLED IN

**Device:** _(model, e.g. iPhone 15 Pro)_ ·
**iOS:** _(version)_ ·
**Build:** _(git SHA)_ ·
**Date:** _____ ·
**Recorded by:** _____

### 5.1 Headline metrics

Median of three runs. Leave a cell blank rather than guessing.

| Screen | Hitch time ratio (ms/s) | Avg CPU % (app) | Main-thread CPU % | Resident memory (MB) |
|---|---|---|---|---|
| Home scroll | | | | |
| Crypto hub | | | | |
| Esports hub | | | | |
| Crypto live (BTC 5m) | | | | |
| World Cup hub — marquee | | | | |
| World Cup hub — globe | | | | |

### 5.2 Lifecycle probes (finding #09) — see §3.6 for why these are the right tests

**Probe A — hidden but foregrounded.** Does work stop when the screen isn't visible?

| Live screen | CPU % visible | CPU % after tab switch | CPU % under a sheet | Sockets still open |
|---|---|---|---|---|
| Crypto live (BTC 5m) | | | | |
| Esports hub | | | | |
| World Cup hub (globe) | | | | |

*Target after Phase 3: the last three columns at ~0. If they are already ~0 at baseline, then
finding #09 is smaller than the audit claimed and Phase 3 should be re-prioritised accordingly.*

**Probe B — suspend and resume.**

| Live screen | Peak CPU % in first 5 s of background | Sockets re-opened on resume | CPU spike on resume |
|---|---|---|---|
| Crypto live (BTC 5m) | | | |
| Esports hub | | | |

### 5.3 Signpost counts (findings #03, #05)

Counts over one complete interaction script from §3.

| Interval | Screen | Count — baseline | Count — after Ph.1 | Count — after Ph.2 |
|---|---|---|---|---|
| `HomeCardKind.classify` | Home scroll | | | |
| `EventList.visibleEvents` | Home scroll | | | |
| `CryptoHub.visibleEvents` | Crypto hub | | | |

### 5.4 Socket count (finding #02)

| Screen | WebSockets to `sports-api.polymarket.com` |
|---|---|
| Esports hub | |
| Live stats tab | |
| Esports match detail | |

*Expected baseline: 5 on the hub. Target after Phase 3: 1.*

---

## 6. What Phase 0 changed

For the record, so a later reader knows the baseline is not measuring the pre-Phase-0 app:

- `NetworkLogger.default` now yields `.basic` in DEBUG rather than `.verbose`; bodies are
  opt-in via the `-verboseNetworkLogging` launch argument. Release was always `.none` and is
  unchanged. *(Audit #16.)*
- Added `Perf` / `OSSignposter.measure` in `SharedDomain`, and instrumented the three sites
  in §4.
- Added the shared `NextOutcome (Profile)` scheme, and checked in the previously
  auto-generated `NextOutcome` scheme alongside it (adding any shared scheme stops Xcode
  auto-creating the rest, so the everyday scheme had to become explicit too).

No behavioural change. Package test suite: 818 passing.

---

## 7. Companion documents

- Full audit with all 18 findings and the phased plan:
  <https://claude.ai/code/artifact/67fea7c1-173b-46a3-80e3-d71d7ffb2466>
- [`../ui-testing/NextOutcome-UI-Test-Suite.md`](../ui-testing/NextOutcome-UI-Test-Suite.md) —
  the XCUITest suite, whose navigation helpers are a useful reference for scripting §3
  consistently.
