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

    /// Factory for the Market Detail top-holders section.
    func makeMarketHoldersFactory() -> MarketHoldersViewModelFactory {
        MarketHoldersViewModelFactory { [repository] conditionId in
            HoldersViewModel(conditionId: conditionId, fetchHolders: FetchHoldersUseCase(repository: repository))
        }
    }
}
