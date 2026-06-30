//
//  DSCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct DSCard<Content: View>: View {
    var highlighted: Bool
    @ViewBuilder var content: () -> Content
    
    public init(highlighted: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.highlighted = highlighted
        self.content = content
    }
    
    public var body: some View {
        content()
            .padding(DSLayout.margin)
            .background(
                highlighted ? DSColor.accentTint : DSColor.surface
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                    .strokeBorder(highlighted ? DSColor.accent.opacity(0.3) : DSColor.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }
}
