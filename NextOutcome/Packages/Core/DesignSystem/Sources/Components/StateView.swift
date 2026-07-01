//
//  StateView.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public enum ViewState { case loading, empty, error(String) }

public struct StateView: View {
    let state: ViewState
    
    public init(_ state: ViewState) { self.state = state }
    
    public var body: some View {
        switch state {
        case .loading:
             ProgressView()
                .tint(DSColor.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView("No results", systemImage: "tray")
        case .error(let msg):
            ContentUnavailableView(msg, systemImage: "exclamationmark.triangle")
        }
    }
}
