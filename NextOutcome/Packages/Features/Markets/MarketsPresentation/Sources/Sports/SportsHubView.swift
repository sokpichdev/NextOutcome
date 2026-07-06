//
//  SportsHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Sports hub screen shown when the category rail selects Sports: a Live/Futures mode
/// bar plus league chips (World Cup, Wimbledon, MLB, UFC, …). Tapping World Cup pushes the
/// existing `WorldCupHubView`; every other league chip pushes a generic league detail
/// screen. Live shows the general sports feed grouped by league; Futures shows a sport
/// picker (NBA/EPL) over ranked futures markets.
public struct SportsHubView: View {
    /// The view model driving the hub's data and Live/Futures mode.
    @State private var viewModel: SportsHubViewModel
    /// The shared World Cup hub view model, reused so its data survives navigation
    /// (the same instance shown when the rail selects World Cup directly).
    private let worldCupViewModel: WorldCupHubViewModel
    /// The use case used to build a league detail screen's view model on demand.
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Whether the Live tab's league search field is shown.
    @State private var isSearchActive = false
    /// The Live tab's league search text.
    @State private var searchQuery = ""

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The Sports hub view model.
    ///   - worldCupViewModel: The shared World Cup hub view model.
    ///   - fetchAllEvents: The use case for building league detail screens.
    public init(viewModel: SportsHubViewModel, worldCupViewModel: WorldCupHubViewModel, fetchAllEvents: FetchAllEventsUseCase) {
        self._viewModel = State(initialValue: viewModel)
        self.worldCupViewModel = worldCupViewModel
        self.fetchAllEvents = fetchAllEvents
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            SportsModeBar(mode: $viewModel.mode, leagues: viewModel.leagues)
                .padding(.vertical, DSLayout.spacingSmall)
            if isSearchActive, viewModel.mode == .live { searchField }
            content
        }
        .background(DSColor.background)
        .navigationDestination(for: SportsLeague.self) { league in
            if league.title == "World Cup" {
                WorldCupHubView(viewModel: worldCupViewModel)
            } else {
                SportsLeagueDetailView(league: league, fetchAllEvents: fetchAllEvents)
            }
        }
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .task { await viewModel.loadIfNeeded() }
    }

    /// Title + search/sort toggles for the Live tab; Futures shows the title only.
    private var header: some View {
        HStack(spacing: DSLayout.spacing) {
            Text(viewModel.mode == .live ? "Sports Live" : "Sports Futures")
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            if viewModel.mode == .live {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isSearchActive.toggle() }
                    if !isSearchActive { searchQuery = "" }
                } label: {
                    Image(systemName: isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                        .foregroundStyle(DSColor.textPrimary)
                }
                Menu {
                    ForEach(SportsSort.allCases, id: \.self) { sort in
                        Button {
                            viewModel.setLiveSort(sort)
                        } label: {
                            if sort == viewModel.liveSort { Label(sort.title, systemImage: "checkmark") }
                            else { Text(sort.title) }
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacing)
    }

    /// The Live tab's league search field.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search sports", text: $searchQuery)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacingSmall)
    }

    /// The selected mode's content, or a loading/error placeholder.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(maxHeight: .infinity)
        case .failed(let message):
            StateView(.error(message)).frame(maxHeight: .infinity)
        case .loaded:
            switch viewModel.mode {
            case .live:    liveContent
            case .futures: futuresContent
            }
        }
    }

    /// The Live tab: league sections of match cards, filtered by `searchQuery`.
    private var liveContent: some View {
        let groups = viewModel.liveGroups.compactMap { group -> (league: SportsLeague, events: [Event])? in
            guard !searchQuery.isEmpty else { return group }
            let filtered = group.events.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
            return filtered.isEmpty ? nil : (group.league, filtered)
        }
        return ScrollView {
            if groups.isEmpty {
                StateView(.empty).padding(.top, DSLayout.spacingXLarge)
            } else {
                LazyVStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                    ForEach(groups, id: \.league.id) { group in
                        VStack(alignment: .leading, spacing: DSLayout.spacing) {
                            Text(group.league.title.uppercased())
                                .font(DSFont.caption.bold())
                                .foregroundStyle(DSColor.textSecondary)
                            ForEach(group.events) { event in
                                NavigationLink(value: event) {
                                    HomeCard(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.vertical, DSLayout.spacing)
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    /// The Futures tab: a sport picker (NBA/EPL) over ranked futures markets.
    private var futuresContent: some View {
        ScrollView {
            VStack(spacing: DSLayout.spacing) {
                if !viewModel.futuresSports.isEmpty {
                    FilterChipRow<String?>(
                        items: viewModel.futuresSports.map { .init(id: $0.id, label: $0.title) },
                        selectedID: viewModel.selectedFuturesSportID,
                        onSelect: { id in if let id { Task { await viewModel.selectFuturesSport(id) } } }
                    )
                    .padding(.horizontal, -DSLayout.margin)
                }
                if viewModel.futuresEvents.isEmpty {
                    StateView(.empty).padding(.top, DSLayout.spacingXLarge)
                } else {
                    LazyVStack(spacing: DSLayout.spacing) {
                        ForEach(viewModel.futuresEvents) { event in
                            FuturesOddsCard(event: event)
                        }
                    }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .refreshable { await viewModel.refresh() }
    }
}
