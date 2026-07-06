//
//  AppContainer.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import MarketsData
import MarketsDomain
import MarketsPresentation
import OrderbookData
import OrderbookDomain
import OrderbookPresentation
import LiveStatsData
import LiveStatsDomain
import PortfolioData
import PortfolioDomain
import PortfolioPresentation
import TradingDomain

/// The app's composition root — a single object that builds and holds the shared
/// dependencies (repositories, streams) once, then hands out ready-made view models
/// and factories to the UI.
///
/// This is the one place where concrete Data-layer types (like `GammaMarketRepository`
/// or `MarketSocket`) are chosen. Views and view models only ever see protocols and
/// use cases, so they stay easy to test and don't need to know how the network is wired.
/// Marked `@MainActor` because it vends UI-facing view models that must live on the main
/// thread.
@MainActor
final class AppContainer {
    /// Fetches markets, events, tags, holders, comments, etc. from the Gamma/Data layer.
    private let repository: MarketRepository
    /// Fetches order books and price history from the CLOB (central limit order book) layer.
    private let orderbookRepository: OrderbookRepository
    /// Live price/quote stream used by the order book and live market screens.
    private let marketStream: MarketStreaming
    /// Fetches the user's positions, activity, and leaderboard data.
    private let portfolioRepository: PortfolioRepository

    /// Creates the container and eagerly builds the shared low-level dependencies.
    ///
    /// Marked `nonisolated` even though the type is `@MainActor`: the app needs to build
    /// the container during launch without first hopping onto the main actor. The work
    /// here is cheap object construction with no main-thread requirement, so it's safe.
    nonisolated init() {
        // A single shared HTTP client is reused by every repository below so they share
        // one connection pool, retry policy, and logger.
        let client = APIClient()
        self.repository = GammaMarketRepository(client: client)
        self.orderbookRepository = ClobOrderbookRepository(client: client)
        self.marketStream = MarketSocket()
        self.portfolioRepository = DataPortfolioRepository(client: client)
    }

