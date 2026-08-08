import SwiftUI
import OrderbookDomain
import DesignSystem

/// User-facing chart timeframe pills, mapped to the domain price-history interval.
public enum ChartTimeframe: String, CaseIterable {
    case h1, d1, w1, m1, max

    /// The short pill label (e.g. "1H").
    public var title: String {
        switch self {
        case .h1: return "1H"
        case .d1: return "1D"
        case .w1: return "1W"
        case .m1: return "1M"
        case .max: return "MAX"
        }
    }

    /// The domain price-history interval this timeframe maps to.
    public var interval: PriceHistoryInterval {
        switch self {
        case .h1: return .oneHour
        case .d1: return .oneDay
        case .w1: return .oneWeek
        case .m1: return .oneMonth
        case .max: return .max
        }
    }
}

/// A row of chips for choosing the chart timeframe, bound to a selection.
public struct TimeframePicker: View {
    /// The currently-selected timeframe (two-way bound).
    @Binding private var selected: ChartTimeframe
    /// Creates the picker.
    /// - Parameter selected: A binding to the selected timeframe.
    public init(selected: Binding<ChartTimeframe>) { self._selected = selected }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(ChartTimeframe.allCases, id: \.self) { tf in
                DSChip(tf.title, isActive: tf == selected) { selected = tf }
            }
        }
    }
}
