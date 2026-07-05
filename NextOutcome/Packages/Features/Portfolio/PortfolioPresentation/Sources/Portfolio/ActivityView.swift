//
//  ActivityView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// The activity feed for the watched wallet: an infinitely-scrolling list of `ActivityRow`s
/// with pull-to-refresh.
public struct ActivityView: View {
    /// The view model driving the feed.
    @State private var viewModel: ActivityViewModel

    /// Creates the view.
    /// - Parameter viewModel: The activity view model.
    public init(viewModel: ActivityViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Activity")
            .task { await viewModel.load() }
    }

    /// Switches on the view model's state to show the no-wallet prompt, loading/empty/error
    /// states, or the activity list.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .needsAddress:
            emptyState("Set a watch wallet in the Portfolio tab to see its activity.",
                       systemImage: "clock.arrow.circlepath")
        case .loading:
            StateView(.loading)
        case .empty:
            StateView(.empty)
        case .failed(let message):
            StateView(.error(message))
        case .loaded(let activities):
            list(activities)
        }
    }

    /// The scrolling activity list. The last row triggers `loadMore()` when it appears,
    /// giving infinite scroll, plus a footer spinner while a page loads.
    /// - Parameter activities: The activity rows to show.
    private func list(_ activities: [Activity]) -> some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.spacing) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                        .task {
                            if activity.id == activities.last?.id {
                                await viewModel.loadMore()
                            }
                        }
                }
                if viewModel.isLoadingMore {
                    ProgressView().tint(DSColor.accent).padding()
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .refreshable { await viewModel.refresh() }
    }

    /// A centered icon + message used for the no-wallet prompt.
    /// - Parameters:
    ///   - text: The message to show.
    ///   - systemImage: The SF Symbol name for the icon.
    private func emptyState(_ text: String, systemImage: String) -> some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text(text)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSLayout.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }
}
