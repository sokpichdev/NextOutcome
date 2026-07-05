//
//  LiveTabView.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// The chip-nav Live sub-tab: a pinned `ScoreHero` above a `ChipRow` of sections, each
/// rendered from the latest `MatchState`. Sections the feed does not populate show the
/// "Not available for this match" placeholder. The socket is injected via environment so
/// this view carries no Data-layer dependency.
public struct LiveTabView: View {
    /// The game to show live stats for.
    private let gameID: String
    /// The streamer injected from the environment; `nil` in previews/tests.
    @Environment(\.sportsStreamer) private var streamer
    /// The view model, created lazily once a streamer is available.
    @State private var vm: LiveTabViewModel?
    /// Index of the currently-selected section chip.
    @State private var selectedSection = 0

    /// Creates the Live tab for a specific game.
    /// - Parameter gameID: The game's feed identifier.
    public init(gameID: String) {
        self.gameID = gameID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            if let vm {
                content(vm)
            } else {
                UnavailableRow()
            }
        }
        .task(id: gameID) {
            guard let streamer else { return }
            let model = LiveTabViewModel(gameID: gameID, streamer: streamer)
            vm = model
            await model.observe()
        }
    }

    /// Builds the loaded content: the score hero, then either an error+retry block or the
    /// section chip row and the selected section's view.
    /// - Parameter vm: The active view model to read state from.
    @ViewBuilder
    private func content(_ vm: LiveTabViewModel) -> some View {
        ScoreHero(match: vm.match, connection: vm.connection)

        if case let .failed(message) = vm.state {
            VStack(spacing: DSLayout.spacingSmall) {
                Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                Button("Retry") { vm.retry() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacingLarge)
        } else {
            let titles = LiveSection.allCases.map(\.title)
            ChipRow(items: titles, selection: $selectedSection)
            section(for: LiveSection.allCases[selectedSection], match: vm.match)
        }
    }

    /// Maps a `LiveSection` to its concrete section view.
    /// - Parameters:
    ///   - section: Which section to render.
    ///   - match: The latest match snapshot to feed into the section.
    @ViewBuilder
    private func section(for section: LiveSection, match: LiveStatsDomain.MatchState?) -> some View {
        switch section {
        case .stats: StatsSection(match: match)
        case .pitch: PitchSection(match: match)
        case .lineups: LineupsSection(match: match)
        case .timeline: TimelineSection(match: match)
        case .table: TableSection(match: match)
        case .h2h: H2HSection(match: match)
        }
    }
}
