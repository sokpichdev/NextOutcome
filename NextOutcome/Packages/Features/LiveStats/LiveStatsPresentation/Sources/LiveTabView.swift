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
    private let gameID: String
    @Environment(\.sportsStreamer) private var streamer
    @State private var vm: LiveTabViewModel?
    @State private var selectedSection = 0

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
