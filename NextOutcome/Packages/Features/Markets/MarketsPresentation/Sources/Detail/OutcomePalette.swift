import SwiftUI
import DesignSystem

/// Stable color per outcome index for multi-series charts and legends.
public enum OutcomePalette {
    private static let colors: [Color] = [
        DSColor.accent, DSColor.positive, DSColor.categoryGold, DSColor.newsOrange
    ]
    public static func color(_ index: Int) -> Color {
        colors[index % colors.count]
    }
}
