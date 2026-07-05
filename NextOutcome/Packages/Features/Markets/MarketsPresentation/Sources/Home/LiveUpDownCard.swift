import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation

/// Compact live BTC Up/Down card: circular Up% gauge, Up/Down buttons, decorative +$ chips.
public struct LiveUpDownCard: View {
    /// The event backing the card.
    private let event: Event
    /// Factory (from the environment) for building the live-market view model.
    @Environment(\.marketLiveFactory) private var factory
    /// The live view model, created lazily once a factory and Up outcome are available.
    @State private var model: LiveUpDownCardViewModel?

    /// Creates the card.
    /// - Parameter event: The event to display.
    public init(event: Event) { self.event = event }

    /// The event's first market.
    private var market: Market? { event.markets.first }
    /// The navigation target opened when the card's buttons are tapped.
    private var navigationTarget: MarketNavigationTarget? {
        market.map { MarketNavigationTarget(market: $0, eventID: event.id) }
    }
    /// The "Up" outcome, if the market has one.
    private var upOutcome: Outcome? {
        market?.outcomes.first { $0.title.lowercased() == "up" }
    }

    public var body: some View {
        DSCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: DSLayout.spacing) {
                        CardIcon(url: event.imageURL)
                        Text(event.title).font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                    }
                    HStack {
                        NavigationLink(value: navigationTarget) { Text("Up").frame(maxWidth: .infinity) }
                            .buttonStyle(DSBuyYesButtonStyle())
                        NavigationLink(value: navigationTarget) { Text("Down").frame(maxWidth: .infinity) }
                            .buttonStyle(DSBuyNoButtonStyle())
                    }
                    Label("LIVE · Bitcoin", systemImage: "circle.fill")
                        .font(DSFont.caption).foregroundStyle(DSColor.negative)
                }
                Spacer()
                gauge
            }
        }
        .task {
            if model == nil, let up = upOutcome, let f = factory {
                model = LiveUpDownCardViewModel(upOutcome: up, factory: f)
            }
            model?.start()
        }
        .onDisappear { model?.stop() }
    }

    /// The semicircular Up% gauge, filled to the live (or fallback static) Up fraction.
    @ViewBuilder
    private var gauge: some View {
        let fraction = model?.upFraction ?? upOutcome.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 0.5
        ZStack {
            Circle().trim(from: 0, to: 0.5).rotation(.degrees(180))
                .stroke(DSColor.separator, style: .init(lineWidth: 6, lineCap: .round))
            Circle().trim(from: 0, to: fraction * 0.5).rotation(.degrees(180))
                .stroke(DSColor.positive, style: .init(lineWidth: 6, lineCap: .round))
            Text(model?.upPercentText ?? "—")
                .font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
        }
        .frame(width: 72, height: 72)
    }
}
