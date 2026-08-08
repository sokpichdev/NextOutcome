//
//  SearchView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//


import SwiftUI
import MarketsDomain
import DesignSystem

/// The market search screen: a search field over a results list, with prompt/empty/error
/// states. Results are flat markets (no parent event).
public struct SearchView: View {
    /// The view model driving search.
    @State private var viewModel: SearchViewModel

    /// Creates the view.
    /// - Parameter viewModel: The search view model.
    public init(viewModel: SearchViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        // The field is rendered inline rather than via `.searchable`. The app hosts every
        // tab inside `RootView.chrome()`, which hides the system navigation bar in favour
        // of the custom top bar — and `.searchable` renders *into* that bar, so it was
        // never visible and the screen had no way to accept a query. Matches the inline
        // field the Crypto hub already uses.
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, DSLayout.margin)
                .padding(.vertical, DSLayout.spacing)
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
    }

    /// The inline search input. Mirrors `CryptoHubView.searchField` so the two screens
    /// read as one control.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search markets", text: Binding(
                get: { viewModel.query },
                set: { viewModel.queryChanged($0) }
            ))
            .font(DSFont.subheadline)
            .foregroundStyle(DSColor.textPrimary)
            // No `.textInputAutocapitalization` / `.submitLabel` here: the package also
            // builds for macOS, where those modifiers don't exist.
            .autocorrectionDisabled()
            .accessibilityIdentifier("search.field")
            if !viewModel.query.isEmpty {
                Button { viewModel.queryChanged("") } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DSColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }

    /// Switches on the view model's state to show the prompt, loading/empty/error states, or
    /// the results list.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            prompt
        case .loading:
            StateView(.loading)
        case .empty:
            StateView(.empty)
        case .failed(let message):
            StateView(.error(message))
        case .results(let events):
            results(events)
        }
    }

    /// The idle-state prompt shown before the user types a query.
    private var prompt: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text("Search NextOutcome markets")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }

    /// The scrolling list of matching event cards. Uses the same `HomeCard` the feed does,
    /// so a result looks identical to the card it came from.
    /// - Parameter events: The search results to show.
    private func results(_ events: [Event]) -> some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        HomeCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
    }
}