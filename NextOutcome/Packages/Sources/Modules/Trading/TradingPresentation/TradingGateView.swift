//
//  TradingGateView.swift
//  NextOutcome
//
//  Created by Sok Pich on 12/8/2026.
//

import SwiftUI
import DesignSystem
import TradingDomain

/// What the trade sheet shows instead of the amount pad when the user's region can't
/// open a position. Blocked and close-only get different wording — close-only users can
/// still exit what they hold, and telling them "unavailable" would be wrong.
public struct TradingGateView: View {
    /// The denial being explained. `.allowed` renders nothing; the caller shouldn't
    /// present this view in that case.
    private let access: TradingAccess
    /// Closes the sheet.
    private let onDismiss: () -> Void

    /// Creates the gate.
    /// - Parameters:
    ///   - access: The resolved access state.
    ///   - onDismiss: Called when the user taps Dismiss.
    public init(access: TradingAccess, onDismiss: @escaping () -> Void) {
        self.access = access
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(DSColor.textSecondary)
            Text(title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text(message)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss", action: onDismiss)
                .buttonStyle(DSPrimaryButtonStyle())
                .padding(.top, DSLayout.spacingSmall)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSLayout.spacingXLarge)
        .padding(.horizontal, DSLayout.margin)
    }

    /// The glyph for this denial.
    private var icon: String { Self.icon(for: access) }
    /// The headline for this denial.
    private var title: String { Self.title(for: access) }
    /// The explanation for this denial.
    private var message: String { Self.message(for: access) }

    /// The glyph: a hard stop versus a one-way door.
    /// - Parameter access: The denial being explained.
    static func icon(for access: TradingAccess) -> String {
        switch access {
        case .blocked: "hand.raised.fill"
        case .closeOnly: "arrow.down.right.circle.fill"
        case .allowed: "checkmark.circle.fill"
        }
    }

    /// The headline.
    /// - Parameter access: The denial being explained.
    static func title(for access: TradingAccess) -> String {
        switch access {
        case .blocked: "Trading unavailable"
        case .closeOnly: "Closing positions only"
        case .allowed: ""
        }
    }

    /// The explanation, naming the region when the endpoint reported one.
    ///
    /// Close-only deliberately doesn't say "unavailable" — those users *can* still exit
    /// what they hold, and telling them otherwise would be wrong.
    /// - Parameter access: The denial being explained.
    static func message(for access: TradingAccess) -> String {
        switch access {
        case .blocked(let region):
            "Trading isn't available\(suffix(region))."
        case .closeOnly(let region):
            "You can close existing positions\(suffix(region)), but not open new ones."
        case .allowed:
            ""
        }
    }

    /// " in US" when the region is known, " in your region" when it isn't.
    private static func suffix(_ region: String?) -> String {
        guard let region, !region.isEmpty else { return " in your region" }
        return " in \(region)"
    }
}

#if DEBUG
#Preview("Blocked") {
    TradingGateView(access: .blocked(region: "US"), onDismiss: {})
        .background(DSColor.background)
}

#Preview("Close only, unknown region") {
    TradingGateView(access: .closeOnly(region: nil), onDismiss: {})
        .background(DSColor.background)
}
#endif
