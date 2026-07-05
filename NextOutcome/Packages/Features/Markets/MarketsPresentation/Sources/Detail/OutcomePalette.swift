import SwiftUI
import DesignSystem

/// Stable color per outcome index for multi-series charts and legends.
public enum OutcomePalette {
    /// The cycle of colours assigned to outcomes/series by index.
    private static let colors: [Color] = [
        DSColor.accent, DSColor.positive, DSColor.categoryGold, DSColor.newsOrange
    ]
    /// The colour for a given outcome index, wrapping around when there are more outcomes
    /// than colours.
    /// - Parameter index: The outcome/series index.
    /// - Returns: A stable colour for that index.
    public static func color(_ index: Int) -> Color {
        colors[index % colors.count]
    }
}
