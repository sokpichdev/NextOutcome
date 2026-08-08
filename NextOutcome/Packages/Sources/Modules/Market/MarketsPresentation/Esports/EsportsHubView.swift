//
//  EsportsHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Esports hub, replacing the generic `EventListView` for the Esports rail category:
/// an "Esports | Leaderboard" header, the hero carousel of live matches (embedded stream,
/// prices, live-trades ticker), the horizontal game tiles, and the Games list. The
/// leaderboard tab's content is injected from the composition root (it lives in
/// PortfolioPresentation, which this package doesn't depend on).
public struct EsportsHubView: View {
    /// The view model driving the hub.
    @State private var viewModel: EsportsHubViewModel
    /// The Esports tag's live Gamma id, resolved by `HubTabsViewModel`.
    private let tagID: String?
    /// The Leaderboard tab's screen, built by the composition root.
    private let leaderboard: AnyView

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The Esports hub view model.
    ///   - tagID: The Esports tag's live Gamma id.
    ///   - leaderboard: The Leaderboard tab's content.
    public init(viewModel: EsportsHubViewModel, tagID: String?, leaderboard: AnyView) {
        self._viewModel = State(initialValue: viewModel)
        self.tagID = tagID
        self.leaderboard = leaderboard
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                modeBar
                switch viewModel.mode {
                case .esports: esportsContent
                case .leaderboard: leaderboard
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .task {
            if let tagID { await viewModel.loadIfNeeded(tagID: tagID) }
            viewModel.startLivePolling()
        }
        .onDisappear { viewModel.stopLivePolling() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Header

    /// The "Esports | Leaderboard" toggle, styled like web's inline tab header.
    private var modeBar: some View {
        HStack(spacing: DSLayout.spacing) {
            modeButton("Esports", mode: .esports)
            modeButton("Leaderboard", mode: .leaderboard)
            Spacer()
        }
    }

    private func modeButton(_ title: String, mode: EsportsHubViewModel.Mode) -> some View {
        Button {
            viewModel.mode = mode
        } label: {
            Text(title)
                .font(DSFont.title)
                .foregroundStyle(viewModel.mode == mode ? DSColor.textPrimary : DSColor.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Esports tab

    @ViewBuilder
    private var esportsContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingPlaceholder
        case .failed(let message):
            StateView(.error(message))
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        case .loaded:
            if !viewModel.heroMatches.isEmpty { heroCarousel }
            gameTileRow
            gamesList
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: DSLayout.spacing) {
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .fill(DSColor.surface)
                .frame(height: 380)
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .fill(DSColor.surface)
                .frame(height: 130)
        }
        .redacted(reason: .placeholder)
    }

    /// The paged hero carousel of live (or next-up) matches.
    private var heroCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DSLayout.spacingSmall) {
                ForEach(viewModel.heroMatches) { event in
                    NavigationLink(value: event) {
                        EsportsHeroCard(
                            event: event,
                            result: viewModel.result(for: event),
                            stream: viewModel.liveStream(for: event),
                            trades: viewModel.trades(for: event)
                        )
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    /// The horizontal CS2/LoL/Dota 2 artwork tiles with live counts.
    private var gameTileRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingSmall) {
                ForEach(EsportsGame.allCases) { game in
                    EsportsGameTile(
                        game: game,
                        liveCount: viewModel.liveCount(for: game),
                        isSelected: viewModel.selectedGame == game
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedGame = viewModel.selectedGame == game ? nil : game
                        }
                    }
                }
            }
        }
    }

    /// The Games section: one match card per visible event.
    @ViewBuilder
    private var gamesList: some View {
        Text("Games")
            .font(DSFont.title)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.top, DSLayout.spacingSmall)

        if viewModel.visibleMatches.isEmpty {
            Text("No matches right now. Check back soon.")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(viewModel.visibleMatches) { event in
                    NavigationLink(value: event) {
                        EsportsMatchCard(event: event, result: viewModel.result(for: event))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
