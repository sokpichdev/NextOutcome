import SwiftUI
import MarketsDomain
import DesignSystem

/// Single-binary news event: article image + headline + Yes/No.
public struct NewsCard: View {
    /// The event to render.
    private let event: Event
    /// Creates the card.
    /// - Parameter event: The event to display.
    public init(event: Event) { self.event = event }

    public var body: some View {
        NavigationLink(value: event) {
            DSCard {
                HStack(alignment: .top, spacing: DSLayout.spacing) {
                    CardIcon(url: event.imageURL)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title).font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary).lineLimit(3)
                        if let market = event.markets.first, let yes = market.yesOutcome {
                            HStack {
                                OutcomePill(.yes, value: "Yes \(MarketFormatting.percent(yes.price))")
                                OutcomePill(.no, value: "No")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
