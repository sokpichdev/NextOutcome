import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation

/// Compact live BTC Up/Down card: circular Up% gauge, Up/Down buttons, decorative +$ chips.
public struct LiveUpDownCard: View {
    private let event: Event
    @Environment(\.marketLiveFactory) private var factory
    @State private var model: LiveUpDownCardViewModel?

    public init(event: Event) { self.event = event }

    private var market: Market? { event.markets.first }
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
                        NavigationLink(value: market) { Text("Up").frame(maxWidth: .infinity) }
                            .buttonStyle(DSBuyYesButtonStyle())
                        NavigationLink(value: market) { Text("Down").frame(maxWidth: .infinity) }
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
                let m = LiveUpDownCardViewModel(upOutcome: up, factory: f)
                model = m
                m.start()
            }
        }
        .onDisappear { model?.stop() }
    }

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