    /// Builds the view model for the main markets/events list screen.
    ///
    /// Each `makeXxxViewModel` method injects the use cases a screen needs, keeping the
    /// view model free of any knowledge about how data is fetched.
    /// - Returns: A view model wired to fetch events and their filter tags.
    func makeEventListViewModel() -> EventListViewModel {
        EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repository),
            fetchTags: FetchTagsUseCase(repository: repository),
            searchEvents: SearchEventsUseCase(repository: repository)
        )
    }

    /// Builds the view model for the Breaking movers feed (biggest 24h movers).
    /// - Returns: A view model wired to fetch the ranked movers.
    func makeBreakingViewModel() -> BreakingViewModel {
        BreakingViewModel(fetchMovers: FetchMoversUseCase(repository: repository))
    }

    /// Builds the view model for the Politics hub (2026 Midterms).
    /// - Returns: A view model wired to fetch the midterms + referendums tags.
    func makePoliticsHubViewModel() -> PoliticsHubViewModel {
        PoliticsHubViewModel(fetchAllEvents: FetchAllEventsUseCase(repository: repository))
    }

    /// Builds the view model for the Sports hub (Live/Futures modes, league chips).
    /// - Returns: A view model wired to fetch events and the tag catalogue.
    func makeSportsHubViewModel() -> SportsHubViewModel {
        SportsHubViewModel(
            fetchEvents: FetchEventsUseCase(repository: repository),
            fetchAllEvents: FetchAllEventsUseCase(repository: repository)
        )
    }

    /// The use case shared by Sports league detail screens (built lazily per league, since
    /// each screen owns its own view model).
    func makeFetchEventsUseCase() -> FetchEventsUseCase {
        FetchEventsUseCase(repository: repository)
    }

    /// A factory for the bespoke movers detail screen. It builds the detail view model when a
    /// mover row is tapped, wiring in the parent-event fetch and the social-strip factory (for
    /// Comments/Top Holders/Positions/Activity) — built synchronously in `load()` rather than
    /// read from the view's environment, so the sheet always has real content the moment it's
    /// presented.
    func makeMoversDetailFactory() -> MoversDetailViewModelFactory {
        let socialStripFactory = makeSocialStripFactory()
        return MoversDetailViewModelFactory { [repository] mover in
            let fetchEvent = FetchEventUseCase(repository: repository)
            return MoversDetailViewModel(
                mover: mover,
                fetchEvent: { try await fetchEvent.execute(slug: $0) },
                makeSocialStrip: { eventID, conditionId, markets in
                    socialStripFactory(eventID: eventID, conditionId: conditionId, markets: markets)
                }
            )
        }
    }

    /// Builds the view model for the World Cup hub screen (bracket, map, results, teams).
    /// - Returns: A view model wired with every use case the hub's sub-tabs need.
    func makeWorldCupHubViewModel() -> WorldCupHubViewModel {
        WorldCupHubViewModel(
            fetchSeriesEvents: FetchSeriesEventsUseCase(repository: repository),
            fetchGameResults: FetchGameResultsUseCase(repository: repository),
            fetchEvents: FetchEventsUseCase(repository: repository),
            fetchEvent: FetchEventUseCase(repository: repository),
            fetchTeams: FetchTeamsUseCase(repository: repository),
            fetchCompleted: FetchCompletedEventsUseCase(repository: repository)
        )
    }

    /// Builds the view model backing the market search screen.
    /// - Returns: A view model that runs text searches against the market repository.
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchMarkets: SearchMarketsUseCase(repository: repository))
    }

    /// Builds the view model for the portfolio screen (open and closed positions).
    /// - Returns: A view model that loads the user's current and historical positions.
    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(
            fetchPortfolio: FetchPortfolioUseCase(repository: portfolioRepository),
            fetchClosed: FetchClosedPositionsUseCase(repository: portfolioRepository)
        )
    }

    /// Builds the view model for the leaderboard screen (top traders by profit/volume).
    /// - Returns: A view model that loads leaderboard rankings.
    func makeLeaderboardViewModel() -> LeaderboardViewModel {
        LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: portfolioRepository))
    }

    /// A factory function used by screens that show market detail.
    /// It delays creating the live market view model until the screen knows the asset ID.
    func makeMarketLiveFactory() -> MarketLiveViewModelFactory {
        MarketLiveViewModelFactory { [orderbookRepository, marketStream] assetID in
            MarketLiveViewModel(
                assetID: assetID,
                observeBook: ObserveOrderBookUseCase(repository: orderbookRepository, stream: marketStream),
                fetchHistory: FetchPriceHistoryUseCase(repository: orderbookRepository)
            )
        }
    }

    /// A factory for the order book section inside market detail.
    /// The screen can build this view model later when it knows the asset ID.
    func makeOrderbookFactory() -> OrderbookViewModelFactory {
        OrderbookViewModelFactory { [orderbookRepository, marketStream] assetID in
            OrderbookViewModel(assetID: assetID, repository: orderbookRepository, stream: marketStream)
        }
    }

    /// Factory for the Market Detail top-holders section.
    func makeMarketHoldersFactory() -> MarketHoldersViewModelFactory {
        MarketHoldersViewModelFactory { [repository] conditionId in
            HoldersViewModel(conditionId: conditionId, fetchHolders: FetchHoldersUseCase(repository: repository))
        }
    }

    /// A factory for the event detail social strip (comments, holders, trades, etc.).
    /// It creates the social strip view model when the screen knows the event details.
    func makeSocialStripFactory() -> SocialStripViewModelFactory {
        SocialStripViewModelFactory { [repository] eventID, conditionId, markets in
            SocialStripViewModel(
                eventID: eventID,
                conditionId: conditionId,
                markets: markets,
                fetchComments: FetchCommentsUseCase(repository: repository),
                fetchHolders: FetchHoldersUseCase(repository: repository),
                fetchActivity: FetchActivityTradesUseCase(repository: repository),
                fetchCommenterPositions: FetchCommenterPositionsUseCase(repository: repository)
            )
        }
    }

    /// Factory injected into the environment so the home feed's BTC card can open the
    /// BTC 5-minute live screen (candles, server-clock countdown, quick-bet).
    func makeBTCLiveFactory() -> BTCLiveViewModelFactory {
        BTCLiveViewModelFactory { [orderbookRepository, marketStream] context, onQuickBet in
            BTCLiveViewModel(
                assetID: context.assetID,
                eventID: context.eventID,
                windowEnd: context.windowEnd,
                fetchHistory: FetchPriceHistoryUseCase(repository: orderbookRepository),
                fetchServerTime: FetchServerTimeUseCase(repository: orderbookRepository),
                fetchRecentTrades: FetchRecentTradesUseCase(repository: orderbookRepository),
                observeBook: ObserveOrderBookUseCase(repository: orderbookRepository, stream: marketStream),
                onQuickBet: onQuickBet
            )
        }
    }

    /// The mock trade sheet's order-sending dependency. Simulated only — sends nothing,
    /// persists nothing. Task D swaps this for a real submitter behind `TradeSubmitting`
    /// with zero UI changes.
    func makeTradeSubmitter() -> TradeSubmitting {
        SimulatedTradeSubmitter()
    }

    /// Live sports-stats streamer injected into the environment so the Live sub-tab can
    /// subscribe without importing the Data layer.
    func makeSportsStreamer() -> any SportsStateStreaming {
        SportsSocket()
    }

    /// Provider injected into the environment so feature screens can build price-history
    /// charts without importing the Data layer.
    func makePriceHistoryProvider() -> PriceHistoryProvider {
        let useCase = FetchPriceHistoryUseCase(repository: orderbookRepository)
        return PriceHistoryProvider { assetID, interval in
            try await useCase.execute(assetID: assetID, interval: interval)
        }
    }
}
