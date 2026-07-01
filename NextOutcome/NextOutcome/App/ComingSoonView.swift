//
//  ComingSoonView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import DesignSystem

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text("\(title) — coming soon")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .navigationTitle(title)
    }
}
