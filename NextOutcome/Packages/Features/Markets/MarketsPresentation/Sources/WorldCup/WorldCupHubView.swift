//
//  WorldCupHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Dedicated World Cup screen shown when the category rail selects World Cup: flag-marquee
/// header, Games / Props / Bracket / Map sub-tabs, and per-tab content.
public struct WorldCupHubView: View {
    @State private var viewModel: WorldCupHubViewModel

    public init(viewModel: WorldCupHubViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                WorldCupTabBar(selection: $viewModel.selectedTab)
                    .padding(.vertical, DSLayout.spacing)
                tabContent
                    .padding(.horizontal, DSLayout.margin)
                    .padding(.bottom, DSLayout.spacingXLarge)
            }
        }
        .background(DSColor.background)
        .refreshable { await viewModel.refresh() }
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .task { await viewModel.loadIfNeeded() }
        .task { await viewModel.pollResults() }
    }

    private var header: some View {
        VStack(spacing: DSLayout.spacingSmall) {
            FlagMarqueeView(tiles: FlagMarqueeView.tiles(from: viewModel.winnerEvent))

            Text("World Cup")
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)

            VStack(spacing: 2) {
                Text("Live world cup predictions & odds")
                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated, format: .dateTime.month(.abbreviated).day().year())")
                }
            }
            .font(DSFont.subheadline)
            .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSLayout.spacingLarge)
        .padding(.bottom, DSLayout.spacing)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(minHeight: 200)
        case .failed(let message):
            StateView(.error(message)).frame(minHeight: 200)
        case .loaded:
            switch viewModel.selectedTab {
            case .games:
                GamesScheduleView(gamesByDay: viewModel.gamesByDay, results: viewModel.results)
            case .props:
                // Placeholder until the Props tab lands in the next phase.
                WorldCupPlaceholderView(tab: .props)
            case .bracket, .map:
                WorldCupPlaceholderView(tab: viewModel.selectedTab)
            }
        }
    }
}

/// "Coming soon" body for hub tabs whose data views haven't landed yet.
struct WorldCupPlaceholderView: View {
    let tab: WorldCupTab

    var body: some View {
        ContentUnavailableView {
            Label(tab.title, systemImage: icon)
        } description: {
            Text("\(tab.title) is coming soon.")
        }
        .padding(.vertical, DSLayout.spacingXLarge)
    }

    private var icon: String {
        switch tab {
        case .games:   return "sportscourt"
        case .props:   return "person.2"
        case .bracket: return "chart.bar.doc.horizontal"
        case .map:     return "globe"
        }
    }
}
