//
//  Font+Tokens.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public enum DSFont {
    public static let largeTitle = Font.largeTitle.bold()
    public static let title = Font.title2.bold()
    public static let headline = Font.headline
    public static let body = Font.body
    public static let subheadline = Font.subheadline
    public static let caption = Font.caption
    public static let caption2 = Font.caption2
    public static let price = Font.system(.title2, design: .monospaced).bold()
    public static let priceSmall = Font.system(.subheadline, design: .monospaced)
}
