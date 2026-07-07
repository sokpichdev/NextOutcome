<!-- App Logo -->
<p align="center">
  <!-- TODO: add app logo — replace the placeholder below with docs/assets/logo.png -->
  <img src="docs/assets/logo.png" alt="NextOutcome logo" width="120" onerror="this.style.display='none'"/>
</p>

<h1 align="center">NextOutcome</h1>

<!-- Short Description -->
<p align="center">
  A native iOS prediction-market app for browsing <a href="https://polymarket.com">Polymarket</a> events,
  live order books, and sports markets — with real-time price charts, a World Cup hub, and a
  watch-only portfolio. Read-only today; on-chain trading is on the roadmap.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-blue"/>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange"/>
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-green"/>
  <img alt="Status" src="https://img.shields.io/badge/status-in%20development-yellow"/>
</p>

---

## App Screenshots

> Captured from the current dev build in the simulator — not a final/curated set.

| | | |
|---|---|---|
| <img src="screenshots/home_trending.png" width="200"/><br/>Home feed — Trending | <img src="screenshots/home_politics.png" width="200"/><br/>Home feed — Politics | <img src="screenshots/home_breaking.png" width="200"/><br/>Home feed — Breaking |
| <img src="screenshots/home_trending_worldcup_winners.png" width="200"/><br/>Trending — World Cup winner odds | <img src="screenshots/worldcup_franch_winner.png" width="200"/><br/>France-to-win market | <img src="screenshots/home_sports_live.png" width="200"/><br/>Sports hub — Live feed |
| <img src="screenshots/home_sports_futures.png" width="200"/><br/>Sports hub — Futures | <img src="screenshots/home_sports_mlb.png" width="200"/><br/>Sports hub — MLB league | <img src="screenshots/home_sports_wimbledon.png" width="200"/><br/>Sports hub — Wimbledon league |
| <img src="screenshots/home_sports_worldcup.png" width="200"/><br/>Sports hub — World Cup league | <img src="screenshots/home_worldcup_game.png" width="200"/><br/>World Cup hub — Games schedule | <img src="screenshots/home_worldcup_bracket.png" width="200"/><br/>World Cup hub — Bracket |
| <img src="screenshots/home_worldcup_props.png" width="200"/><br/>World Cup hub — Props | <img src="screenshots/home_worldcup_map.png" width="200"/><br/>World Cup hub — Map (SceneKit globe) | |

---

## Features

- **Markets feed** — trending, category rail (Politics, Sports, Breaking, World Cup), sort/status filters, and hide-sports toggle, with infinite scroll.
- **Search** — debounced full-text market search.
- **Event & market detail** — multi-series price chart with selectable timeframes, a "% chance" header, grouped market sections (moneyline / spreads / totals), rules expander, and a sticky header on scroll.
- **Live order book** — expandable depth ladder streamed over WebSocket with transparent reconnect/back-off, plus spread and cumulative-size depth bars.
- **BTC 5-minute live** — candle/line chart, a server-clock–anchored countdown, live Up/Down quick-bet prices, and a recent-trades ticker.
- **Live sports stats** — score hero, minute timeline, stats, pitch, lineups, and commentary, streamed from the public sports feed.
- **World Cup hub** — Games schedule, Props (awards / player H2H / group futures), a Bracket carousel (Groups → knockout rounds), and a Map tab with a rotating, draggable **SceneKit globe** of nation odds.
- **Portfolio (watch-only)** — track any wallet's open/closed positions, activity feed, and the trader leaderboard. No keys, no custody.
- **Social strip** — comments, top holders, and recent activity per event.
- **Mock trade sheet** — keypad amount entry with a live "to win" payout. **Simulated only** — sends nothing, stores nothing — until real trading lands.

---

## Demo GIF / Video

| World Cup hub navigation | World Cup Map — SceneKit globe |
|---|---|
| <img src="screenshots/home_world_cup.gif" width="220"/> | <img src="screenshots/home_worldcup_map.gif" width="220"/> |

