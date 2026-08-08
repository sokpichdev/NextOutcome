import SwiftUI
import DesignSystem

/// Collapsible "Rules" block: event-level description plus each market's resolution
/// criteria. Collapsed by default, matching the live site's "Show more" pattern.
public struct RulesExpander: View {
    /// One market's resolution-criteria entry within the rules block.
    public struct MarketRule: Identifiable {
        /// Stable identity (usually the market id).
        public let id: String
        /// The rule's heading (e.g. the market/outcome name).
        public let title: String
        /// The resolution-criteria text.
        public let text: String

        /// Creates a market rule entry.
        public init(id: String, title: String, text: String) {
            self.id = id
            self.title = title
            self.text = text
        }
    }

    /// The event-level description shown at the top when expanded.
    private let eventDescription: String?
    /// The per-market rules listed below the description.
    private let marketRules: [MarketRule]
    /// Whether the block is expanded.
    @State private var isExpanded: Bool

    /// Creates the rules expander.
    /// - Parameters:
    ///   - eventDescription: The event-level description, if any.
    ///   - marketRules: The per-market resolution rules.
    ///   - startsExpanded: Whether the block starts expanded. Defaults to `false` (the
    ///     inline collapsed-by-default look); pass `true` when hosting this in a sheet
    ///     whose whole purpose is showing the rules.
    public init(eventDescription: String?, marketRules: [MarketRule], startsExpanded: Bool = false) {
        self.eventDescription = eventDescription
        self.marketRules = marketRules
        self._isExpanded = State(initialValue: startsExpanded)
    }

    /// Whether there's any content to show (otherwise the block renders nothing).
    private var hasContent: Bool {
        (eventDescription?.isEmpty == false) || !marketRules.isEmpty
    }

    public var body: some View {
        if hasContent {
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("Rules")
                                .font(DSFont.subheadline.bold())
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rules")
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                    if isExpanded {
                        VStack(alignment: .leading, spacing: DSLayout.spacingMedium) {
                            if let eventDescription, !eventDescription.isEmpty {
                                Text(eventDescription)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                            ForEach(marketRules) { rule in
                                VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                                    Text(rule.title)
                                        .font(DSFont.caption.bold())
                                        .foregroundStyle(DSColor.textPrimary)
                                    Text(rule.text)
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Rules expander") {
    ScrollView {
        RulesExpander(
            eventDescription: "This event resolves based on the official FIFA World Cup bracket.",
            marketRules: [
                RulesExpander.MarketRule(id: "1", title: "Argentina",
                                          text: "If Argentina wins, this market resolves \"Yes\". Otherwise \"No\".")
            ]
        )
        .padding()
    }
    .background(DSColor.background)
}
#endif
