import SwiftUI
import MarketsDomain
import DesignSystem

/// Which way a chance has moved, used to pick the colour and arrow.
public enum ChanceDirection: Equatable {
    /// Chance increased.
    case up
    /// Chance decreased.
    case down
    /// No change.
    case flat
}

/// Formatting helpers for the chance-change indicator.
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

    /// The colour for a change direction (green up, red down, muted flat).
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
    /// The current chance as a 0…1 fraction.
    private let chanceFraction: Decimal
    /// The recent change in percentage points, or `nil` to hide the indicator.
    private let deltaPoints: Decimal?
    /// The colour of the leading "% chance" text.
    private let leadingColor: Color

    /// Creates the header.
    /// - Parameters:
    ///   - chanceFraction: The current chance (0…1).
    ///   - deltaPoints: The recent change in points, or `nil` to hide it.
    ///   - leadingColor: The colour of the main percentage. Defaults to the accent colour.
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
