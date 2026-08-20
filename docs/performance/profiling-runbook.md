# Profiling runbook — how to actually take the measurements

Step-by-step for capturing the Phase 0 baselines. Follow this with the device in your hand;
write the numbers into [`baselines.md`](baselines.md) as you go.

Budget about **2–3 hours**. Most of it is waiting through 60-second holds.

---

## Part 0 — Before you start (15 min, once)

### 0.1 Device setup

1. Plug the iPhone in. Unlock it, tap **Trust** if prompted.
2. On the device: **Settings → Privacy & Security → Developer Mode → On**. It reboots.
   (If you don't see Developer Mode, connect the device to Xcode once and it appears.)
3. Back in Xcode: **Window → Devices and Simulators**, confirm the device shows as
   connected with no "preparing" spinner. First connection can take several minutes while
   Xcode copies symbols — let it finish or every trace will be unsymbolicated.
4. **Take the device off charge** and leave it off charge for the whole session. Charging
   changes thermal behaviour.
5. Set brightness to something fixed (50% is fine) and turn **off** auto-brightness. The
   display is a big share of energy numbers and you want it constant.

Signing is already configured (`DEVELOPMENT_TEAM = BTDYS54RKT`, automatic), so a device
build should just work.

### 0.2 Pick the scheme

In Xcode's scheme picker choose **`NextOutcome (Profile)`**, and select your device (not a
simulator) as the destination.

That scheme is the whole point of Phase 0 — Release config, no debugger, Main Thread Checker
and the Performance Antipattern Checker off, and no verbose network logging. Profiling the
ordinary `NextOutcome` scheme gives you Debug `-Onone` numbers, which are wrong in a
direction that wastes days.

### 0.3 One thing that will look broken but isn't

Press **⌘R** with this scheme and Xcode will install and launch the app, then immediately
show "Running" as finished and go idle. **That is correct.** The scheme deliberately
launches without attaching LLDB, so there is nothing for Xcode to sit and watch. Look at the
phone — the app is running.

---

## Part 1 — Three recording sessions, not one

Instruments perturbs what it measures, and different instruments perturb differently.
Allocations in particular adds enough overhead to distort CPU timings. So each screen gets
profiled **three separate times**, once per session below.

Do it screen-by-screen within a session (all five screens under Time Profiler, then all five
under Animation Hitches, and so on) rather than instrument-by-instrument within a screen —
fewer template switches, less chance of drift.

| Session | Template | Add these instruments | Gives you |
|---|---|---|---|
| **A** | Time Profiler | `os_signpost`, `Activity Monitor` | Where CPU goes · avg CPU % · signpost counts |
| **B** | Animation Hitches | — | Hitch time ratio (the "feels janky" number) |
| **C** | Allocations | `VM Tracker` | Resident memory |

A fourth, one-off session with the **Network** template answers the socket-count question
for finding #02. That one takes five minutes and only needs the Esports hub.

### Launching Instruments

**Product → Profile (⌘I).** This builds Release and opens Instruments with the app already
targeted. Pick your template in the chooser.

If Instruments opens without your app selected, set the target in the toolbar: device name →
**NextOutcome**.

### Adding an instrument to a template

Click the **`+`** at the top-right of the Instruments window to open the Library, type the
instrument's name, and drag it into the track list on the left. Do this before you record.

---

## Part 2 — Session A: Time Profiler + signposts

This is the session that settles findings #01, #03, and #05.

### 2.1 Set it up

1. ⌘I → **Time Profiler**.
2. Add **`os_signpost`** and **`Activity Monitor`** from the Library (Part 1).
3. Don't press record yet.

### 2.2 For each of the five screens

1. **Navigate to the screen on the device first.** Let it finish loading and settle.

   > The `-preselectCategory` shortcut you may remember is `#if DEBUG` only, so it does
   > nothing in this scheme. Navigate by hand. This is better anyway — it keeps one-time
   > navigation and load cost out of the steady-state numbers.

2. Press **record** (the red circle) in Instruments.
3. Run the interaction script for that screen from [`baselines.md` §3](baselines.md).
   Follow it exactly; the "after" runs have to repeat it.
4. Press **stop**.
5. Read the numbers (§2.3 below) and write them into the tables.
6. Repeat **three times**. Discard the first run after a cold launch — it pays one-time
   caching costs. Record the **median** of the three.
7. Let the device sit ~30 s between runs so it doesn't thermally throttle into flattering
   you.

### 2.3 Reading Session A

**Average CPU %** — select the **Activity Monitor** track, drag-select the steady-state
portion of the timeline (skip launch and initial load), and read `%CPU` for the NextOutcome
process. Note the main thread's share separately from the Time Profiler track: 40% CPU spread
across threads and 40% pinned to the main thread are very different problems.

**Where the CPU goes** — select the **Time Profiler** track, then in the detail pane at the
bottom turn on **Invert Call Tree** and **Hide System Libraries**. This is where you look for
the specific claims:

| Look for | Confirms |
|---|---|
| `Hasher.combine` / `String.hash` under `NavigationLink` | #01 — deep hashing of `Event` |
| `Set.init` / `String.lowercased` under `HomeCardKind` | #03 — per-frame classification |
| `JSONDecoder.decode` on the Esports hub | #02 — firehose decoded per socket |
| `Shape.subtracting` / path boolean ops | #04 — the raised-control lip |

