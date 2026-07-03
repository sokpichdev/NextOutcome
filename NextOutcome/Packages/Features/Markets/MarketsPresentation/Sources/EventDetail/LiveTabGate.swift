import Foundation

/// Decides whether the "Live" segment shows on an event-detail page.
public enum LiveTabGate {
    /// Live segment shows only for in-progress sports matches: kickoff has passed,
    /// the event has team-based outcomes, and no market has resolved yet.
    public static func showsLive(gameStartTime: Date?, hasTeams: Bool, isResolved: Bool, now: Date) -> Bool {
        guard let gameStartTime, hasTeams, !isResolved else { return false }
        return gameStartTime <= now
    }
}
