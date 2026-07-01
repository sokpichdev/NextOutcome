import SwiftUI

/// Top-level content categories shown in the persistent chip rail.
/// Order matches the screenshots exactly.
public enum ShellCategory: String, CaseIterable, Sendable {
    case trending, worldCup, breaking, politics, sports

    public var title: String {
        switch self {
        case .trending: return "Trending"
        case .worldCup: return "World Cup"
        case .breaking: return "Breaking"
        case .politics: return "Politics"
        case .sports:   return "Sports"
        }
    }

    /// Leading SF Symbol; `nil` when the chip is text-only.
    public var glyph: String? {
        switch self {
        case .trending: return "chart.line.uptrend.xyaxis"
        case .worldCup: return "soccerball"
        default:        return nil
        }
    }

    /// Text/glyph color when this chip is the active one.
    public var activeColor: Color {
        switch self {
        case .worldCup: return DSColor.categoryGold
        case .trending: return DSColor.accent
        default:        return DSColor.textPrimary
        }
    }
}
