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
import PortfolioData
import PortfolioDomain
import PortfolioPresentation

@MainActor
final class AppContainer {
    private let repository: MarketRepository
    private let orderbookRepository: OrderbookRepository
    private let marketStream: MarketStreaming
    private let portfolioRepository: PortfolioRepository

    nonisolated init() {
        let client = APIClient()
        self.repository = GammaMarketRepository(client: client)
        self.orderbookRepository = ClobOrderbookRepository(client: client)
        self.marketStream = MarketSocket()
        self.portfolioRepository = DataPortfolioRepository(client: client)
    }

    func makeEventListViewModel() -> EventListViewModel {
        EventListViewModel(
            fetchEvents: FetchEventsUseCase(repository: repository),
            fetchTags: FetchTagsUseCase(repository: repository)
        )
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchMarkets: SearchMarketsUseCase(repository: repository))
    }

    func makePortfolioViewModel() -> PortfolioViewModel {
        PortfolioViewModel(
            fetchPortfolio: FetchPortfolioUseCase(repository: portfolioRepository),
            fetchClosed: FetchClosedPositionsUseCase(repository: portfolioRepository)
        )
    }

    func makeActivityViewModel() -> ActivityViewModel {
        ActivityViewModel(fetchActivity: FetchActivityUseCase(repository: portfolioRepository))
    }

    func makeLeaderboardViewModel() -> LeaderboardViewModel {
        LeaderboardViewModel(fetchLeaderboard: FetchLeaderboardUseCase(repository: portfolioRepository))
    }

    /// Factory injected into the environment so Market Detail can build its live view model.
    func makeMarketLiveFactory() -> MarketLiveViewModelFactory {
        MarketLiveViewModelFactory { [orderbookRepository, marketStream] assetID in
            MarketLiveViewModel(
                assetID: assetID,
                observeBook: ObserveOrderBookUseCase(repository: orderbookRepository, stream: marketStream),
                fetchHistory: FetchPriceHistoryUseCase(repository: orderbookRepository)
            )
        }
    }

    /// Factory injected into the environment so Market Detail can build its expandable
    /// live order book independently of the chart's view model.
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

    /// Factory for the Event Detail social strip (Comments · Top Holders · Positions · Activity).
    func makeSocialStripFactory() -> SocialStripViewModelFactory {
        SocialStripViewModelFactory { [repository] eventID, conditionId in
            SocialStripViewModel(
                eventID: eventID,
                conditionId: conditionId,
                fetchComments: FetchCommentsUseCase(repository: repository),
                fetchHolders: FetchHoldersUseCase(repository: repository),
                fetchActivity: FetchActivityTradesUseCase(repository: repository)
            )
        }
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
