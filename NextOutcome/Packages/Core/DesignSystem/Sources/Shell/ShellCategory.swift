import SwiftUI

/// Top-level content categories shown in the persistent chip rail.
/// Order matches the screenshots exactly.
///
/// This drives the row of filter chips at the top of the home screen (see
/// `CategoryRail`) that lets the user switch between different content feeds.
public enum ShellCategory: String, CaseIterable, Sendable {
    /// The default "what's popular right now" feed.
    case trending
    /// The World Cup hub — brackets, schedules, and props for the tournament.
    case worldCup
    /// Breaking news markets.
    case breaking
    /// Political markets (elections, policy outcomes, etc.).
    case politics
    /// General sports markets (outside the dedicated World Cup hub).
    case sports

    /// The human-readable label shown on the chip for this category.
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
