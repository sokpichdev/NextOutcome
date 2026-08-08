//
//  SportsLeagueDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// A single league's detail screen, pushed from a Sports hub chip (e.g. Wimbledon, MLB,
/// UFC): a Games/Props toggle, a Volume/Soonest sort, a toggleable title search, and a
/// trophy-icon standings sheet.
public struct SportsLeagueDetailView: View {
    /// The view model driving this league's markets, tab, sort, and search state.
    @State private var viewModel: SportsLeagueDetailViewModel
    /// Whether the standings sheet (trophy icon) is showing.
    @State private var isStandingsPresented = false
    /// The team logo tapped, if any — drives the profile push.
    @State private var selectedTeam: TeamProfileTarget?
    /// Builds the profile view model when a team logo is tapped.
    @Environment(\.teamProfileFactory) private var teamProfileFactory

    /// Creates the view.
    /// - Parameters:
    ///   - league: The league this screen shows.
    ///   - fetchAllEvents: The use case used to load the league's markets.
    public init(league: SportsLeague, fetchAllEvents: FetchAllEventsUseCase) {
        self._viewModel = State(initialValue: SportsLeagueDetailViewModel(league: league, fetchAllEvents: fetchAllEvents))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isSearchActive { searchField }
            tabRow
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .navigationDestination(item: $selectedTeam) { target in
            if let teamProfileFactory {
                TeamProfileView(viewModel: teamProfileFactory(target))
            }
        }
        .sheet(isPresented: $isStandingsPresented) {
            LeagueStandingsSheet(leagueTitle: viewModel.league.title, event: viewModel.standingsEvent)
        }
        .task { await viewModel.loadIfNeeded() }
    }

    /// The screen's own title row (the app hides the system nav bar): search + standings icons.
    private var header: some View {
        HStack {
            Text(viewModel.league.title)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.isSearchActive.toggle() }
                if !viewModel.isSearchActive { viewModel.searchQuery = "" }
            } label: {
                Image(systemName: viewModel.isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                    .foregroundStyle(DSColor.textPrimary)
            }
            Button { isStandingsPresented = true } label: {
                Image(systemName: "trophy").foregroundStyle(DSColor.textPrimary)
            }
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacing)
    }

    /// The toggleable search field shown above the list.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search \(viewModel.league.title)", text: $viewModel.searchQuery)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacing)
    }

    /// The Games/Props toggle chips plus the sort filter icon.
    private var tabRow: some View {
        HStack(spacing: DSLayout.spacing) {
            HStack(spacing: 8) {
                ForEach(SportsLeagueDetailViewModel.Tab.allCases, id: \.self) { tab in
                    DSChip(tab.title, isActive: viewModel.selectedTab == tab) { viewModel.selectedTab = tab }
                }
            }
            Spacer()
            Menu {
                ForEach(SportsSort.allCases, id: \.self) { sort in
                    Button {
                        viewModel.setSort(sort)
                    } label: {
                        if sort == viewModel.sort { Label(sort.title, systemImage: "checkmark") }
                        else { Text(sort.title) }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3").foregroundStyle(DSColor.textPrimary)
            }
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacing)
    }

    /// The selected tab's market list, or a loading/empty/error placeholder.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(maxHeight: .infinity)
        case .failed(let message):
            StateView(.error(message)).frame(maxHeight: .infinity)
        case .loaded:
            if viewModel.visibleEvents.isEmpty {
                StateView(.empty).frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DSLayout.spacing) {
                        ForEach(viewModel.visibleEvents) { event in
                            NavigationLink(value: event) {
                                HomeCard(
                                    event: event,
                                    onTeamTap: { selectedTeam = $0 },
                                    leagueSlug: viewModel.league.title.lowercased()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DSLayout.margin)
                    .padding(.vertical, DSLayout.spacing)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}
