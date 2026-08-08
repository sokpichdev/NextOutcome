import Foundation

/// Formats a time-remaining duration for live countdown displays (e.g. market close, event start).
public enum CountdownFormatter {
    /// `"3:47"` mm:ss under an hour, `"1h 12m"` above, `"0:00"` when `end` has already passed.
    ///
    /// - Parameters:
    ///   - end: The target date the countdown is counting down to.
    ///   - now: The current date to measure the remaining time from. Passed in
    ///     explicitly (rather than using `Date()` internally) so this function is
    ///     deterministic and easy to unit test.
    /// - Returns: A short, human-readable countdown string. Never negative — if
    ///   `end` is in the past, the remaining time is clamped to zero.
    public static func string(until end: Date, now: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        if remaining >= 3600 { return "\(remaining / 3600)h \((remaining % 3600) / 60)m" }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
