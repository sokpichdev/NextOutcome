//
//  DSChip.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct DSChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    public init(_ label: String, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(DSFont.caption.bold())
                .foregroundStyle(isActive ? .white : DSColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? AnyView(DSGradient.accent) : AnyView(DSColor.surface))
                .clipShape(Capsule())
                .glowAccent(radius: isActive ? 8 : 0)
        }
        .buttonStyle(.plain)
    }
}
