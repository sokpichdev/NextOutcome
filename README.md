<!-- App Icon -->
<p align="center">
  <img src="screenshots/app_icon.png" alt="NextOutcome app icon" width="120"/>
</p>

<h1 align="center">NextOutcome</h1>

<p align="center">
  <b>Polymarket, built native for iOS.</b><br/>
  Browse live prediction markets, watch order books move in real time, and dive into
  purpose-built hubs for Sports, Crypto, Esports, Politics and the World Cup - countdown
  clocks, candle charts, a US race map and a spinning 3D globe included. Read-only today,
  on-chain trading is next.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2018%2B-blue"/>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange"/>
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-green"/>
  <img alt="Tests" src="https://img.shields.io/badge/tests-818%20passing-brightgreen"/>
  <img alt="Status" src="https://img.shields.io/badge/status-in%20development-yellow"/>
  <a href="https://www.sokpich.dev/nextoutcome"><img alt="Live preview" src="https://img.shields.io/badge/live_preview-sokpich.dev-black"/></a>
  <img alt="" src="https://komarev.com/ghpvc/?username=sokpichdev&color=blueviolet"/>
</p>

<p align="center">
  <b>Live preview →</b> <a href="https://www.sokpich.dev/nextoutcome">www.sokpich.dev/nextoutcome</a>
</p>

<p align="center">
  ⭐ If you like what you see, star the repo - clone instructions are below.
</p>

---

## Table of Contents

