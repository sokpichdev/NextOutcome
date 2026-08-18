//
//  TabBarVisibility.swift
//  NextOutcome
//
//  Created by Sok Pich on 18/08/2026.
//

import SwiftUI

public extension View {
    /// Hides the app's bottom tab bar for as long as this screen is the top of a
    /// navigation stack, giving a detail screen the full height and putting the tab bar
    /// back on the way out.
    ///
    /// Applied by the detail screens themselves rather than by whoever pushes them: a
    /// screen like `MarketDetailView` is pushed from seven different feeds, and a rule
    /// each caller has to remember is a rule that eventually gets forgotten.
    ///
    /// The test for applying it is "is this screen only ever pushed?", not "does it look
    /// like a detail screen". `SportsLeagueDetailView` reads as one but is rendered
    /// *inline* by `SportsHubView` inside the Home tab, so it keeps the bar — hiding it
    /// there would strand the user on a main screen with no way back to another tab.
    ///
    /// A no-op off iOS: `.tabBar` is an iOS-only toolbar placement, and this package
    /// builds for macOS as well.
    /// - Returns: The view, with the tab bar hidden while it's on screen.
    func hidesTabBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
