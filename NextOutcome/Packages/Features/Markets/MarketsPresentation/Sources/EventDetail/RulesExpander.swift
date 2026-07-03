import SwiftUI
import DesignSystem

/// Collapsible "Rules" block: event-level description plus each market's resolution
/// criteria. Collapsed by default, matching the live site's "Show more" pattern.
public struct RulesExpander: View {
    public struct MarketRule: Identifiable {
        public let id: String
        public let title: String
        public let text: String

        public init(id: String, title: String, text: String) {
            self.id = id
            self.title = title
            self.text = text
        }
    }

    private let eventDescription: String?
    private let marketRules: [MarketRule]
    @State private var isExpanded = false

    public init(eventDescription: String?, marketRules: [MarketRule]) {
        self.eventDescription = eventDescription
        self.marketRules = marketRules
    }

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