- [Why NextOutcome](#why-nextoutcome)
- [App Screenshots](#app-screenshots)
- [Demo GIF / Video](#demo-gif--video)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Privacy & Permissions](#privacy--permissions)
- [Project Status](#project-status)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Author](#author)

---

## Why NextOutcome

[Polymarket](https://polymarket.com) lives in a browser. NextOutcome brings its markets, order
books, and live sports data to a proper native iOS app - smooth scrolling feeds, real-time
WebSocket order books, live-updating charts, and category hubs that each get the treatment the
category deserves rather than one generic list. No wallet required to explore: browsing, order
books, live stats, and portfolio tracking are all watch-only today, with on-chain trading
actively on the roadmap.

---

## App Screenshots

> Captured from the current dev build in the simulator. Every tile below is a real capture -
> source files live in [`screenshots/`](screenshots/).

### Home & feeds

| | | |
|---|---|---|
| <img src="screenshots/home_trending.png" width="200"/><br/>Home feed - "All" | <img src="screenshots/home_politics.png" width="200"/><br/>Home feed - Politics | <img src="screenshots/search.png" width="200"/><br/>Search |
| <img src="screenshots/breaking_movers.png" width="200"/><br/>Breaking - 24h movers | <img src="screenshots/home_breaking.png" width="200"/><br/>Breaking - ranked list | |

### Market detail & trading

| | | |
|---|---|---|
| <img src="screenshots/market_detail.png" width="200"/><br/>Market detail - multi-outcome rows | <img src="screenshots/orderbook_live.png" width="200"/><br/>Live order book | <img src="screenshots/worldcup_franch_winner.png" width="200"/><br/>Binary market - chart & book |
| <img src="screenshots/trade_confirm_alert.png" width="200"/><br/>Trade sheet - `DSNumberPad` | <img src="screenshots/discuss_sheet.png" width="200"/><br/>Discussion sheet - comments, holders, activity | |

### Sports, World Cup & Esports

| | | |
|---|---|---|
| <img src="screenshots/home_sports_live.png" width="200"/><br/>Sports hub - Live feed | <img src="screenshots/home_sports_futures.png" width="200"/><br/>Sports hub - Futures | <img src="screenshots/sports_hub_catalogue.png" width="200"/><br/>Sports hub - Live now |
| <img src="screenshots/home_sports_mlb.png" width="200"/><br/>Sports hub - MLB league | <img src="screenshots/home_sports_wimbledon.png" width="200"/><br/>Sports hub - Wimbledon | <img src="screenshots/home_sports_worldcup.png" width="200"/><br/>Sports hub - World Cup |
| <img src="screenshots/home_worldcup_game.png" width="200"/><br/>World Cup - Games | <img src="screenshots/home_worldcup_bracket.png" width="200"/><br/>World Cup - Bracket | <img src="screenshots/home_worldcup_props.png" width="200"/><br/>World Cup - Props |
| <img src="screenshots/home_worldcup_map.png" width="200"/><br/>World Cup - SceneKit globe | <img src="screenshots/home_trending_worldcup_winners.png" width="200"/><br/>World Cup winner odds | |
| <img src="screenshots/esports_hub.png" width="200"/><br/>Esports hub - leaderboard & games | <img src="screenshots/esports_match_detail.png" width="200"/><br/>Esports match - map winners | |

### Crypto & Politics

| | | |
|---|---|---|
| <img src="screenshots/crypto_hub.png" width="200"/><br/>Crypto hub - 5m/15m/1h windows | <img src="screenshots/crypto_live.png" width="200"/><br/>Crypto live window - candles | <img src="screenshots/crypto_live_sections.png" width="200"/><br/>Crypto live - book & recent trades |
| <img src="screenshots/politics_hub.png" width="200"/><br/>Politics hub - Midterms map | <img src="screenshots/politics_midterm_election.png" width="200"/><br/>Midterms - Senate & House seat dots | |

---

## Demo GIF / Video

Recorded on the simulator and converted to GIF with `ffmpeg`; the source `.mov` for each clip
sits next to it in [`screenshots/`](screenshots/).

| Home - "All" feed | Sports hub - Soccer | Esports hub | Crypto hub |
|---|---|---|---|
| <img src="screenshots/home_all_listing.gif" width="200"/> | <img src="screenshots/sports_hub.gif" width="200"/> | <img src="screenshots/esports_hub.gif" width="200"/> | <img src="screenshots/crypto_hub.gif" width="200"/> |

| Crypto live - Price | Crypto live - Chance | Crypto live - Candles | Politics - Midterms |
|---|---|---|---|
| <img src="screenshots/crypto_price.gif" width="200"/> | <img src="screenshots/crypto_chance.gif" width="200"/> | <img src="screenshots/crypto_candles.gif" width="200"/> | <img src="screenshots/politics_midterm_election.gif" width="200"/> |

| World Cup hub navigation | World Cup Map - SceneKit globe |
|---|---|
| <img src="screenshots/home_world_cup.gif" width="200"/> | <img src="screenshots/home_worldcup_map.gif" width="200"/> |

---

## Features

### Shell & navigation
- **Navigation** - three primary tabs (Home, Breaking, Portfolio) with Search set apart as a
  standalone `Tab(role: .search)` on the trailing edge, plus a slide-in drawer. Each tab owns its
  own `NavigationStack`, so navigation depth is tracked independently.
- **Markets feed** - an "All" default feed, a dynamic category rail (curated categories like
  Crypto/Esports/Politics resolved live from Gamma's `top-navbar` tag), sort/status filters, a
  hide-sports toggle, and infinite scroll. Multi-outcome cards preview an event's two likeliest
  options, ranked by probability.
- **Search** - debounced full-text market search.
- **Light/Dark theme** - app-wide toggle from the drawer, persisted locally, independent of
  system appearance.
- **Shimmering skeletons** - every loading state is a shaped skeleton of the content that's
  coming, not a spinner. Numbers that change in place roll digit-by-digit (`RollingNumber`).

### Market detail & order book
- **Event & market detail** - multi-series price chart with selectable timeframes, a "% chance"
  header, grouped market sections (moneyline / spreads / totals), a rules expander, and a sticky
  header on scroll.
- **Sticky trade bar** - Yes/No buy buttons pinned to the bottom of market detail and the crypto
  live screen, so the price you're acting on stays reachable no matter how far you've scrolled.
- **Live order book** - expandable depth ladder streamed over WebSocket with transparent
  reconnect/back-off, plus spread and cumulative-size depth bars.
- **Social strip** - comments (in a swipe-to-dismiss Discuss sheet), top holders, and recent
  activity per event.

### Category hubs
- **Sports hub** - the league catalogue comes from the server (both Gamma endpoints, merged and
  ranked into sports → leagues), not a hardcoded list: a chip row of sports with something open
  to trade, a **More** chip opening the full taxonomy sheet, and Live/Futures modes that all
  select in place. The Live feed is paged five games at a time and sectioned by date - *Live now*
  / *Starting soon* / *Today* / *Tomorrow* / dated bands - with live clocks, live scores, real
  game volume, and team records on the cards. League detail screens carry a standings sheet, and
  teams and fighters get their own profile screen (record header, upcoming match, match history).
  An **Odds Format** menu renders prices as cents, American, decimal, fractional, percentage,
  Indonesian, Hong Kong, or Malaysian.
- **World Cup hub** - Games schedule, Props (awards / player H2H / group futures), a Bracket
  carousel (Groups → knockout rounds), and a Map tab with a rotating, draggable **SceneKit globe**
  of nation odds.
- **Crypto hub** - classifies markets into Up/Down, Above/Below, Price Range, and Hit Price, with
  sort/period/timeframe filters and search. Up/Down cards open a **live window screen**: a
  server-clock countdown driven by the market's real cadence, price-to-beat delta,
  Price/Chance/Candles chart with a dynamic range and pinch-to-zoom, live quick-bet buttons, an
  order-book depth section, a recent-trades ticker, and Comments / Top Holders / Positions /
  Activity below. When a window closes you advance to the next one in place.
- **Esports hub** - live matches with a stream hero (Twitch / YouTube embeds behind a live-status
  probe with YouTube fallback), match cards, a live trade ticker, and a leaderboard, with scores
  pushed over the sports WebSocket and the hub keyset-paged rather than downloading the whole tag.
  A match opens the same purpose-built detail screen - scoreboard, map sections, Livestream tab -
  from whichever feed it was tapped in.
- **Politics hub (2026 Midterms)** - a countdown hero, headline Senate/House control cards with a
  seat pictogram and party-control summary, a **US state map** coloured by each race's lean
  (geometry parsed from SVG paths, no map SDK), carousels for referendums and the biggest races,
  and a searchable, chamber-tabbed list of every race.
- **Breaking** - a dated hero banner, category sub-pills, and a numbered list of the biggest 24h
  movers, each opening a bespoke movers-detail chart.

### Live data & portfolio
- **Live sports stats** - score hero, minute timeline, stats, pitch, lineups, and commentary,
  streamed from the public sports feed.
- **Portfolio (watch-only)** - track any wallet's open/closed positions, activity feed, and the
  trader leaderboard. No keys, no custody.

### Trading (simulated)
- **Mock trade sheet** - amount entry on a custom `DSNumberPad` numeric keyboard with tactile 3D
  "key" buttons, whole dollars first with a decimal key, and a live "to win" payout. Confirming
  plays a success animation and shows a **receipt summary** - amount invested, contracts/shares,
  potential payout. **Simulated only** - sends nothing, stores nothing - until real trading lands.
- **Geoblock gate** - the trade sheet resolves Polymarket's public geoblock status on launch and
  refuses to open in blocked regions, with separate wording for close-only regions. Enforced
  inside the sheet, so every one of its entry points is covered.

---

## Tech Stack

| Layer | Choice |
|---|---|
| **Language** | Swift 5.9 |
| **UI** | SwiftUI, Swift Charts, SceneKit (3D globe) |
| **Concurrency** | Swift Concurrency - `async/await`, actors, `AsyncStream` / `AsyncThrowingStream` |
| **State** | Observation (`@Observable`), MVVM view models |
| **Networking** | `URLSession` for REST **and** WebSockets (order book + sports feeds) |
| **Persistence / security** | Keychain (session token), `UserDefaults` (watched wallet, theme) |
| **Modularization** | Swift Package Manager (one umbrella package - 18 library modules, 36 targets incl. tests) |
| **Logging** | `os.Logger` |
| **Lint** | SwiftLint 0.63.2, pinned in CI ([`.swiftlint.yml`](.swiftlint.yml)) |
| **Backend** | Polymarket public APIs - **Gamma** (markets/events/tags/comments/sports catalogue), **Data** (positions/holders/trades/leaderboard/geoblock), **CLOB** (order book, price history, Chainlink candles, server time), and the sports/market WebSocket channels |

---

## Architecture

**Clean Architecture (Domain / Data / Presentation) + MVVM**, following SOLID:

- **Domain** - pure entities, use cases, and repository *ports* (protocols). No I/O, no UI,
  trivially testable.
- **Data** - DTOs, tolerant decoders for Polymarket's quirky wire shapes, mappers, and the
  concrete repository/socket implementations.
- **Presentation** - `@Observable` view models and SwiftUI views. Dependencies are injected via
  protocols and environment-provided factories, so views never import the Data layer.

The app is a **thin composition root**: [`AppContainer`](NextOutcome/NextOutcome/App/AppContainer.swift)
wires concrete implementations once and vends ready-made view models and factories to
[`RootView`](NextOutcome/NextOutcome/App/RootView.swift). Each feature is a **vertical slice**
with its own `*Domain` / `*Data` / `*Presentation` modules.

```mermaid
graph TD
    UI["Presentation<br/>(SwiftUI Views / @Observable ViewModels)"] --> Domain["Domain<br/>(Use Cases / Entities / Repository protocols)"]
    Domain --> Data["Data<br/>(DTOs, mappers, repository implementations)"]
    Data --> Remote["Remote<br/>(Gamma / Data / CLOB REST + WebSocket)"]
    Data --> Local["Local<br/>(in-memory caches, Keychain, UserDefaults)"]
```

**Key decisions**
- Presentation depends only on Domain's Use Case protocols - it never imports a feature's `Data`
  module; the App composition root wires the concrete repository in.
- `SharedDomain` holds cross-feature primitives (`LoadState`, `Page`) so features don't import
  each other directly.
- Wallet **signing** stays quarantined: the app links the Trading modules for the mock sheet and
  the geoblock gate, but the signer itself is an `UnavailableWalletSigner` stub until a vetted
  secp256k1/EIP-712 implementation passes security review - see
  [`docs/phase-4-wallet-proxy-design.md`](docs/phase-4-wallet-proxy-design.md).
- View bodies are split so `@Observable` tracking stays narrow. On the crypto live screen, for
  example, the header, bet buttons and trades ticker are separate `View` structs - otherwise a
  once-a-second countdown tick would invalidate the candle chart too.

---

## Folder Structure

```
NextOutcome/
├── README.md
├── .swiftlint.yml                        # lint config (test overrides live under Packages/Tests)
├── NextOutcome/                          # Xcode project root
│   ├── NextOutcome.xcodeproj
│   ├── NextOutcome/                      # App target (thin shell)
│   │   └── App/                          # AppContainer, RootView
│   ├── NextOutcomeUITests/               # XCUITest suite (Home, MarketDetail, Esports, …)
│   └── Packages/                         # Swift Package (one umbrella, 18 library modules)
│       ├── Package.swift
│       ├── Sources/
│       │   ├── DesignSystem/             # tokens, components, shell chrome, DSNumberPad, Skeleton
│       │   ├── Networking/               # APIClient (actor), Endpoint, sockets, decoding
│       │   ├── SharedDomain/             # LoadState, Page - cross-feature primitives
│       │   └── Modules/                  # feature slices, each Domain / Data / Presentation
│       │       ├── Market/               # feed, detail, search + Sports/WorldCup/Crypto/
│       │       │                         #   Esports/Politics/Breaking hubs
│       │       ├── Orderbook/            # live book, price/candle charts, live crypto window
│       │       ├── Portfolio/            # watch-only positions, activity, leaderboard
│       │       ├── LiveStats/            # live sports stats
│       │       └── Trading/              # geoblock gate, simulated submitter, signer stub
│       └── Tests/                        # one dir per test target, flat (18 targets)
├── .github/workflows/                    # CI - package tests + SwiftLint + app-target build
├── docs/                                 # API studies, design specs, UI test plan
└── .mobile-agents/                       # engineering standards & agent toolkit
```

---

## Getting Started

Clone it, open it, run it - no API keys, no signup.

### Requirements

- **macOS** with **Xcode 15+** (Swift 5.9 toolchain)
- **iOS 18+**, iPhone or iPad - every target is on the 18.0 deployment target
- A physical device or the iOS Simulator
- Internet access (the app reads Polymarket's public APIs)

### Installation

```bash
git clone https://github.com/sokpichdev/NextOutcome.git
cd NextOutcome
open NextOutcome/NextOutcome.xcodeproj
```

Xcode resolves the local Swift package under `NextOutcome/Packages` automatically on first open.

### Configuration

- **No secrets or API keys are required** for the read-only experience - all Polymarket endpoints used are public.
- **Portfolio** is watch-only: paste any `0x…` wallet address to track it. Nothing is signed or funded.
- **Trading** is simulated. Real trading will require a backend proxy (`TradingProxyConfig`) and a vetted on-device signer; both are stubbed today.

### Build & Run

**In Xcode:** select the `NextOutcome` scheme and an iOS 18+ simulator, then press **⌘R**.

**Build the packages from the command line:**

```bash
cd NextOutcome/Packages
swift build
```

---

## Testing

```bash
cd NextOutcome/Packages
swift test
```

**818 tests, ~2 seconds, all hermetic** - no simulator, no network. Each feature slice (Markets,
Orderbook, Portfolio, LiveStats, Trading) has its own `*DomainTests`, `*DataTests`, and
`*PresentationTests` targets: Domain tests exercise Use Cases against stub repositories, Data
tests exercise DTO decoding against fixture JSON, Presentation tests drive view models.
`Networking`, `DesignSystem`, and `SharedDomain` have their own test targets too - 18 in all.

**Continuous integration.** [`.github/workflows/tests.yml`](.github/workflows/tests.yml) runs on
every push and PR to `main`, in three jobs:

| Job | What it catches |
|---|---|
| `swift test` | Logic and decoding regressions across all 18 test targets |
| `swiftlint` | Style/complexity violations, pinned to SwiftLint 0.63.2 - fails on **error** severity only; warnings land as inline PR annotations |
| `xcodebuild` (compile only) | Breaks in `App/`/`AppContainer`, which the package suite can't see |

**UI tests.** An XCUITest suite lives in
[`NextOutcome/NextOutcomeUITests/`](NextOutcome/NextOutcomeUITests) (Home feed, market detail,
Esports, category rail, drawer, World Cup, tab navigation), run locally via
`scripts/run-tests.sh`. It's **deliberately excluded from CI** - it drives a simulator against
live Polymarket APIs and asserts on transient market data, so it would fail when the market moves
rather than when the code breaks. A formal coverage target hasn't been set yet (see
[Roadmap](#roadmap)).

---

## Privacy & Permissions

- **No permissions requested** - no camera, location, or notification usage descriptions in `Info.plist` today.
- **No analytics or crash reporting** - zero third-party dependencies in `Package.swift`; the only instrumentation is `os.Logger`.
- **Data entered:** a wallet address (`0x…`) to watch a portfolio, stored locally in `UserDefaults` and used only to query Polymarket's own public Data API directly. Nothing is sent to a first-party backend today.

---

## Project Status

🚧 **In active development.** Browsing (with a dynamic, tag-resolved category rail), live order
books, the Sports hub with its server-driven league catalogue, the Crypto hub with a live window
screen, the Esports and Politics hubs, live sports/World Cup, the Breaking movers feed, the
watch-only portfolio, and app-wide light/dark theming are all implemented. Trading is
**mock/simulated** pending wallet + proxy integration and funding - though the geoblock gate that
fronts it is real and enforced.

---

## Roadmap

- [x] Markets feed, search, event/market detail with live charts
- [x] Live order book over WebSocket with reconnect/back-off
- [x] Live sports stats and the World Cup hub (schedule, props, bracket, 3D globe map)
- [x] Watch-only portfolio (positions, activity, leaderboard) by wallet address
- [x] Dynamic category rail - curated categories resolved live from Gamma tags
- [x] Crypto hub - Up/Down, Above/Below, Price Range, Hit Price, plus a live window screen with candles, order book, holders and activity
- [x] Esports hub - live matches, stream hero, trade ticker, leaderboard, keyset paging
- [x] Politics hub - Midterms countdown, chamber control, US race map, full race list
- [x] Breaking - 24h movers feed with a bespoke detail chart
- [x] Sports hub taxonomy - server-driven sport/league catalogue, date-sectioned live feed, team profiles, eight odds formats
- [x] Trade sheet - number pad, confirmation, and receipt summary (simulated)
- [x] App-wide light/dark theme toggle, persisted locally
- [x] Shimmering skeleton loading states and rolling number transitions
- [x] 1024pt app icon (light/dark/tinted variants)
- [x] Continuous integration - package tests + SwiftLint + app-target build on every push/PR
- [x] XCUITest UI suite covering core app flows
- [x] Geoblock gate on the trade sheet - blocked and close-only regions can't open a position
- [ ] Real on-chain trading - vetted EIP-712 signer + backend proxy (currently simulated)
- [ ] Wallet connect & session auth
- [ ] Portfolio funding and real positions on market detail
- [ ] Push notifications for price moves and market resolutions
- [ ] Replace the placeholder screenshots above, plus a demo video and App Store assets
- [ ] Burn down the SwiftLint warning backlog, then turn on `--strict`
- [ ] Expanded test coverage across feature slices and a formal coverage target

---

## Contributing

This is currently a solo project, but contributions are welcome:

1. Fork and create a feature branch (`git checkout -b feat/thing`)
2. Keep changes scoped to a feature's vertical slice (`Domain`/`Data`/`Presentation`) per the [Architecture](#architecture) rules
3. Make sure `swift test` passes from `NextOutcome/Packages`, and `swiftlint lint` reports no new errors
4. Open a PR against `main`

---

## Security

The app is read-only and non-custodial today - no wallet keys, no funds at risk. If you find a security issue, please open a GitHub issue or reach out to the author directly rather than disclosing it publicly.

---

## License

To be determined. <!-- TODO: choose a license (e.g. MIT) and add a LICENSE file. -->

---

## Acknowledgments

- [Polymarket](https://polymarket.com) - the public Gamma, Data, and CLOB APIs this app is built entirely on.

---

## Author

**Sok Pich** - [@sokpichdev](https://github.com/sokpichdev) · [sokpich.dev/nextoutcome](https://www.sokpich.dev/nextoutcome)

If you're building something similar or want to talk iOS/prediction markets, open an issue or reach out on GitHub.
