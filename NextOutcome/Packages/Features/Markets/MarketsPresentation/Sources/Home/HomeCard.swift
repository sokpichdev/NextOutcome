import SwiftUI
import MarketsDomain
import DesignSystem

/// Renders the correct Home card variant for an event.
public struct HomeCard: View {
    private let event: Event
    private let kind: HomeCardKind

    public init(event: Event, kindOverride: HomeCardKind? = nil) {
        self.event = event
        self.kind = kindOverride ?? HomeCardKind.classify(event)
    }

    public var body: some View {
        switch kind {
        case .liveUpDown:  LiveUpDownCard(event: event)
        case .news:        NewsCard(event: event)
        case .multiOutcome: MultiOutcomeCard(event: event)
        case .hero:        HeroPromoCard(event: event)
        case .standard:    EventCard(event: event)
        }
    }
}
