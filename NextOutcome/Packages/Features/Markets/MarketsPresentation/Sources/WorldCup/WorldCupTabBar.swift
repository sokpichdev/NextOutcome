//
//  WorldCupTabBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import DesignSystem

/// Pill selector for the hub's sub-tabs. A sibling of `SegmentToggle` rather than a reuse:
/// that control stretches segments to equal widths, while this row hugs its labels and
/// scrolls if it must.
struct WorldCupTabBar: View {
    @Binding var selection: WorldCupTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingLarge) {
                ForEach(WorldCupTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, DSLayout.margin)
        }
    }

    private func tabButton(for tab: WorldCupTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            Text(tab.title)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(isSelected ? DSColor.textPrimary : DSColor.textSecondary)
                .padding(.horizontal, DSLayout.spacingLarge)
                .padding(.vertical, DSLayout.spacingMedium)
                .background(isSelected ? DSColor.surfaceElevated : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
