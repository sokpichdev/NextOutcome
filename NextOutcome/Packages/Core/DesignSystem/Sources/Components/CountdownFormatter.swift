import Foundation

/// Formats a time-remaining duration for live countdown displays (e.g. market close, event start).
public enum CountdownFormatter {
    /// `"3:47"` mm:ss under an hour, `"1h 12m"` above, `"0:00"` when `end` has already passed.
    public static func string(until end: Date, now: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        if remaining >= 3600 { return "\(remaining / 3600)h \((remaining % 3600) / 60)m" }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