---

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI, Swift Charts, SceneKit (3D globe)
- **Concurrency:** Swift Concurrency — `async/await`, actors, `AsyncStream` / `AsyncThrowingStream`
- **State:** Observation (`@Observable`), MVVM view models
- **Networking:** `URLSession` for REST **and** WebSockets (order book + sports feeds)
- **Persistence / security:** Keychain (session token), `UserDefaults` (watched wallet)
- **Modularization:** Swift Package Manager (one umbrella package, ~18 targets)
- **Logging:** `os.Logger`
- **Backend:** Polymarket public APIs — **Gamma** (markets/events/tags/comments), **Data** (positions/holders/trades/leaderboard/geoblock), **CLOB** (order book, price history, server time), and the sports/market WebSocket channels.

---

## Architecture

**Clean Architecture (Domain / Data / Presentation) + MVVM**, following SOLID:

- **Domain** — pure entities, use cases, and repository *ports* (protocols). No I/O, no UI, trivially testable.
- **Data** — DTOs, tolerant decoders for Polymarket's quirky wire shapes, mappers, and the concrete repository/socket implementations.
- **Presentation** — `@Observable` view models and SwiftUI views. Dependencies are injected via protocols and environment-provided factories, so views never import the Data layer.

The app is a **thin composition root**: [`AppContainer`](NextOutcome/NextOutcome/App/AppContainer.swift) wires concrete implementations once and vends ready-made view models and factories to [`RootView`](NextOutcome/NextOutcome/App/RootView.swift). Each feature is a **vertical slice** with its own `*Domain` / `*Data` / `*Presentation` modules. The Trading modules are deliberately quarantined — the read-only app never links them.

---

## Folder Structure

```
NextOutcome/
├── README.md
├── NextOutcome/                         # Xcode project root
│   ├── NextOutcome.xcodeproj
│   ├── NextOutcome/                      # App target (thin shell)
│   │   └── App/                          # AppContainer, RootView
│   └── Packages/                         # Swift Package (one umbrella)
│       ├── Package.swift
│       ├── Core/
│       │   ├── DesignSystem/             # tokens, components, shell chrome
│       │   └── Networking/               # APIClient (actor), Endpoint, sockets, decoding
│       ├── SharedDomain/                 # LoadState, Page — cross-feature primitives
│       └── Features/                     # vertical slices: Domain / Data / Presentation
│           ├── Markets/                  # feed, detail, search, World Cup hub
│           ├── Orderbook/                # live book, price/candle charts, BTC live
│           ├── Portfolio/                # watch-only positions, activity, leaderboard
│           ├── LiveStats/               # live sports stats
│           └── Trading/                  # order signing + proxy (quarantined)
└── .mobile-agents/                       # engineering standards & agent toolkit
```

---

## Getting Started

### Requirements

- **macOS** with **Xcode 15+** (Swift 5.9 toolchain)
- **iOS 17+** target (the app uses `@Observable`, `ContentUnavailableView`, and modern `.task` APIs)
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

- **No secrets or API keys are required** for the read-only experience — all Polymarket endpoints used are public.
- **Portfolio** is watch-only: paste any `0x…` wallet address to track it. Nothing is signed or funded.
- **Trading** is simulated. Real trading will require a backend proxy (`TradingProxyConfig`) and a vetted on-device signer; both are stubbed today.

### Build & Run

**In Xcode:** select the `NextOutcome` scheme and an iOS 17+ simulator, then press **⌘R**.

**Build the packages from the command line:**

```bash
cd NextOutcome/Packages
swift build
```

---

## Project Status

🚧 **In active development.** Browsing, live order books, live sports/World Cup, and the watch-only portfolio are implemented. Trading is **mock/simulated** pending wallet + proxy integration and funding.

---

## Roadmap

- [ ] Real on-chain trading — vetted EIP-712 signer + backend proxy (currently simulated)
- [ ] Wallet connect & session auth
- [ ] Portfolio funding and real positions on market detail
- [ ] Push notifications for price moves and market resolutions
- [ ] Screenshots, demo GIF/video, and App Store assets
- [ ] Expanded test coverage across feature slices

---

## License

To be determined. <!-- TODO: choose a license (e.g. MIT) and add a LICENSE file. -->

---

## Author

**Sok Pich** — [@sokpichdev](https://github.com/sokpichdev)