**Signpost counts — the important part.** Select the **`os_signpost`** track. In the detail
pane, filter to subsystem `com.nextoutcome.perf`, category `RenderPath`, and group the
intervals by name. You get three rows:

- `EventList.visibleEvents`
- `CryptoHub.visibleEvents`
- `HomeCardKind.classify`

**Record the count, not the duration.** These paths are individually cheap and collectively
ruinous — the finding is entirely about repetition. What you're testing:

> `HomeCardKind.classify` should fire once per event per data load. If a 30-second Home
> scroll shows it firing thousands of times, #03 is confirmed exactly as written.
>
> `EventList.visibleEvents` should fire once per user action. If it fires on every frame of
> a scroll, #05 is confirmed.

Write both counts into [`baselines.md` §5.3](baselines.md). After Phases 1 and 2 the success
criterion is a **collapse in count**, not a faster interval.

---

## Part 3 — Session B: Animation Hitches

The number that corresponds to "the app feels janky".

1. ⌘I → **Animation Hitches**.
2. Same procedure: navigate first, record, run the script, stop.
3. Read **hitch time ratio** in ms/s — milliseconds hitched per second of scrolling — not the
   raw hitch count. Under 5 ms/s is good; over 10 ms/s is something a user notices.
4. Three runs, median, into §5.1.

Worth doing on the device with **Debug → View Debugging → Rendering → Color Offscreen-Rendered**
turned on for one exploratory pass (not a recorded run): the shadow and blend passes from
`OutcomePill` and the flag marquee light up yellow, which makes #04 and #06 visible rather
than theoretical.

---

## Part 4 — Session C: Allocations

1. ⌘I → **Allocations**. Add **VM Tracker** from the Library.
2. Navigate, record, run the script, stop.
3. Read **resident size** from VM Tracker — *not* "All Heap Allocations", which understates
   badly by ignoring image and layer backing stores. Image memory is exactly what finding
   #15 is about, so the heap number would hide the thing you're measuring.
4. Take the reading twice: immediately after the script, and 5 s later once transient
   allocations have drained. Record the second.

For the Home feed specifically, the interesting test is whether memory is **bounded or
monotonic**: scroll 200 rows, then scroll back to the top. If resident size doesn't come back
down, `AsyncImage` is re-decoding and holding full-size bitmaps (#15).

---

## Part 5 — Socket count (finding #02)

Five minutes, once.

1. ⌘I → **Network** template.
2. Navigate to the **Esports hub**, wait for hero cards and live scores.
3. Record 60 s.
4. Count connections to `sports-api.polymarket.com`.

**Expected baseline: 5.** Target after Phase 3: **1**. This one is binary and doesn't need
three runs.

While you're here, note the connection count to `ws-live-data.polymarket.com` from the Crypto
live screen too — that feeds finding #11.

---

## Part 6 — The lifecycle probes (finding #09)

**Read [`baselines.md` §3.6](baselines.md) before doing this.** The audit originally framed
#09 as background battery drain and that framing was too broad — `Info.plist` declares only
`remote-notification`, so iOS suspends the app within seconds of backgrounding and freezes
every thread no matter what our code does. "Background it and watch CPU" reads ~0 either way.

Run the two probes in §3.6 instead, under Session A's template (Activity Monitor gives you
the CPU trace across the whole thing):

- **Probe A — hidden but foregrounded.** Switch tabs, then present a sheet, and see whether
  the live work actually stops. The sheet case is the interesting one: SwiftUI does not fire
  `onDisappear` for a view covered by a sheet.
- **Probe B — suspend and resume.** Peak CPU in the first 5 s of background, then the size
  of the reconnect burst when you come back.

**If Probe A comes back at ~0 across the board, say so** — it means the existing
`.task`/`onDisappear` teardown is doing its job, #09 is smaller than the audit claimed, and
Phase 3 should be re-prioritised to put finding #02 first.

---

## Part 7 — When you're done

1. Fill in every table in [`baselines.md` §5](baselines.md). A blank cell is fine; a guessed
   cell is not.
2. Fill in the header: device model, iOS version, git SHA, date.
3. **Save the `.trace` files.** Instruments → File → Save As. Put them somewhere durable and
   note where in the doc — being able to re-open the "before" trace six weeks later is worth
   more than the summary numbers, because the question you'll want to ask then is one you
   didn't think to write down now.
4. Commit `baselines.md`. It's tracked now, which is the point.

Then Phase 1 starts, and every claim in it has a number to beat.

---

## Quick reference

| I want | Session | Where to read it |
|---|---|---|
| Does it feel janky? | B — Animation Hitches | Hitch time ratio, ms/s |
| Where is CPU going? | A — Time Profiler | Inverted call tree, system libs hidden |
| How much CPU total? | A — Activity Monitor | `%CPU` for NextOutcome |
| Is #03/#05 real? | A — os_signpost | Interval **count**, subsystem `com.nextoutcome.perf` |
| How much memory? | C — Allocations + VM Tracker | Resident size |
| How many sockets? | Network template | Connections to `sports-api.polymarket.com` |
| Does work stop when hidden? | A, via §3.6 Probe A | CPU after tab switch and under a sheet |
