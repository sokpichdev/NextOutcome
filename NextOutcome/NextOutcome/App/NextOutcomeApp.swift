//
//  NextOutcomeApp.swift
//  NextOutcome
//
//  Created by Sok Pich on 28/06/2026.
//

import SwiftUI
import UIKit
import DesignSystem

@main
struct NextOutcomeApp: App {
    init() {
        #if DEBUG
        if ScreenshotMode.isActive {
            // Kill transition animations globally so a capture can never land mid-tween.
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
