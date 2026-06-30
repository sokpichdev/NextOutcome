//
//  Gradients.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public enum DSGradient {
    public static let accent = LinearGradient(
        colors: [DSColor.accent, DSColor.accent2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let positive = LinearGradient(
        colors: [DSColor.positive, DSColor.positive2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let negative = LinearGradient(
        colors: [DSColor.negative, DSColor.negative2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let positiveArea = LinearGradient(
        colors: [DSColor.positive.opacity(0.35), DSColor.positive.opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
    public static let accentArea = LinearGradient(
        colors: [DSColor.accent.opacity(0.35), DSColor.accent.opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
}
