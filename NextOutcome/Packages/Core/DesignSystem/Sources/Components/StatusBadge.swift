//
//  StatusBadge.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct StatusBadge: View {
    let text: String
    let color: Color
    
    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        Text(text)
            .font(DSFont.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
