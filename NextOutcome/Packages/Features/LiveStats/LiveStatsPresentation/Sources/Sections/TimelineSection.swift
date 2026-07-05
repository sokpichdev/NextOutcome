//
//  TimelineSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// The "Timeline" section: live commentary lines, newest first. Falls back to the
/// "Not available" row when the feed carries no commentary.
struct TimelineSection: View {
    /// The latest match snapshot to read `commentary` from.
    let match: MatchState?

    var body: some View {
        // Newest commentary first.
        let commentary = Array((match?.commentary ?? []).reversed())
        if !commentary.isEmpty {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                ForEach(commentary.indices, id: \.self) { i in
                    let item = commentary[i]
                    HStack(alignment: .top, spacing: DSLayout.spacingSmall) {
                        Text(item.minute.map { "\($0)'" } ?? "")
                            .font(DSFont.caption.bold())
                            .foregroundStyle(DSColor.textSecondary)
                            .frame(width: 32, alignment: .leading)
                        Text(item.text).font(DSFont.caption).foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
        } else {
            UnavailableRow()
        }
    }
}
