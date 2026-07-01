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

@MainActor
final class AppContainer {
    private let repository: MarketRepository
    private let orderbookRepository: OrderbookRepository
    private let marketStream: MarketStreaming

    nonisolated init() {
        let client = APIClient()
        self.repository = GammaMarketRepository(client: client)
        self.orderbookRepository = ClobOrderbookRepository(client: client)
        self.marketStream = MarketSocket()
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
}
