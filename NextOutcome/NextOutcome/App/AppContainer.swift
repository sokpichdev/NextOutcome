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

@MainActor
final class AppContainer {
    private let repository: MarketRepository

    nonisolated init() {
        let client = APIClient()
        self.repository = GammaMarketRepository(client: client)
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
}
