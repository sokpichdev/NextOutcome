//
//  MidtermsPromoCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// Navigation marker pushed when the "2026 Midterms Predictions" promo card is tapped in the
/// Politics feed — the one entry point into the full `PoliticsHubView` detail screen.
struct MidtermsHubDestination: Hashable {}

/// The "2026 Midterms Predictions" promo card shown at the top of the Politics feed — a
/// title plus a live mini state-lean map thumbnail. Tapping it (via the caller's
/// `NavigationLink(value: MidtermsHubDestination())`) is the only way into the full hub.
struct MidtermsPromoCard: View {
    let viewModel: PoliticsHubViewModel

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                (Text("2026 Midterms ").foregroundStyle(DSColor.textPrimary)
                    + Text("Predictions").foregroundStyle(DSColor.accent))
                    .font(DSFont.title)
                USStateMapView(colors: viewModel.leanByState(for: .senate).mapValues(\.color))
                    .frame(height: 130)
            }
        }
    }
}
