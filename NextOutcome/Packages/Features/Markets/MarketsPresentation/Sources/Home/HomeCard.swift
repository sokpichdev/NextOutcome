import SwiftUI
import MarketsDomain
import DesignSystem

/// Renders the correct Home card variant for an event.
/// Renders the correct Home card variant for an event.
public struct HomeCard: View {
    /// The event to render.
    private let event: Event
    /// The chosen card variant (from `kindOverride` or classification).
    private let kind: HomeCardKind

    /// Creates the card.
    /// - Parameters:
    ///   - event: The event to display.
    ///   - kindOverride: Force a specific variant (e.g. `.hero` for a feed slot); otherwise
    ///     the kind is derived from the event via `HomeCardKind.classify`.
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

#if DEBUG
private func _sampleEvent(title: String, markets: [Market], tags: [String], image: Bool = false) -> Event {
    Event(id: title, title: title, slug: title, markets: markets, volume: 4_000_000_000,
          imageURL: image ? URL(string: "https://example.com/x.png") : nil,
          tags: tags.map { Tag(id: $0, label: $0, slug: $0.lowercased()) })
}
private func _mkt(_ q: String, _ outs: [(String, Double)]) -> Market {
    Market(id: q, question: q, slug: q,
           outcomes: outs.map { Outcome(id: $0.0, title: $0.0, price: Decimal($0.1)) },
           volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
}

#Preview("Home cards") {
    ScrollView {
        VStack(spacing: 12) {
            HomeCard(event: _sampleEvent(title: "World Cup Winner",
                markets: [_mkt("France", [("Yes", 0.33), ("No", 0.67)]),
                          _mkt("Argentina", [("Yes", 0.19), ("No", 0.81)])], tags: ["Soccer"]))
            HomeCard(event: _sampleEvent(title: "BTC Up or Down 5m",
                markets: [_mkt("BTC", [("Up", 0.51), ("Down", 0.49)])], tags: ["Crypto"]))
            HomeCard(event: _sampleEvent(title: "Claude Fable 5 restored?",
                markets: [_mkt("Q", [("Yes", 0.98), ("No", 0.02)])], tags: ["Breaking"], image: true))
        }.padding()
    }
    .background(DSColor.background)
}
#endif
