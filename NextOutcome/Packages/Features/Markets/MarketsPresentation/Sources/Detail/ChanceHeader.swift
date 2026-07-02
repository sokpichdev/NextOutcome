import SwiftUI
import MarketsDomain
import DesignSystem

public enum ChanceDirection: Equatable { case up, down, flat }

public enum ChanceDelta {
    /// Formats a percentage-point change. nil input → nil (hidden). Rounds to a whole percent.
    public static func format(_ deltaPoints: Decimal?) -> (text: String, direction: ChanceDirection)? {
        guard let deltaPoints else { return nil }
        let rounded = (deltaPoints as NSDecimalNumber).doubleValue.rounded()
        let magnitude = Int(abs(rounded))
        if rounded > 0 { return ("▲ \(magnitude)%", .up) }
        if rounded < 0 { return ("▼ \(magnitude)%", .down) }
        return ("0%", .flat)
    }

    static func color(_ direction: ChanceDirection) -> Color {
        switch direction {
        case .up: return DSColor.positive
        case .down: return DSColor.negative
        case .flat: return DSColor.textSecondary
        }
    }
}

/// The big "60% chance ▲ 9%" block on a market detail screen.
public struct ChanceHeader: View {
    private let chanceFraction: Decimal
    private let deltaPoints: Decimal?
    private let leadingColor: Color

    public init(chanceFraction: Decimal, deltaPoints: Decimal?, leadingColor: Color = DSColor.accent) {
        self.chanceFraction = chanceFraction
        self.deltaPoints = deltaPoints
        self.leadingColor = leadingColor
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(MarketFormatting.percent(chanceFraction)) chance")
                .font(DSFont.largeTitle)
                .foregroundStyle(leadingColor)
            if let delta = ChanceDelta.format(deltaPoints) {
                Text(delta.text)
                    .font(DSFont.subheadline)
                    .foregroundStyle(ChanceDelta.color(delta.direction))
            }
            Spacer()
        }
    }
}
