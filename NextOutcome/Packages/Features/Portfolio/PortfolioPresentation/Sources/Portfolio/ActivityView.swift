//
//  ActivityView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

public struct ActivityView: View {
    @State private var viewModel: ActivityViewModel

    public init(viewModel: ActivityViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Activity")
            .task { await viewModel.load() }
    }

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
